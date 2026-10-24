class RestaurantItemModel {
  final String id;
  final String name;
  final String category;
  final String unit;
  final int minimumStock;
  final bool isActive;
  final double price;
  final DateTime? createdAt;
  final String? createdBy;

  const RestaurantItemModel({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.minimumStock,
    required this.isActive,
    this.price = 0,
    this.createdAt,
    this.createdBy,
  });

  factory RestaurantItemModel.fromMap(String id, Map<String, dynamic> data) {
    return RestaurantItemModel(
      id: id,
      name: (data['name'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      unit: (data['unit'] ?? 'Unit').toString(),
      minimumStock: _toInt(data['minimumStock']),
      isActive: data['isActive'] != false,
      price: _toDouble(data['price']),
      createdAt: _asDate(data['createdAt']),
      createdBy: data['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toMap({String? createdBy}) => {
        'name': name.trim(),
        'category': category.trim(),
        'unit': unit.trim(),
        'minimumStock': minimumStock,
        'isActive': isActive,
        'price': price,
        if (createdBy != null) 'createdBy': createdBy,
      };

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
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
