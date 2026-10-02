import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/restaurant_item_model.dart';

/// Admin-managed restaurant menu / master items.
class RestaurantItemStore extends ChangeNotifier {
  RestaurantItemStore({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance {
    _listen();
  }

  final FirebaseFirestore _db;
  static const String collection = 'restaurant_items';

  final List<RestaurantItem> _items = [];
  bool isLoading = true;

  List<RestaurantItem> get items => List.unmodifiable(_items);

  void _listen() {
    _db
        .collection(collection)
        .orderBy('name')
        .snapshots()
        .listen((snapshot) {
      _items
        ..clear()
        ..addAll(snapshot.docs.map(
          (doc) => RestaurantItem.fromMap(doc.id, doc.data()),
        ));
      isLoading = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('RestaurantItemStore error: $e');
      isLoading = false;
      notifyListeners();
    });
  }

  List<RestaurantItem> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return items;
    return _items
        .where((item) => item.name.toLowerCase().contains(q))
        .toList();
  }

  Future<void> addItem({required String name, required double price}) async {
    await _db.collection(collection).add({
      'name': name.trim(),
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required double price,
  }) async {
    await _db.collection(collection).doc(id).update({
      'name': name.trim(),
      'price': price,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteItem(String id) async {
    await _db.collection(collection).doc(id).delete();
  }
}
