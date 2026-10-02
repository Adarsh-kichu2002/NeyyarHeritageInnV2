import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/restaurant_bill_model.dart';
import '/utils/restaurant_bill_number_generator.dart';
/// Dedicated store for Restaurant Bills (separate from Homestay `bills`).
class RestaurantBillStore extends ChangeNotifier {
  RestaurantBillStore({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance {
    _listen();
  }

  final FirebaseFirestore _db;
  static const String collection = 'restaurant_bills';

  final List<Map<String, dynamic>> _bills = [];
  bool isLoading = true;

  List<Map<String, dynamic>> get bills => List.unmodifiable(_bills);

  void _listen() {
    _db
        .collection(collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      _bills
        ..clear()
        ..addAll(snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'billId': doc.id,
            'createdAt': (data['createdAt'] as Timestamp?)?.toDate(),
          };
        }));
      isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('RestaurantBillStore error: $e');
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> saveBill(Map<String, dynamic> bill) async {
    final billId = bill['billId']?.toString();
    if (billId == null || billId.isEmpty) {
      throw Exception('billId is required to save restaurant bill');
    }

    final items = (bill['items'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => RestaurantBillItem.fromMap(Map<String, dynamic>.from(e)))
        .map((e) => e.toMap())
        .toList();

    final itemsTotal = items.fold<double>(
      0,
      (sum, i) => sum + ((i['total'] as num?)?.toDouble() ?? 0),
    );
    final discount = (bill['discount'] is num)
        ? (bill['discount'] as num).toDouble()
        : double.tryParse('${bill['discount'] ?? 0}') ?? 0;
    final computedGrand = itemsTotal - (discount < 0 ? 0 : discount);
    final grandTotal = bill['grandTotal'] != null
        ? ((bill['grandTotal'] is num)
            ? (bill['grandTotal'] as num).toDouble()
            : double.tryParse('${bill['grandTotal']}') ?? computedGrand)
        : (computedGrand < 0 ? 0 : computedGrand);

    final docRef = _db.collection(collection).doc(billId);
    final snap = await docRef.get();

    await docRef.set({
      'billNumber': bill['billNumber'],
      'customerName': bill['customerName'] ?? '',
      'phoneNumber': bill['phoneNumber'] ?? '',
      'address': bill['address'] ?? '',
      'gstNumber': bill['gstNumber'] ?? '',
      'items': items,
      'itemsTotal': itemsTotal,
      'discount': discount < 0 ? 0 : discount,
      'grandTotal': grandTotal < 0 ? 0 : grandTotal,
      'billSource': 'restaurant',
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<int> nextBillNumber() {
    return RestaurantBillNumberGenerator(db: _db).nextBillNumber();
  }

  Future<void> deleteBill(String billId) async {
    await _db.collection(collection).doc(billId).delete();
  }
}
