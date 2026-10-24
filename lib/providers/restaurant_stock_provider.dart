import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/restaurant_bill_service.dart';
import '../models/restaurant_report_item_model.dart';
import '../models/stock_activity_model.dart';
import '../models/stock_entry_model.dart';
import '../models/stock_report_row.dart';
import '../services/restaurant_report_service.dart';
import '../services/restaurant_stock_service.dart';
import '../utils/restaurant_stock_utils.dart';

class RestaurantStockProvider extends ChangeNotifier {
  RestaurantStockProvider({
    RestaurantStockService? stockService,
    RestaurantReportService? reportService,
    RestaurantBillStore? billStore,
  })  : _stockService = stockService ?? RestaurantStockService(),
        _reportService = reportService ?? RestaurantReportService(),
        _billStore = billStore;

  final RestaurantStockService _stockService;
  final RestaurantReportService _reportService;
  final RestaurantBillStore? _billStore;

  List<RestaurantItemModel> _items = [];
  List<StockEntryModel> _entries = [];
  bool isLoading = true;
  String? errorMessage;

  String _searchQuery = '';
  String _filterItemQuery = '';
  DateTime? _fromDate;
  DateTime? _toDate;

  StreamSubscription<List<RestaurantItemModel>>? _itemsSub;
  StreamSubscription<List<StockEntryModel>>? _entriesSub;
  bool _isListening = false;

  String get searchQuery => _searchQuery;
  String get filterItemQuery => _filterItemQuery;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  bool get hasActiveFilters =>
      _filterItemQuery.isNotEmpty || _fromDate != null || _toDate != null;

  List<RestaurantItemModel> get items => List.unmodifiable(_items);
  List<StockEntryModel> get entries => List.unmodifiable(_entries);

  List<RestaurantItemModel> get activeItems =>
      _items.where((i) => i.isActive).toList();

  void startListening() {
    if (_isListening) return;
    _isListening = true;
    _itemsSub = _stockService.watchItems().listen(
      (items) {
        _items = items;
        isLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('RestaurantStockProvider items error: $e');
        isLoading = false;
        errorMessage = 'Could not load restaurant items.';
        notifyListeners();
      },
    );

    _entriesSub = _stockService.watchStockEntries().listen(
      (entries) {
        _entries = entries;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('RestaurantStockProvider entries error: $e');
        errorMessage = 'Could not load stock entries.';
        notifyListeners();
      },
    );

    _billStore?.addListener(_onBillsChanged);
  }

  void stopListening() {
    if (!_isListening) return;
    _isListening = false;
    final itemsSub = _itemsSub;
    final entriesSub = _entriesSub;
    _itemsSub = null;
    _entriesSub = null;
    if (itemsSub != null) unawaited(itemsSub.cancel());
    if (entriesSub != null) unawaited(entriesSub.cancel());
    _billStore?.removeListener(_onBillsChanged);
  }

  void _onBillsChanged() => notifyListeners();

  List<Map<String, dynamic>> get _bills =>
      _billStore?.bills ?? const [];

  List<StockReportRow> get reportRows => _reportService.buildReportRows(
        items: _items,
        entries: _entries,
        bills: _bills,
        from: _fromDate,
        to: _toDate,
        searchQuery: _searchQuery,
        filterItemQuery: _filterItemQuery,
      );

  StockSummaryData get summary => _reportService.buildSummary(reportRows);

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void applyFilters({
    String? itemQuery,
    DateTime? from,
    DateTime? to,
  }) {
    _filterItemQuery = itemQuery ?? '';
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void clearFilters() {
    _filterItemQuery = '';
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  /// Clears report-only search and date filters without rebuilding listeners.
  /// Used when the reports route is being disposed.
  void resetReportView() {
    _searchQuery = '';
    _filterItemQuery = '';
    _fromDate = null;
    _toDate = null;
  }

  List<RestaurantItemModel> searchItemsForAutocomplete(String query) {
    return searchItems(activeItems, query, (i) => i.name);
  }

  StockReportRow? reportRowForItem(String itemId) {
    final item = _items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return null;
    return _reportService.buildReportRow(
      item: item,
      entries: _entries,
      bills: _bills,
      from: _fromDate,
      to: _toDate,
    );
  }

  List<StockActivity> stockHistoryForItem(String itemId) {
    final item = _items.where((item) => item.id == itemId).firstOrNull;
    if (item == null) return const [];
    return _activitiesForItem(item).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<StockActivity> get visibleStockActivities {
    final query = _searchQuery.trim();
    final result = <StockActivity>[];
    for (final item in _items) {
      if (!_matchesActivityItem(item, query) ||
          !_matchesActivityItem(item, _filterItemQuery)) continue;
      for (final activity in _activitiesForItem(item)) {
        if (!isWithinDateRange(activity.date, from: _fromDate, to: _toDate)) {
          continue;
        }
        result.add(activity);
      }
    }
    final itemIds = _items.map((item) => item.id).toSet();
    for (final entry in _entries.where((entry) => !itemIds.contains(entry.itemId))) {
      if ((query.isNotEmpty && !matchesItemSearch(entry.itemName, query)) ||
          (_filterItemQuery.isNotEmpty &&
              !matchesItemSearch(entry.itemName, _filterItemQuery)) ||
          !isWithinDateRange(entry.date, from: _fromDate, to: _toDate)) {
        continue;
      }
      result.add(StockActivity.fromStockEntry(entry));
    }
    result
      ..sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  bool _matchesActivityItem(RestaurantItemModel item, String query) =>
      query.trim().isEmpty || matchesItemSearch(item.name, query);

  Iterable<StockActivity> _activitiesForItem(RestaurantItemModel item) sync* {
    for (final entry in _entries.where((entry) => entry.itemId == item.id)) {
      yield StockActivity.fromStockEntry(entry);
    }

    final normalizedName = normalizeItemName(item.name);
    for (final bill in _bills) {
      final createdAt = bill['createdAt'];
      if (createdAt is! DateTime) continue;
      final rawItems = bill['items'] as List? ?? const [];
      for (var index = 0; index < rawItems.length; index++) {
        final raw = rawItems[index];
        if (raw is! Map) continue;
        final billItem = Map<String, dynamic>.from(raw);
        final quantity = _toInt(billItem['quantity'] ?? billItem['qty']);
        if (quantity <= 0) continue;

        final masterId = billItem['masterItemId']?.toString();
        final matches = masterId != null && masterId.isNotEmpty
            ? masterId == item.id
            : normalizeItemName(
                    (billItem['itemName'] ?? billItem['name'] ?? '').toString()) ==
                normalizedName;
        if (!matches) continue;

        final billNumber = (bill['billNumber'] ?? '').toString().trim();
        yield StockActivity(
          id: '${bill['billId'] ?? bill['id'] ?? 'bill'}_$index',
          itemId: item.id,
          itemName: item.name,
          quantity: quantity,
          unit: item.unit,
          date: createdAt,
          type: StockActivityType.sold,
          note: billNumber.isEmpty ? 'Bill sale' : 'Bill #$billNumber',
        );
      }
    }
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<RestaurantItemModel> createItem({
    required String name,
    required String category,
    required String unit,
    required int minimumStock,
  }) {
    return _stockService.createItem(
      name: name,
      category: category,
      unit: unit,
      minimumStock: minimumStock,
    );
  }

  Future<StockEntryModel> addStock({
    required RestaurantItemModel item,
    required int quantity,
    required DateTime date,
    required String note,
  }) {
    return _stockService.addStockEntry(
      itemId: item.id,
      itemName: item.name,
      quantity: quantity,
      unit: item.unit,
      date: date,
      note: note,
    );
  }

  Future<void> updateStockEntry({
    required StockEntryModel entry,
    required int quantity,
    required DateTime date,
    required String note,
  }) => _stockService.updateStockEntry(
        entryId: entry.id,
        quantity: quantity,
        date: date,
        note: note,
      );

  Future<void> deleteStockEntry(String entryId) =>
      _stockService.deleteStockEntry(entryId);

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
