class StockEntryModel {
  final String id;
  final String itemId;
  final String itemName;
  final int quantity;
  final String unit;
  final DateTime date;
  final String note;
  final DateTime? createdAt;
  final String? createdBy;

  const StockEntryModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.unit,
    required this.date,
    required this.note,
    this.createdAt,
    this.createdBy,
  });

  factory StockEntryModel.fromMap(String id, Map<String, dynamic> data) {
    return StockEntryModel(
      id: id,
      itemId: (data['itemId'] ?? '').toString(),
      itemName: (data['itemName'] ?? '').toString(),
      quantity: _toInt(data['quantity']),
      unit: (data['unit'] ?? 'Unit').toString(),
      date: _asDate(data['date']) ?? DateTime.now(),
      note: (data['note'] ?? '').toString(),
      createdAt: _asDate(data['createdAt']),
      createdBy: data['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap({String? createdBy}) => {
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'unit': unit,
        'date': date,
        'note': note.trim(),
        if (createdBy != null) 'createdBy': createdBy,
      };

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static DateTime? _asDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    try {
      return v.toDate();
    } catch (_) {
      return null;
    }
  }
}
