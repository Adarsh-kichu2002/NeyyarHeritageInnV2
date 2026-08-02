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
    if (quotation['createdAt'] is DateTime) {
      dataToUpdate['createdAt'] =
          Timestamp.fromDate(quotation['createdAt']);
    }

    await _db
        .collection('quotations')
        .doc(quotationId)
        .update(dataToUpdate);
  }

  /// ❌ DELETE QUOTATION
  Future<void> deleteQuotation(String quotationId) async {
    await _db.collection('quotations').doc(quotationId).delete();
  }
}
