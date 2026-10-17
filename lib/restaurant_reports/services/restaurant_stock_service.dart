import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/restaurant_item_model.dart';
import '../models/stock_entry_model.dart';

/// Firestore CRUD for restaurant stock items and stock entries.
class RestaurantStockService {
  RestaurantStockService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String itemsCollection = 'restaurant_items';
  static const String entriesCollection = 'restaurant_stock_entries';

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<RestaurantItemModel>> watchItems() {
    return _db
        .collection(itemsCollection)
        .orderBy('name')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RestaurantItemModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Stream<List<StockEntryModel>> watchStockEntries() {
    return _db
        .collection(entriesCollection)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StockEntryModel.fromMap(doc.id, doc.data()))
            .toList());
  }

  Future<RestaurantItemModel> createItem({
    required String name,
    required String category,
    required String unit,
    required int minimumStock,
    double price = 0,
  }) async {
    final docRef = _db.collection(itemsCollection).doc();
    final data = {
      'name': name.trim(),
      'category': category.trim(),
      'unit': unit.trim(),
      'minimumStock': minimumStock,
      'isActive': true,
      'price': price,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (_currentUserId != null) 'createdBy': _currentUserId,
    };
    await docRef.set(data);
    final snap = await docRef.get();
    return RestaurantItemModel.fromMap(docRef.id, snap.data() ?? data);
  }

  Future<StockEntryModel> addStockEntry({
    required String itemId,
    required String itemName,
    required int quantity,
    required String unit,
    required DateTime date,
    required String note,
  }) async {
    final docRef = _db.collection(entriesCollection).doc();
    final data = {
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'date': Timestamp.fromDate(date),
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      if (_currentUserId != null) 'createdBy': _currentUserId,
    };
    await docRef.set(data);
    final snap = await docRef.get();
    final saved = snap.data() ?? data;
    return StockEntryModel.fromMap(
      docRef.id,
      {
        ...saved,
        if (saved['date'] is Timestamp)
          'date': (saved['date'] as Timestamp).toDate(),
      },
    );
  }

  Future<void> updateStockEntry({
    required String entryId,
    required int quantity,
    required DateTime date,
    required String note,
  }) async {
    await _db.collection(entriesCollection).doc(entryId).update({
      'quantity': quantity,
      'date': Timestamp.fromDate(date),
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (_currentUserId != null) 'updatedBy': _currentUserId,
    });
  }

  Future<void> deleteStockEntry(String entryId) async {
    await _db.collection(entriesCollection).doc(entryId).delete();
  }

  List<StockEntryModel> entriesForItem(
    List<StockEntryModel> allEntries,
    String itemId,
  ) {
    return allEntries.where((e) => e.itemId == itemId).toList();
  }
}
