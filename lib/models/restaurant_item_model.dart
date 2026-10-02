class RestaurantItem {
  final String id;
  final String name;
  final double price;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const RestaurantItem({
    required this.id,
    required this.name,
    required this.price,
    this.createdAt,
    this.updatedAt,
  });

  factory RestaurantItem.fromMap(String id, Map<String, dynamic> data) {
    return RestaurantItem(
      id: id,
      name: (data['name'] ?? '').toString(),
      price: _toDouble(data['price']),
      createdAt: _asDate(data['createdAt']),
      updatedAt: _asDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
      };

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
