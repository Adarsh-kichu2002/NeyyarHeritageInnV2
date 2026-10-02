class RestaurantBillItem {
  final String itemName;
  final int quantity;
  final double price;
  final double total;
  final bool isManual;
  final String? masterItemId;

  const RestaurantBillItem({
    required this.itemName,
    required this.quantity,
    required this.price,
    required this.total,
    this.isManual = false,
    this.masterItemId,
  });

  factory RestaurantBillItem.fromMap(Map<String, dynamic> data) {
    final qty = _toInt(data['quantity'] ?? data['qty']);
    final price = _toDouble(data['price']);
    final total = data['total'] != null
        ? _toDouble(data['total'])
        : qty * price;
    return RestaurantBillItem(
      itemName: (data['itemName'] ?? data['name'] ?? '').toString(),
      quantity: qty,
      price: price,
      total: total,
      isManual: data['isManual'] == true,
      masterItemId: data['masterItemId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'itemName': itemName,
        'quantity': quantity,
        'price': price,
        'total': total,
        'isManual': isManual,
        if (masterItemId != null) 'masterItemId': masterItemId,
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
}

class RestaurantBill {
  final String id;
  final int billNumber;
  final String customerName;
  final String phoneNumber;
  final String address;
  final String gstNumber;
  final List<RestaurantBillItem> items;
  final double grandTotal;
  final DateTime? createdAt;

  const RestaurantBill({
    required this.id,
    required this.billNumber,
    required this.customerName,
    required this.phoneNumber,
    required this.address,
    required this.gstNumber,
    required this.items,
    required this.grandTotal,
    this.createdAt,
  });

  factory RestaurantBill.fromMap(String id, Map<String, dynamic> data) {
    final rawItems = data['items'] as List? ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => RestaurantBillItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    return RestaurantBill(
      id: id,
      billNumber: RestaurantBillItem._toInt(data['billNumber']),
      customerName: (data['customerName'] ?? '').toString(),
      phoneNumber: (data['phoneNumber'] ?? data['phone1'] ?? '').toString(),
      address: (data['address'] ?? '').toString(),
      gstNumber: (data['gstNumber'] ?? data['customerGst'] ?? '').toString(),
      items: items,
      grandTotal: RestaurantBillItem._toDouble(data['grandTotal']),
      createdAt: _asDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'billNumber': billNumber,
        'customerName': customerName,
        'phoneNumber': phoneNumber,
        'address': address,
        'gstNumber': gstNumber,
        'items': items.map((e) => e.toMap()).toList(),
        'grandTotal': grandTotal,
      };

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
