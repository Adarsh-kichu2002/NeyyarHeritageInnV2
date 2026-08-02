import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GstStore extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final List<Map<String, dynamic>> _folders = [];
  final List<Map<String, dynamic>> _gstBills = [];
  bool isLoading = true;

  List<Map<String, dynamic>> get folders => List.unmodifiable(_folders);
  List<Map<String, dynamic>> get gstBills => List.unmodifiable(_gstBills);

  GstStore() {
    _listenFolders();
    _listenGstBills();
  }

  static String folderIdFor(int month, int year) {
    return '${year}_${month.toString().padLeft(2, '0')}';
  }

  static String folderLabel(int month, int year) {
    final date = DateTime(year, month);
    return DateFormat('MMMM yyyy').format(date);
  }

  bool isBillSaved(String billId) {
    return _gstBills.any((b) => b['billId'] == billId);
  }

  List<Map<String, dynamic>> billsForFolder(String folderId) {
    final list =
        _gstBills.where((b) => b['folderId'] == folderId).toList();
    list.sort((a, b) {
      final aNo = a['gstInvoiceNo'] as int? ?? 0;
      final bNo = b['gstInvoiceNo'] as int? ?? 0;
      return aNo.compareTo(bNo);
    });
    return list;
  }

  void _listenFolders() {
    _db
        .collection('gst_folders')
        .orderBy('year', descending: true)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'folderId': doc.id,
        };
      }).toList();

      list.sort((a, b) {
        final ay = a['year'] as int? ?? 0;
        final by = b['year'] as int? ?? 0;
        if (ay != by) return by.compareTo(ay);
        final am = a['month'] as int? ?? 0;
        final bm = b['month'] as int? ?? 0;
        return bm.compareTo(am);
      });

      _folders
        ..clear()
        ..addAll(list);

      _updateLoading();
      notifyListeners();
    });
  }

  void _listenGstBills() {
    _db.collection('gst_bills').snapshots().listen((snapshot) {
      _gstBills
        ..clear()
        ..addAll(
          snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'gstBillId': doc.id,
              'checkInDate':
                  (data['checkInDate'] as Timestamp?)?.toDate(),
              'checkOutDate':
                  (data['checkOutDate'] as Timestamp?)?.toDate(),
            };
          }),
        );

      _updateLoading();
      notifyListeners();
    });
  }

  void _updateLoading() {
    isLoading = false;
  }

  Future<int> _nextGstInvoiceNo() async {
    final snapshot = await _db
        .collection('gst_bills')
        .orderBy('gstInvoiceNo', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return 1;

    final last = snapshot.docs.first.data()['gstInvoiceNo'] as int? ?? 0;
    return last + 1;
  }

  /// Save a bill into a GST month folder. Original bill invoice is untouched.
  Future<void> saveBillToGst({
    required Map<String, dynamic> bill,
    required int month,
    required int year,
  }) async {
    final billId = bill['billId']?.toString();
    if (billId == null || billId.isEmpty) {
      throw Exception('billId is required');
    }

    if (isBillSaved(billId)) {
      throw Exception('Bill already saved to GST');
    }

    final folderId = folderIdFor(month, year);
    final gstInvoiceNo = await _nextGstInvoiceNo();

    final folderRef = _db.collection('gst_folders').doc(folderId);
    final folderSnap = await folderRef.get();

    if (!folderSnap.exists) {
      await folderRef.set({
        'month': month,
        'year': year,
        'label': folderLabel(month, year),
        'downloaded': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    final cleanItems = ((bill['items'] as List?) ?? []).map((i) {
      return {
        'name': i['name'],
        'qty': i['qty'],
        'price': i['price'],
      };
    }).toList();

    DateTime? asDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      return null;
    }

    final checkIn = asDate(bill['checkInDate']);
    final checkOut = asDate(bill['checkOutDate']);

    await _db.collection('gst_bills').doc(billId).set({
      'billId': billId,
      'folderId': folderId,
      'month': month,
      'year': year,
      'gstInvoiceNo': gstInvoiceNo,
      'originalInvoiceNo': bill['invoiceNo'],
      'originalInvoiceNoInt': bill['invoiceNoInt'],
      'customerName': bill['customerName'],
      'phone1': bill['phone1'],
      'phone2': bill['phone2'] ?? '',
      'items': cleanItems,
      'subtotal': bill['subtotal'],
      'gst': bill['gst'],
      'gstPercent': bill['gstPercent'] ?? 18,
      'advance': bill['advance'],
      'discount': bill['discount'],
      'balance': bill['balance'],
      'payment': bill['payment'],
      if (checkIn != null) 'checkInDate': Timestamp.fromDate(checkIn),
      if (checkOut != null) 'checkOutDate': Timestamp.fromDate(checkOut),
      'savedAt': FieldValue.serverTimestamp(),
    });

    // Mark on original bill so UI can lock the checkbox (does not change invoice).
    await _db.collection('bills').doc(billId).set({
      'gstSaved': true,
      'gstFolderId': folderId,
      'gstInvoiceNo': gstInvoiceNo,
    }, SetOptions(merge: true));
  }

  Future<void> markFolderDownloaded(String folderId) async {
    await _db.collection('gst_folders').doc(folderId).set({
      'downloaded': true,
      'downloadedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
