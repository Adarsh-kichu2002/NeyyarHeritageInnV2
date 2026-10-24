import 'restaurant_report_item_model.dart';

class StockReportRow {
  final RestaurantItemModel item;
  final int totalAdded;
  final int totalSold;
  final int balance;

  const StockReportRow({
    required this.item,
    required this.totalAdded,
    required this.totalSold,
    required this.balance,
  });

  bool get isLowStock =>
      item.minimumStock > 0 && balance <= item.minimumStock;

  String get unit => item.unit;
}

class StockSummaryData {
  final int itemCount;
  final int? totalAdded;
  final int? totalSold;
  final int? totalBalance;
  final String? commonUnit;
  final bool hasMixedUnits;

  const StockSummaryData({
    required this.itemCount,
    this.totalAdded,
    this.totalSold,
    this.totalBalance,
    this.commonUnit,
    this.hasMixedUnits = false,
  });
}
