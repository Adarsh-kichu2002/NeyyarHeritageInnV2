import 'package:flutter/material.dart';

import '../widgets/restaurant_item_selector.dart';

/// Screen 2 — Restaurant bill line items (no GST column, no advance).
class RestaurantBillItemsScreen extends StatefulWidget {
  const RestaurantBillItemsScreen({super.key});

  @override
  State<RestaurantBillItemsScreen> createState() =>
      _RestaurantBillItemsScreenState();
}

class _RestaurantBillItemsScreenState extends State<RestaurantBillItemsScreen> {
  Map<String, dynamic> data = {};
  final List<Map<String, dynamic>> items = [];
  final _discountCtrl = TextEditingController(text: '0');
  String role = 'staff';
  bool _initialized = false;

  bool get isAdmin => role == 'admin';

  double get itemsTotal => items.fold<double>(
        0,
        (sum, i) => sum + ((i['total'] as num?)?.toDouble() ?? 0),
      );

  double get discount {
    final v = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    return v < 0 ? 0 : v;
  }

  double get grandTotal {
    final total = itemsTotal - discount;
    return total < 0 ? 0 : total;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    data = Map<String, dynamic>.from(
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
          {},
    );
    role = (data['role'] ?? 'staff').toString();
    if (data['discount'] != null) {
      _discountCtrl.text = '${data['discount']}';
    }

    /// Load existing items when editing a saved restaurant bill.
    if (items.isEmpty && data['items'] is List) {
      for (final raw in data['items'] as List) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final qty = (map['quantity'] as num?)?.toInt() ??
            int.tryParse('${map['quantity']}') ??
            0;
        final price = (map['price'] as num?)?.toDouble() ??
            double.tryParse('${map['price']}') ??
            0;
        items.add({
          'itemName': map['itemName'] ?? map['name'] ?? '',
          'quantity': qty,
          'price': price,
          'total': map['total'] ?? (qty * price),
          'isManual': map['isManual'] == true,
          if (map['masterItemId'] != null) 'masterItemId': map['masterItemId'],
        });
      }
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  bool _samePrice(dynamic a, dynamic b) {
    final pa = a is num ? a.toDouble() : double.tryParse('$a') ?? 0;
    final pb = b is num ? b.toDouble() : double.tryParse('$b') ?? 0;
    return (pa - pb).abs() < 0.0001;
  }

  void _addOrMergeItem(Map<String, dynamic> selected) {
    final name = (selected['itemName'] ?? '').toString().trim().toLowerCase();
    final price = selected['price'];
    final addQty = (selected['quantity'] as num?)?.toInt() ?? 0;
    if (name.isEmpty || addQty <= 0) return;

    final existingIndex = items.indexWhere((item) {
      final existingName =
          (item['itemName'] ?? '').toString().trim().toLowerCase();
      return existingName == name && _samePrice(item['price'], price);
    });

    setState(() {
      if (existingIndex >= 0) {
        final existing = items[existingIndex];
        final newQty =
            ((existing['quantity'] as num?)?.toInt() ?? 0) + addQty;
        final unit = (existing['price'] as num?)?.toDouble() ?? 0;
        items[existingIndex] = {
          ...existing,
          'quantity': newQty,
          'total': newQty * unit,
        };
      } else {
        items.add(Map<String, dynamic>.from(selected));
      }
    });
  }

  Future<void> _addItem() async {
    final selected = await showRestaurantItemSelector(
      context,
      isAdmin: isAdmin,
    );
    if (selected == null || !mounted) return;
    _addOrMergeItem(Map<String, dynamic>.from(selected));
  }

  void _editQuantity(int index) async {
    final item = items[index];
    final isManual = item['isManual'] == true;
    final qtyCtrl =
        TextEditingController(text: '${item['quantity'] ?? 1}');
    final priceCtrl = TextEditingController(
      text: '${item['price'] ?? 0}',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('${item['itemName']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
              if (isManual) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Price: ₹${item['price']} (fixed)',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                final price = isManual
                    ? (double.tryParse(priceCtrl.text.trim()) ?? 0)
                    : ((item['price'] as num?)?.toDouble() ?? 0);
                if (qty <= 0 || price <= 0) return;
                Navigator.pop(ctx, {
                  'quantity': qty,
                  'price': price,
                  'total': qty * price,
                });
              },
              child: const Text('Update'),
            ),
          ],
        );
      },
    );

    qtyCtrl.dispose();
    priceCtrl.dispose();
    if (result == null || !mounted) return;
    setState(() {
      items[index] = {
        ...item,
        ...result,
      };
    });
  }

  void _preview() {
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/restaurant_bill_preview',
      arguments: {
        ...data,
        'role': role,
        'items': items
            .map((e) => {
                  'itemName': e['itemName'],
                  'quantity': e['quantity'],
                  'price': e['price'],
                  'total': e['total'],
                  'isManual': e['isManual'] == true,
                  if (e['masterItemId'] != null)
                    'masterItemId': e['masterItemId'],
                })
            .toList(),
        'itemsTotal': itemsTotal,
        'discount': discount,
        'grandTotal': grandTotal,
        'billNumber': data['billNumber'],
      },
    );
  }

  String _money(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Bill Items'),
        // actions: [
        //   if (isAdmin)
        //     IconButton(
        //       tooltip: 'Manage Items',
        //       icon: const Icon(Icons.edit),
        //       onPressed: () {
        //         Navigator.pushNamed(
        //           context,
        //           '/restaurant_item_management',
        //           arguments: {'role': role},
        //         );
        //       },
        //     ),
        // ],
      ),
      floatingActionButton: null,
      body: Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Text(
                      'No items added.\nTap + to add items',
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStatePropertyAll(
                          Theme.of(context).primaryColor,
                        ),
                        columns: [
                          const DataColumn(label: Text('Item')),
                          const DataColumn(label: Text('Quantity'), numeric: true),
                          const DataColumn(label: Text('Price'), numeric: true),
                          const DataColumn(label: Text('Total'), numeric: true),
                          if (isAdmin) const DataColumn(label: Text('')),
                        ],
                        rows: List.generate(items.length, (i) {
                          final item = items[i];
                          return DataRow(
                            cells: [
                              DataCell(
                                Text('${item['itemName']}'),
                                onTap: () => _editQuantity(i),
                              ),
                              DataCell(
                                Text('${item['quantity']}'),
                                onTap: () => _editQuantity(i),
                              ),
                              DataCell(
                                Text('₹${_money(item['price'])}'),
                                onTap: () => _editQuantity(i),
                              ),
                              DataCell(Text('₹${_money(item['total'])}')),
                              if (isAdmin)
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () =>
                                        setState(() => items.removeAt(i)),
                                  ),
                                ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
          ),
          /// + button above discount / bottom bar
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 16, 8),
              child: Material(
                color: Colors.green,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _addItem,
                  child: const SizedBox(
                    width: 52,
                    height: 52,
                    child: Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              color: Colors.green.shade50,
              child: Column(
                children: [
                  TextField(
                    controller: _discountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Discount',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Items Total'),
                      Text('₹${_money(itemsTotal)}'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Discount'),
                      Text('₹${_money(discount)}'),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Grand Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '₹${_money(grandTotal)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _preview,
                      child: const Text('Preview Bill'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
