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
    return _confirmed.any(
      (q) => q['originalQuotationId'] == quotationId,
    );
  }

  /// 🔥 REAL-TIME LISTENER
  /// 1️⃣ AUTO REMOVE AFTER CHECKOUT DAY ENDS
  /// 2️⃣ SORT BY NEAREST CHECK-IN DATE
  void fetchConfirmed() {
    _db
        .collection('confirmed_quotations')
        .snapshots()
        .listen((snapshot) async {
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
          final checkoutEnd =
              DateTime(checkOut.year, checkOut.month, checkOut.day, 23, 59, 59);

          if (now.isAfter(checkoutEnd)) {
            await _db
                .collection('confirmed_quotations')
                .doc(doc.id)
                .delete();
            continue; // skip adding
          }
        }

        tempList.add({
          'confirmId': doc.id,
          'originalQuotationId': data['originalQuotationId'],
          'customerName': data['customerName'],
          'phone1': data['phone1'],
          'phone2': data['phone2'] ?? '',
          'advance': data['advance'] ?? 0,
          'address': data['address'] ?? '',
          'package': data['package'],
          'checkInDate': parseDate(data['checkInDate']),
          'checkOutDate': parseDate(data['checkOutDate']),
          'checkInTime': data['checkInTime'] ?? '',
          'checkOutTime': data['checkOutTime'] ?? '',
          'rooms': data['rooms'] ?? [],
          'adult': data['adult'] ?? 0,
          'children': data['children'] ?? 0,
          'child': data['child'] ?? 0,
          'totalPax': data['totalPax'] ?? 0,
          'discount': data['discount'] ?? 0,
          'extraPersons': data['extraPersons'] ?? 0,
          'extraTotal': data['extraTotal'] ?? 0,
          'extraPersonPrice': data['extraPersonPrice'] ?? 0,
          'amount': data['amount'] ?? 0,
          'total': data['total'] ?? data['amount'] ?? 0,
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
  Future<void> confirmQuotation(Map<String, dynamic> q) async {
    final String quotationId = q['id'];
    if (isConfirmed(quotationId)) return;

    await _db.collection('confirmed_quotations').add({
      'originalQuotationId': quotationId,

      'customerName': q['customerName'],
      'phone1': q['phone1'],
      'phone2': q['phone2'] ?? '',
      'advance': q['advance'] ?? 0,
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

  /// 🔁 SYNC AFTER QUOTATION EDIT
  Future<void> syncAfterQuotationUpdate(
      Map<String, dynamic> updatedQuotation) async {
    final String quotationId = updatedQuotation['id'];

    final query = await _db
        .collection('confirmed_quotations')
        .where('originalQuotationId', isEqualTo: quotationId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return;

    final docId = query.docs.first.id;

    await _db.collection('confirmed_quotations').doc(docId).update({
      'customerName': updatedQuotation['customerName'],
      'phone1': updatedQuotation['phone1'],
      'phone2': updatedQuotation['phone2'] ?? '',
      'advance': updatedQuotation['advance'] ?? 0,
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
      'facilities': updatedQuotation['facilities'] ?? [],
      'rooms': updatedQuotation['rooms'] ?? [],
    });
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
  await _db
      .collection('confirmed_quotations')
      .doc(confirmId)
      .update({
    'billGenerated': true,
    'billId': billId,
  });
}
}
