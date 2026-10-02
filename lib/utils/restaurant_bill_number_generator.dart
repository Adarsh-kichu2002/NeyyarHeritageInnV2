import 'package:cloud_firestore/cloud_firestore.dart';

/// Generates the next Restaurant bill number independently from Homestay.
class RestaurantBillNumberGenerator {
  RestaurantBillNumberGenerator({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collection = 'restaurant_bills';

  /// Safe next number using max(billNumber) + 1.
  Future<int> nextBillNumber() async {
    final snapshot = await _db
        .collection(collection)
        .orderBy('billNumber', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return 1;

    final last = snapshot.docs.first.data()['billNumber'];
    final lastNo = last is num
        ? last.toInt()
        : int.tryParse(last?.toString() ?? '') ?? 0;
    return lastNo + 1;
  }
}
