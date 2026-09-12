import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConfirmStore extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _confirmed = [];
  bool _isLoading = true;

  List<Map<String, dynamic>> get confirmedQuotations =>
      List.unmodifiable(_confirmed);

  bool get isLoading => _isLoading;

  ConfirmStore() {
    fetchConfirmed();
  }

  /// 🔍 CHECK IF ALREADY CONFIRMED
  bool isConfirmed(String quotationId) {
    return _confirmed.any((q) => q['originalQuotationId'] == quotationId);
  }

  Map<String, dynamic>? confirmedByQuotationId(String quotationId) {
    for (final q in _confirmed) {
      if (q['originalQuotationId'] == quotationId) return q;
    }
    return null;
  }

  /// 🔥 REAL-TIME LISTENER
  /// 1️⃣ AUTO REMOVE AFTER CHECKOUT DAY ENDS
  /// 2️⃣ SORT BY NEAREST CHECK-IN DATE
  void fetchConfirmed() {
    _db.collection('confirmed_quotations').snapshots().listen((snapshot) async {
      final now = DateTime.now();

      DateTime? parseDate(dynamic value) {
        if (value == null) return null;
        if (value is Timestamp) return value.toDate();
        if (value is DateTime) return value;
        return null;
      }

      List<Map<String, dynamic>> tempList = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();

        final checkOut = parseDate(data['checkOutDate']);

        /// 🔥 AUTO DELETE ONLY FROM confirmed_quotations
        if (checkOut != null) {
          final checkoutEnd = DateTime(
            checkOut.year,
            checkOut.month,
            checkOut.day,
            23,
            59,
            59,
          );

          if (now.isAfter(checkoutEnd)) {
            await _syncAdvanceMetadataToBill(
              confirmId: doc.id,
              data: data,
            );
            await _db.collection('confirmed_quotations').doc(doc.id).delete();
            continue; // skip adding
          }
        }

        tempList.add({
          'confirmId': doc.id,
          'originalQuotationId': data['originalQuotationId'],
          'customerName': data['customerName'],
          'phone1': data['phone1'],
          'phone2': data['phone2'] ?? '',
          'advance': _toDouble(data['advance']),
          'advancePayments': _parseAdvancePayments(data['advancePayments']),
          'advancePaymentMode': data['advancePaymentMode'],
          'advanceRecordedBy': data['advanceRecordedBy'],
          'advancePaymentDate': parseDate(data['advancePaymentDate']),
          'address': data['address'] ?? '',
          'package': data['package'],
          'checkInDate': parseDate(data['checkInDate']),
          'checkOutDate': parseDate(data['checkOutDate']),
          'checkInTime': data['checkInTime'] ?? '',
          'checkOutTime': data['checkOutTime'] ?? '',
          'rooms': data['rooms'] ?? [],
          'adult': _toInt(data['adult']),
          'children': _toInt(data['children']),
          'child': _toInt(data['child']),
          'totalPax': _toInt(data['totalPax']),
          'discount': _toInt(data['discount']),
          'extraPersons': _toInt(data['extraPersons']),
          'extraTotal': _toInt(data['extraTotal']),
          'extraPersonPrice': _toInt(data['extraPersonPrice']),
          'amount': _toInt(data['amount']),
          'total': _toInt(data['total'] ?? data['amount']),
          'gstPercent': data['gstPercent'],
          'facilities': data['facilities'] ?? [],
          'createdAt': parseDate(data['createdAt']),
          'confirmedAt': parseDate(data['confirmedAt']),
          'billGenerated': data['billGenerated'] ?? false,
          'billId': data['billId'],
        });
      }

      /// 🔥 SORT BY CHECK-IN DATE (NEAREST FIRST)
      tempList.sort((a, b) {
        final DateTime? aDate = a['checkInDate'];
        final DateTime? bDate = b['checkInDate'];

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        return aDate.compareTo(bDate); // nearest date first
      });

      _confirmed
        ..clear()
        ..addAll(tempList);

      _isLoading = false;
      notifyListeners();
    });
  }

  /// ➕ CONFIRM QUOTATION
  Future<void> confirmQuotation(
    Map<String, dynamic> q, {
    required String advancePaymentMode,
    required String advanceRecordedBy,
    DateTime? advancePaymentDate,
    List<Map<String, dynamic>>? advancePayments,
  }) async {
    final String quotationId = q['id'];
    if (isConfirmed(quotationId)) return;

    final payments = _firestoreAdvancePayments(
      advancePayments,
      fallbackAmount: _toDouble(q['advance']),
      fallbackMode: advancePaymentMode,
      fallbackRecordedBy: advanceRecordedBy,
      fallbackPaidAt: advancePaymentDate,
    );
    final advance = payments.fold<double>(
      0,
      (sum, entry) => sum + _toDouble(entry['amount']),
    );
    final last = payments.isNotEmpty ? payments.last : null;

    await _db.collection('confirmed_quotations').add({
      'originalQuotationId': quotationId,

      'customerName': q['customerName'],
      'phone1': q['phone1'],
      'phone2': q['phone2'] ?? '',
      'advance': advance,
      'advancePayments': payments,
      'advancePaymentMode': last?['mode'] ?? advancePaymentMode,
      'advanceRecordedBy': last?['recordedBy'] ?? advanceRecordedBy,
      'advancePaymentDate': last?['paidAt'] ??
          Timestamp.fromDate(_dateOnly(advancePaymentDate ?? DateTime.now())),
      'address': q['address'] ?? '',
      'package': q['package'],

      'checkInDate': q['checkInDate'] is DateTime
          ? Timestamp.fromDate(q['checkInDate'])
          : q['checkInDate'],
      'checkOutDate': q['checkOutDate'] is DateTime
          ? Timestamp.fromDate(q['checkOutDate'])
          : q['checkOutDate'],

      'checkInTime': q['checkInTime'] ?? '',
      'checkOutTime': q['checkOutTime'] ?? '',

      'adult': q['adult'] ?? 0,
      'children': q['children'] ?? 0,
      'child': q['child'] ?? 0,
      'totalPax': q['totalPax'] ?? 0,

      'discount': q['discount'] ?? 0,
      'extraPersons': q['extraPersons'] ?? 0,
      'extraTotal': q['extraTotal'] ?? 0,
      'extraPersonPrice': q['extraPersonPrice'] ?? 0,
      'amount': q['amount'] ?? 0,
      'total': q['total'] ?? 0,
      'gstPercent': q['gstPercent'] ?? 18,
      'facilities': q['facilities'] ?? [],
      'rooms': q['rooms'] ?? [],

      'createdAt': q['createdAt'] is DateTime
          ? Timestamp.fromDate(q['createdAt'])
          : q['createdAt'],

      // Bill status
      'billGenerated': false,
      'billId': null,

      'confirmedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addAdvancePayment({
    required String confirmId,
    required double amount,
    required String mode,
    required String recordedBy,
    DateTime? paidAt,
  }) async {
    if (amount <= 0) return;

    final paymentDate = paidAt ?? DateTime.now();
    final doc = _db.collection('confirmed_quotations').doc(confirmId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(doc);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final currentAdvance = _toDouble(data['advance']);
      final payments = List<Map<String, dynamic>>.from(
        (data['advancePayments'] as List? ?? const []).map(
          (entry) => Map<String, dynamic>.from(entry as Map),
        ),
      );
      payments.add({
        'amount': amount,
        'mode': mode,
        'recordedBy': recordedBy,
        'paidAt': Timestamp.fromDate(paymentDate),
      });
      transaction.update(doc, {
        'advance': currentAdvance + amount,
        'advancePayments': payments,
        'advancePaymentMode': mode,
        'advanceRecordedBy': recordedBy,
        'advancePaymentDate': Timestamp.fromDate(paymentDate),
      });
    });

    final confirmSnap = await doc.get();
    if (confirmSnap.exists) {
      await _syncAdvanceMetadataToBill(
        confirmId: confirmId,
        data: confirmSnap.data()!,
      );
    }
  }

  /// Replace all advance payments (edit booking — no duplicates).
  Future<void> replaceAdvancePayments({
    required String confirmId,
    required List<Map<String, dynamic>> advancePayments,
  }) async {
    final payments = _firestoreAdvancePayments(advancePayments);
    if (payments.isEmpty) return;

    final advance = payments.fold<double>(
      0,
      (sum, entry) => sum + _toDouble(entry['amount']),
    );
    final last = payments.last;

    final update = {
      'advance': advance,
      'advancePayments': payments,
      'advancePaymentMode': last['mode'],
      'advanceRecordedBy': last['recordedBy'],
      'advancePaymentDate': last['paidAt'],
    };

    await _db.collection('confirmed_quotations').doc(confirmId).update(update);

    final confirmSnap =
        await _db.collection('confirmed_quotations').doc(confirmId).get();
    if (confirmSnap.exists) {
      await _syncAdvanceMetadataToBill(
        confirmId: confirmId,
        data: {
          ...confirmSnap.data()!,
          ...update,
        },
      );
    }
  }

  List<Map<String, dynamic>> _firestoreAdvancePayments(
    List<Map<String, dynamic>>? payments, {
    double fallbackAmount = 0,
    String? fallbackMode,
    String? fallbackRecordedBy,
    DateTime? fallbackPaidAt,
  }) {
    Timestamp? toTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(_dateOnly(value));
      return null;
    }

    if (payments != null && payments.isNotEmpty) {
      return payments
          .where((entry) => _toDouble(entry['amount']) >= 1)
          .map((entry) {
        final paidAt = toTimestamp(entry['paidAt']) ??
            Timestamp.fromDate(_dateOnly(fallbackPaidAt ?? DateTime.now()));
        return {
          'amount': _toDouble(entry['amount']),
          'mode': (entry['mode'] ?? fallbackMode ?? 'Cash').toString(),
          'recordedBy':
              (entry['recordedBy'] ?? fallbackRecordedBy ?? 'Admin').toString(),
          'paidAt': paidAt,
        };
      }).toList();
    }

    if (fallbackAmount < 1) return [];

    return [
      {
        'amount': fallbackAmount,
        'mode': fallbackMode ?? 'Cash',
        'recordedBy': fallbackRecordedBy ?? 'Admin',
        'paidAt': Timestamp.fromDate(
          _dateOnly(fallbackPaidAt ?? DateTime.now()),
        ),
      },
    ];
  }

  /// Copy advance date/mode/recordedBy onto the linked bill so Total Income
  /// still has them after confirmed_quotations is auto-deleted at checkout.
  Future<void> _syncAdvanceMetadataToBill({
    required String confirmId,
    required Map<String, dynamic> data,
    bool onlyIfBillMissingDate = false,
  }) async {
    final advance = _toDouble(data['advance']);
    if (advance <= 0) return;

    String? billId = data['billId']?.toString();
    if (billId == null || billId.isEmpty) {
      final byConfirm = await _db
          .collection('bills')
          .where('confirmId', isEqualTo: confirmId)
          .limit(1)
          .get();
      if (byConfirm.docs.isNotEmpty) {
        billId = byConfirm.docs.first.id;
      } else {
        final quotationId = data['originalQuotationId']?.toString();
        if (quotationId != null && quotationId.isNotEmpty) {
          final byQuotation = await _db
              .collection('bills')
              .where('originalQuotationId', isEqualTo: quotationId)
              .limit(1)
              .get();
          if (byQuotation.docs.isNotEmpty) {
            billId = byQuotation.docs.first.id;
          }
        }
      }
    }

    // Old bills often have no confirmId / originalQuotationId.
    // Match by guest + stay dates instead.
    if (billId == null || billId.isEmpty) {
      billId = await _findBillIdByGuestStay(data);
    }

    if (billId == null || billId.isEmpty) return;

    if (onlyIfBillMissingDate) {
      final billSnap = await _db.collection('bills').doc(billId).get();
      if (!billSnap.exists) return;
      final billData = billSnap.data()!;
      if (billData['advancePaymentDate'] != null) return;
    }

    final paidAt = data['advancePaymentDate'] is Timestamp
        ? data['advancePaymentDate'] as Timestamp
        : data['advancePaymentDate'] is DateTime
            ? Timestamp.fromDate(data['advancePaymentDate'] as DateTime)
            : null;

    final payments = _normalizeAdvancePayments(
      data['advancePayments'],
      fallbackAmount: advance,
      fallbackMode: data['advancePaymentMode']?.toString(),
      fallbackRecordedBy: data['advanceRecordedBy']?.toString(),
      fallbackPaidAt: paidAt,
    );

    await _db.collection('bills').doc(billId).set({
      'advance': advance,
      'advancePayments': payments,
      'advancePaymentMode':
          data['advancePaymentMode'] ?? payments.first['mode'],
      'advanceRecordedBy':
          data['advanceRecordedBy'] ?? payments.first['recordedBy'],
      if (paidAt != null)
        'advancePaymentDate': paidAt
      else if (payments.first['paidAt'] != null)
        'advancePaymentDate': payments.first['paidAt'],
      'confirmId': confirmId,
      if (data['originalQuotationId'] != null)
        'originalQuotationId': data['originalQuotationId'],
    }, SetOptions(merge: true));
  }

  Future<String?> _findBillIdByGuestStay(Map<String, dynamic> data) async {
    final customerName = data['customerName']?.toString().trim();
    if (customerName == null || customerName.isEmpty) return null;

    DateTime? asDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    bool sameDay(DateTime? a, DateTime? b) {
      if (a == null || b == null) return false;
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }

    final checkIn = asDate(data['checkInDate']);
    final checkOut = asDate(data['checkOutDate']);

    final snap = await _db
        .collection('bills')
        .where('customerName', isEqualTo: customerName)
        .get();

    for (final doc in snap.docs) {
      final bill = doc.data();
      final billIn = asDate(bill['checkInDate']);
      final billOut = asDate(bill['checkOutDate']);
      if (sameDay(checkIn, billIn) && sameDay(checkOut, billOut)) {
        return doc.id;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeAdvancePayments(
    dynamic values, {
    required double fallbackAmount,
    String? fallbackMode,
    String? fallbackRecordedBy,
    Timestamp? fallbackPaidAt,
  }) {
    Timestamp? toTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is DateTime) return Timestamp.fromDate(value);
      return null;
    }

    if (values is List && values.isNotEmpty) {
      return values.whereType<Map>().map((entry) {
        final paidAt = toTimestamp(entry['paidAt']) ?? fallbackPaidAt;
        return {
          'amount': _toDouble(entry['amount']),
          'mode': (entry['mode'] ?? fallbackMode ?? 'Not recorded').toString(),
          'recordedBy':
              (entry['recordedBy'] ?? fallbackRecordedBy ?? 'Admin').toString(),
          if (paidAt != null) 'paidAt': paidAt,
        };
      }).where((payment) => _toDouble(payment['amount']) > 0).toList();
    }

    return [
      {
        'amount': fallbackAmount,
        'mode': fallbackMode ?? 'Not recorded',
        'recordedBy': fallbackRecordedBy ?? 'Admin',
        if (fallbackPaidAt != null) 'paidAt': fallbackPaidAt,
      },
    ];
  }

  List<Map<String, dynamic>> _parseAdvancePayments(dynamic values) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      return null;
    }

    if (values is! List) return [];
    return values.whereType<Map>().map((entry) {
      return {
        'amount': _toDouble(entry['amount']),
        'mode': entry['mode'],
        'recordedBy': entry['recordedBy'],
        'paidAt': parseDate(entry['paidAt']),
      };
    }).toList();
  }

  double _toDouble(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  int _toInt(dynamic value) => _toDouble(value).round();

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// 🔁 SYNC AFTER QUOTATION EDIT
  Future<void> syncAfterQuotationUpdate(
    Map<String, dynamic> updatedQuotation,
  ) async {
    final String quotationId = updatedQuotation['id'];

    final query = await _db
        .collection('confirmed_quotations')
        .where('originalQuotationId', isEqualTo: quotationId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final docId = query.docs.first.id;

    final paymentList = updatedQuotation['advancePayments'] is List
        ? _firestoreAdvancePayments(
            (updatedQuotation['advancePayments'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(),
          )
        : null;

    final dataToUpdate = {
      'customerName': updatedQuotation['customerName'],
      'phone1': updatedQuotation['phone1'],
      'phone2': updatedQuotation['phone2'] ?? '',
      if (updatedQuotation.containsKey('advance'))
        'advance': updatedQuotation['advance'] ?? 0,
      if (paymentList != null) ...{
        'advancePayments': paymentList,
        if (paymentList.isNotEmpty) ...{
          'advancePaymentMode': paymentList.last['mode'],
          'advanceRecordedBy': paymentList.last['recordedBy'],
          'advancePaymentDate': paymentList.last['paidAt'],
        },
      } else if (updatedQuotation['advancePaymentDate'] is DateTime) ...{
        'advancePaymentDate': Timestamp.fromDate(
          _dateOnly(updatedQuotation['advancePaymentDate'] as DateTime),
        ),
        'advancePayments': [
          {
            'amount': _toDouble(updatedQuotation['advance']),
            'mode': updatedQuotation['advancePaymentMode'] ?? 'Not recorded',
            'recordedBy': updatedQuotation['advanceRecordedBy'] ?? 'Admin',
            'paidAt': Timestamp.fromDate(
              _dateOnly(updatedQuotation['advancePaymentDate'] as DateTime),
            ),
          },
        ],
      },
      if (updatedQuotation.containsKey('advancePaymentMode') &&
          paymentList == null)
        'advancePaymentMode': updatedQuotation['advancePaymentMode'],
      if (updatedQuotation.containsKey('advanceRecordedBy') &&
          paymentList == null)
        'advanceRecordedBy': updatedQuotation['advanceRecordedBy'],
      'address': updatedQuotation['address'] ?? '',
      'package': updatedQuotation['package'],
      'checkInDate': updatedQuotation['checkInDate'] is DateTime
          ? Timestamp.fromDate(updatedQuotation['checkInDate'])
          : updatedQuotation['checkInDate'],
      'checkOutDate': updatedQuotation['checkOutDate'] is DateTime
          ? Timestamp.fromDate(updatedQuotation['checkOutDate'])
          : updatedQuotation['checkOutDate'],
      'checkInTime': updatedQuotation['checkInTime'] ?? '',
      'checkOutTime': updatedQuotation['checkOutTime'] ?? '',
      'totalPax': updatedQuotation['totalPax'] ?? 0,
      'discount': updatedQuotation['discount'] ?? 0,
      'extraPersons': updatedQuotation['extraPersons'] ?? 0,
      'extraTotal': updatedQuotation['extraTotal'] ?? 0,
      'extraPersonPrice': updatedQuotation['extraPersonPrice'] ?? 0,
      'amount': updatedQuotation['amount'] ?? 0,
      'total': updatedQuotation['total'] ?? 0,
      if (updatedQuotation.containsKey('gstPercent'))
        'gstPercent': updatedQuotation['gstPercent'] ?? 18,
      'facilities': updatedQuotation['facilities'] ?? [],
      'rooms': updatedQuotation['rooms'] ?? [],
    };

    await _db
        .collection('confirmed_quotations')
        .doc(docId)
        .update(dataToUpdate);

    if (updatedQuotation.containsKey('advancePaymentDate') ||
        updatedQuotation.containsKey('advancePaymentMode') ||
        updatedQuotation.containsKey('advanceRecordedBy') ||
        updatedQuotation.containsKey('advance') ||
        updatedQuotation.containsKey('advancePayments')) {
      final snap =
          await _db.collection('confirmed_quotations').doc(docId).get();
      if (snap.exists) {
        await _syncAdvanceMetadataToBill(
          confirmId: docId,
          data: snap.data()!,
        );
      }
    }
  }

  /// ❌ REMOVE IF QUOTATION HISTORY DELETES
  Future<void> removeByOriginalId(String quotationId) async {
    final query = await _db
        .collection('confirmed_quotations')
        .where('originalQuotationId', isEqualTo: quotationId)
        .get();

    for (var doc in query.docs) {
      await _db.collection('confirmed_quotations').doc(doc.id).delete();
    }
  }

  /// ❌ MANUAL DELETE FROM CONFIRM SCREEN
  Future<void> deleteConfirmed(String confirmId) async {
    await _db.collection('confirmed_quotations').doc(confirmId).delete();
  }

  Future<void> markBillGenerated({
    required String confirmId,
    required String billId,
  }) async {
    await _db.collection('confirmed_quotations').doc(confirmId).update({
      'billGenerated': true,
      'billId': billId,
    });

    final confirmSnap =
        await _db.collection('confirmed_quotations').doc(confirmId).get();
    if (confirmSnap.exists) {
      await _syncAdvanceMetadataToBill(
        confirmId: confirmId,
        data: {
          ...confirmSnap.data()!,
          'billId': billId,
        },
      );
    }
  }
}
