import 'stock_entry_model.dart';

enum StockActivityType { added, sold }

/// A report-only view of a stock addition or a quantity sold on a bill.
/// Sales are derived from bills and are never written as stock entries.
class StockActivity {
  const StockActivity({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.type,
    required this.note,
    this.stockEntry,
  });

  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final String unit;
  final DateTime date;
  final StockActivityType type;
  final String note;
  final StockEntryModel? stockEntry;

  bool get isSale => type == StockActivityType.sold;

  factory StockActivity.fromStockEntry(StockEntryModel entry) => StockActivity(
        id: entry.id,
        itemId: entry.itemId,
        itemName: entry.itemName,
        quantity: entry.quantity,
        unit: entry.unit,
        date: entry.date,
        type: StockActivityType.added,
        note: entry.note,
        stockEntry: entry,
      );
}
