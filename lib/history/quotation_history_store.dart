import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QuotationHistoryStore extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _quotations = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get quotations => List.unmodifiable(_quotations);
  bool get isLoading => _isLoading;

  QuotationHistoryStore() {
    fetchQuotations();
  }

  /// 🔥 FETCH QUOTATIONS (REAL-TIME LISTENER)
  void fetchQuotations() {
    _db
        .collection('quotations')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _quotations
        ..clear()
        ..addAll(snapshot.docs.map((doc) {
          final data = doc.data();

          DateTime? parseDate(dynamic value) {
            if (value == null) return null;
            if (value is Timestamp) return value.toDate();
            if (value is DateTime) return value;
            return null;
          }

          return {
            'id': doc.id, // 🔥 Always store Firestore auto ID
            ...data,
            'checkInDate': parseDate(data['checkInDate']),
            'checkOutDate': parseDate(data['checkOutDate']),
            'advancePaymentDate': parseDate(data['advancePaymentDate']),
            'advancePayments': _parseAdvancePayments(data['advancePayments']),
            'createdAt': parseDate(data['createdAt']),
            'updatedAt': parseDate(data['updatedAt']),
          };
        }));

      _isLoading = false;
      notifyListeners();
    }, onError: (error) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error fetching quotations: $error');
    });
  }

  /// ➕ ADD QUOTATION (AUTO DOCUMENT ID — FIXED)
  Future<void> addQuotation(Map<String, dynamic> quotation) async {
    final docRef = _db.collection('quotations').doc(); // ✅ AUTO ID

    final dataToSave = {
      ...quotation,
      'createdAt': FieldValue.serverTimestamp(),
      if (quotation['checkInDate'] is DateTime)
        'checkInDate': Timestamp.fromDate(quotation['checkInDate']),
      if (quotation['checkOutDate'] is DateTime)
        'checkOutDate': Timestamp.fromDate(quotation['checkOutDate']),
    };

    await docRef.set(dataToSave);
  }

  /// ✏️ UPDATE QUOTATION
  Future<void> updateQuotation(
      String quotationId, Map<String, dynamic> quotation) async {
    final dataToUpdate = Map<String, dynamic>.from(quotation)
      ..remove('id')
      ..['updatedAt'] = FieldValue.serverTimestamp();

    if (quotation['checkInDate'] is DateTime) {
      dataToUpdate['checkInDate'] =
          Timestamp.fromDate(quotation['checkInDate']);
    }
    if (quotation['checkOutDate'] is DateTime) {
      dataToUpdate['checkOutDate'] =
          Timestamp.fromDate(quotation['checkOutDate']);
    }
    if (quotation['advancePaymentDate'] is DateTime) {
      dataToUpdate['advancePaymentDate'] =
          Timestamp.fromDate(quotation['advancePaymentDate']);
    }
    if (quotation['advancePayments'] is List) {
      dataToUpdate['advancePayments'] = _cleanAdvancePayments(
        quotation['advancePayments'] as List,
      );
    }
    if (quotation['createdAt'] is DateTime) {
      dataToUpdate['createdAt'] =
          Timestamp.fromDate(quotation['createdAt']);
    }

    await _db
        .collection('quotations')
        .doc(quotationId)
        .update(dataToUpdate);
  }

  Future<void> updateStatus(String quotationId, String status) async {
    final quotationRef = _db.collection('quotations').doc(quotationId);
    final quotationSnapshot = await quotationRef.get();
    final quotation = quotationSnapshot.data() ?? const <String, dynamic>{};
    await quotationRef.update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Keep a confirmed booking visible to Total Income and synchronize only
    // its status; payment amounts and paidAt timestamps remain untouched.
    final confirmation = _db.collection('confirmed_quotations').doc(quotationId);
    final snapshot = await confirmation.get();
    if (snapshot.exists) await confirmation.update({'status': status});

    if (status == 'cancelled' || status == 'postponed') {
      await _removeBookingFromRoomCharts(quotation);
    }
  }

  Future<void> _removeBookingFromRoomCharts(Map<String, dynamic> quotation) async {
    DateTime? dateOf(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    final checkIn = dateOf(quotation['checkInDate']);
    final checkOut = dateOf(quotation['checkOutDate']);
    final customerName = quotation['customerName']?.toString().trim().toLowerCase();
    if (checkIn == null || checkOut == null || customerName == null || customerName.isEmpty) return;

    final firstDay = DateTime(checkIn.year, checkIn.month, checkIn.day);
    final lastDay = DateTime(checkOut.year, checkOut.month, checkOut.day);
    final batch = _db.batch();
    var hasWrites = false;

    for (var day = firstDay; !day.isAfter(lastDay); day = day.add(const Duration(days: 1))) {
      final id = '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final ref = _db.collection('room_occupancy').doc(id);
      final roomDay = await ref.get();
      if (!roomDay.exists) continue;
      final rawRooms = roomDay.data()?['rooms'];
      if (rawRooms is! Map) continue;
      final rooms = Map<String, dynamic>.from(rawRooms);
      final matchingRooms = rooms.entries
          .where((entry) => entry.value is Map &&
              (entry.value['name']?.toString().trim().toLowerCase() == customerName))
          .map((entry) => entry.key)
          .toList();
      if (matchingRooms.isEmpty) continue;
      for (final room in matchingRooms) {
        rooms.remove(room);
      }
      if (rooms.isEmpty) {
        batch.delete(ref);
      } else {
        batch.update(ref, {'rooms': rooms});
      }
      hasWrites = true;
    }

    if (hasWrites) await batch.commit();
  }

  /// ❌ DELETE QUOTATION
  Future<void> deleteQuotation(String quotationId) async {
    await _db.collection('quotations').doc(quotationId).delete();
  }

  List<Map<String, dynamic>> _parseAdvancePayments(dynamic values) {
    if (values is! List) return [];
    return values.whereType<Map>().map((entry) {
      DateTime? paidAt;
      final raw = entry['paidAt'];
      if (raw is Timestamp) {
        paidAt = raw.toDate();
      } else if (raw is DateTime) {
        paidAt = raw;
      }
      return {
        'amount': entry['amount'],
        'mode': entry['mode'],
        'recordedBy': entry['recordedBy'],
        'paidAt': paidAt,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _cleanAdvancePayments(List payments) {
    return payments.whereType<Map>().map((entry) {
      final paidAt = entry['paidAt'];
      return {
        'amount': entry['amount'],
        'mode': entry['mode'],
        'recordedBy': entry['recordedBy'],
        'paidAt': paidAt is DateTime
            ? Timestamp.fromDate(paidAt)
            : paidAt,
      };
    }).toList();
  }
}
