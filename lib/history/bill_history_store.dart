import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillHistoryStore extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _bills = [];
  bool isLoading = true;

  List<Map<String, dynamic>> get bills => _bills;

  BillHistoryStore() {
    _listenBills();
  }

  /// 🔥 REAL-TIME LISTENER
  void _listenBills() {
    _db
        .collection('bills')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _bills
        ..clear()
        ..addAll(
          snapshot.docs.map((doc) {
            final data = doc.data();

            return {
              ...data,
              'billId': doc.id,
              'checkInDate':
                  (data['checkInDate'] as Timestamp?)?.toDate(),
              'checkOutDate':
                  (data['checkOutDate'] as Timestamp?)?.toDate(),
              'advancePaymentDate':
                  (data['advancePaymentDate'] as Timestamp?)?.toDate(),
              'advancePayments': _parseAdvancePayments(data['advancePayments']),
            };
          }),
        );

      isLoading = false;
      notifyListeners();
    });
  }

  /// 🧹 CLEAN ITEMS
  List<Map<String, dynamic>> _cleanItems(List items) {
    return items.map((i) {
      return {
        'name': i['name'],
        'qty': i['qty'],
        'price': i['price'],
      };
    }).toList();
  }

  /// 📌 ADD OR UPDATE BILL
  Future<void> addOrUpdateBill(
    Map<String, dynamic> bill,
  ) async {
    if (bill['billId'] == null) {
      throw Exception('billId is required to save bill');
    }

    final String billId = bill['billId'];

    final docRef = _db.collection('bills').doc(billId);

    final snap = await docRef.get();

    final subtotal = _toNum(bill['subtotal']);
    final gst = _toNum(bill['gst']);
    final discount = _toNum(bill['discount']);
    final balance = _toNum(bill['balance']);
    var advance = _toNum(bill['advance']).round();

    // Older bills may have balance calculated with advance but advance field
    // stored as 0 or as a double that failed to display elsewhere.
    if (advance <= 0 && subtotal + gst - discount - balance > 0) {
      advance = (subtotal + gst - discount - balance).round();
    }

    final cleanData = {
      ...bill,
      'advance': advance,

      if (bill['items'] != null)
        'items': _cleanItems(bill['items']),

      if (bill['checkInDate'] is DateTime)
        'checkInDate':
            Timestamp.fromDate(bill['checkInDate']),

      if (bill['checkOutDate'] is DateTime)
        'checkOutDate':
            Timestamp.fromDate(bill['checkOutDate']),

      if (bill['advancePaymentDate'] is DateTime)
        'advancePaymentDate':
            Timestamp.fromDate(bill['advancePaymentDate']),

      if (bill['advancePayments'] is List)
        'advancePayments': _cleanAdvancePayments(bill['advancePayments']),

      if (bill['createdAt'] is DateTime)
        'createdAt': Timestamp.fromDate(bill['createdAt']),

      'billId': billId,

      'updatedAt': FieldValue.serverTimestamp(),

      if (!snap.exists)
        'createdAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(
      cleanData,
      SetOptions(merge: true),
    );
  }

  List<Map<String, dynamic>> _cleanAdvancePayments(List payments) {
    return payments.whereType<Map>().map((entry) {
      final paidAt = entry['paidAt'];
      return {
        'amount': entry['amount'] ?? 0,
        'mode': entry['mode'] ?? 'Not recorded',
        'recordedBy': entry['recordedBy'] ?? 'Admin',
        if (paidAt is DateTime)
          'paidAt': Timestamp.fromDate(paidAt)
        else if (paidAt is Timestamp)
          'paidAt': paidAt,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _parseAdvancePayments(dynamic values) {
    if (values is! List) return [];
    return values.whereType<Map>().map((entry) {
      final paidAt = entry['paidAt'];
      DateTime? parsedPaidAt;
      if (paidAt is Timestamp) {
        parsedPaidAt = paidAt.toDate();
      } else if (paidAt is DateTime) {
        parsedPaidAt = paidAt;
      }
      return {
        'amount': entry['amount'] ?? 0,
        'mode': entry['mode'],
        'recordedBy': entry['recordedBy'],
        if (parsedPaidAt != null) 'paidAt': parsedPaidAt,
      };
    }).toList();
  }

  /// ❌ DELETE BILL
  Future<void> deleteBill(String billId) async {
    await _db.collection('bills').doc(billId).delete();
  }

  double _toNum(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
