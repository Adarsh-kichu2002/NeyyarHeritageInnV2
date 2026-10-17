import '../models/restaurant_item_model.dart';
import '../models/stock_entry_model.dart';
import '../models/stock_report_row.dart';
import '../utils/restaurant_stock_utils.dart';

/// Sales and balance calculations from stock entries and restaurant bills.
class RestaurantReportService {
  /// Computes sold quantity for [itemId] from restaurant bill data.
  /// Prefers `masterItemId` match; falls back to normalised item name.
  int calculateSoldForItem({
    required String itemId,
    required String itemName,
    required List<Map<String, dynamic>> bills,
    DateTime? from,
    DateTime? to,
  }) {
    var total = 0;
    final normalizedName = normalizeItemName(itemName);

    for (final bill in bills) {
      final createdAt = bill['createdAt'];
      if (createdAt is! DateTime) continue;
      if (!isWithinDateRange(createdAt, from: from, to: to)) continue;

      final rawItems = bill['items'] as List? ?? const [];
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final qty = _toInt(item['quantity'] ?? item['qty']);
        if (qty <= 0) continue;

        final masterId = item['masterItemId']?.toString();
        if (masterId != null && masterId.isNotEmpty) {
          if (masterId == itemId) total += qty;
          continue;
        }

        final billName =
            (item['itemName'] ?? item['name'] ?? '').toString();
        if (normalizeItemName(billName) == normalizedName) {
          total += qty;
        }
      }
    }
    return total;
  }

  int calculateAddedForItem({
    required String itemId,
    required List<StockEntryModel> entries,
    DateTime? from,
    DateTime? to,
  }) {
    return entries
        .where((e) => e.itemId == itemId)
        .where((e) => isWithinDateRange(e.date, from: from, to: to))
        .fold<int>(0, (sum, e) => sum + e.quantity);
  }

  StockReportRow buildReportRow({
    required RestaurantItemModel item,
    required List<StockEntryModel> entries,
    required List<Map<String, dynamic>> bills,
    DateTime? from,
    DateTime? to,
  }) {
    final added = calculateAddedForItem(
      itemId: item.id,
      entries: entries,
      from: from,
      to: to,
    );
    final sold = calculateSoldForItem(
      itemId: item.id,
      itemName: item.name,
      bills: bills,
      from: from,
      to: to,
    );
    return StockReportRow(
      item: item,
      totalAdded: added,
      totalSold: sold,
      balance: added - sold,
    );
  }

  List<StockReportRow> buildReportRows({
    required List<RestaurantItemModel> items,
    required List<StockEntryModel> entries,
    required List<Map<String, dynamic>> bills,
    DateTime? from,
    DateTime? to,
    String searchQuery = '',
    String filterItemQuery = '',
  }) {
    final activeItems = items.where((i) => i.isActive).toList();

    var filtered = activeItems;
    final combinedSearch = filterItemQuery.trim().isNotEmpty
        ? filterItemQuery
        : searchQuery;
    if (combinedSearch.trim().isNotEmpty) {
      filtered = searchItems(filtered, combinedSearch, (i) => i.name);
    }

    return filtered
        .map((item) => buildReportRow(
              item: item,
              entries: entries,
              bills: bills,
              from: from,
              to: to,
            ))
        .toList()
      ..sort((a, b) => a.item.name.compareTo(b.item.name));
  }

  StockSummaryData buildSummary(List<StockReportRow> rows) {
    if (rows.isEmpty) {
      return const StockSummaryData(itemCount: 0, hasMixedUnits: false);
    }

    final units = rows.map((r) => r.unit.trim()).toSet();
    final hasMixedUnits = units.length > 1;

    if (hasMixedUnits) {
      return StockSummaryData(
        itemCount: rows.length,
        hasMixedUnits: true,
      );
    }

    final unit = units.first;
    final added = rows.fold<int>(0, (s, r) => s + r.totalAdded);
    final sold = rows.fold<int>(0, (s, r) => s + r.totalSold);
    final balance = rows.fold<int>(0, (s, r) => s + r.balance);

    return StockSummaryData(
      itemCount: rows.length,
      totalAdded: added,
      totalSold: sold,
      totalBalance: balance,
      commonUnit: unit,
      hasMixedUnits: false,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}
