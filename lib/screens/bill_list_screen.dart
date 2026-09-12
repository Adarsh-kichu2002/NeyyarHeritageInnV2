import 'package:flutter/material.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  Map<String, dynamic> data = {};
  bool _initialized = false;

  /// 🔴 ADVANCE (READ ONLY)
  int advanceAmount = 0;

  /// 🟢 DISCOUNT (EDITABLE)
  final discountCtrl = TextEditingController(text: '0');

  final List<Map<String, dynamic>> items = [];

  static const List<int> _gstOptions = [0, 5, 18];

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  int _defaultGstPercent(String name) {
    if (name.trim().toLowerCase() == 'mineral water') return 0;
    return 5;
  }

  int _normalizeGstPercent(dynamic value, String name) {
    final parsed = _toInt(value, -1);
    if (_gstOptions.contains(parsed)) return parsed;
    return _defaultGstPercent(name);
  }

  int _itemLineNet(Map<String, dynamic> item) {
    final qty = int.tryParse(item['qty'].toString()) ?? 0;
    final price = int.tryParse(item['price'].toString()) ?? 0;
    return qty * price;
  }

  int _itemGstAmount(Map<String, dynamic> item) {
    final percent =
        _toInt(item['gstPercent'], _defaultGstPercent('${item['name']}'));
    return (_itemLineNet(item) * percent / 100).round();
  }

  /// Line total = (price × qty) + GST
  int _itemLineTotal(Map<String, dynamic> item) {
    return _itemLineNet(item) + _itemGstAmount(item);
  }

  Map<String, dynamic> _createItem(String name, int qty, int price,
      {int? gstPercent}) {
    final percent = gstPercent ?? _defaultGstPercent(name);
    return {
      'name': name,
      'qty': qty,
      'price': price,
      'gstPercent': percent,
      'nameCtrl': TextEditingController(text: name),
      'qtyCtrl': TextEditingController(text: qty.toString()),
      'priceCtrl': TextEditingController(text: price.toString()),
    };
  }

  /// DEFAULT ITEMS
  final List<Map<String, dynamic>> defaultItems = [
    {'name': 'Mineral Water', 'qty': 0, 'price': 20},
    {'name': 'Soda', 'qty': 0, 'price': 40},
    {'name': 'Tea', 'qty': 0, 'price': 20},
    {'name': 'Coffee', 'qty': 0, 'price': 25},
    {'name': 'Porotta', 'qty': 0, 'price': 15},
    {'name': 'Chicken Roast', 'qty': 0, 'price': 250},
    {'name': 'Chicken Fry', 'qty': 0, 'price': 250},
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    data = Map<String, dynamic>.from(
      ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
    );
    final bool isEdit = data['isEdit'] == true;

    // Lock billId once on this screen so Preview after Back reuses it.
    final existingBillId = data['billId']?.toString() ?? '';
    if (existingBillId.isEmpty) {
      data['billId'] = DateTime.now().millisecondsSinceEpoch.toString();
    }

    /// 🔴 GET ADVANCE FROM QUOTATION (READ ONLY)
    advanceAmount = _toInt(data['advance']);

    /// 🟢 LOAD DISCOUNT IF EXISTS
    discountCtrl.text = _toInt(data['discount']).toString();

    items.clear();

    /// ===============================
    /// EDIT MODE
    /// ===============================
    if (isEdit && data['items'] != null) {
      final savedItems = (data['items'] as List).map((e) {
        final item = Map<String, dynamic>.from(e);
        final name = item['name']?.toString() ?? '';
        item['qty'] = _toInt(item['qty']);
        item['price'] = _toInt(item['price']);
        item['gstPercent'] = _normalizeGstPercent(item['gstPercent'], name);
        item['nameCtrl'] = TextEditingController(text: name);
        item['qtyCtrl'] =
            TextEditingController(text: item['qty'].toString());
        item['priceCtrl'] =
            TextEditingController(text: item['price'].toString());
        return item;
      }).toList();

      items.addAll(savedItems);

      for (final defaultItem in defaultItems) {
        final exists =
            savedItems.any((e) => e['name'] == defaultItem['name']);

        if (!exists) {
          items.add(_createItem(
              defaultItem['name'] as String,
              _toInt(defaultItem['qty']),
              _toInt(defaultItem['price'])));
        }
      }

      return;
    }

    /// ===============================
    /// CREATE MODE
    /// ===============================
    final rooms = (data['rooms'] ?? []) as List;

    for (final r in rooms.where((r) => r['selected'] == true)) {
      items.add(_createItem(
        r['name']?.toString() ?? '',
        _toInt(r['qty'], 1),
        _toInt(r['price']),
      ));
    }

    if (_toInt(data['extraTotal']) > 0) {
      items.add(_createItem(
        'Extra Persons',
        _toInt(data['extraPersons'], 1),
        _toInt(data['extraPersonPrice']),
      ));
    }

    items.addAll(defaultItems.map(
        (e) => _createItem(
              e['name'] as String,
              _toInt(e['qty']),
              _toInt(e['price']),
            )));
  }

  /// ===============================
  /// CALCULATIONS
  /// ===============================

  /// Grand total including GST (sum of line totals)
  int get total => items.fold(0, (s, i) => s + _itemLineTotal(i));

  int get discount => int.tryParse(discountCtrl.text) ?? 0;

  /// Sum of per-item GST amounts
  int get gst => items.fold(0, (s, i) => s + _itemGstAmount(i));

  /// Final balance (total already includes GST)
  int get balance {
    final amount = total - discount - advanceAmount;
    return amount < 0 ? 0 : amount;
  }

  void _addItem() {
    setState(() {
      items.add(_createItem('', 1, 0));
    });
  }

  void _removeItem(int index) {
    final item = items[index];
    item['nameCtrl']?.dispose();
    item['qtyCtrl']?.dispose();
    item['priceCtrl']?.dispose();

    setState(() {
      items.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bill Items')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => _itemEditor(i),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            ),

            const Divider(),

            /// 🔴 ADVANCE (READ ONLY)
            _amountRow('Advance', advanceAmount),

            /// 🟢 DISCOUNT FIELD
            TextField(
              controller: discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Discount'),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 8),

            _amountRow('GST', gst),
            _amountRow('Total', total),
            _amountRow('Balance', balance, bold: true),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('Preview Bill'),
                onPressed: () {
                  final previewItems = items
                      .where((i) =>
                          (int.tryParse(i['qty'].toString()) ?? 0) > 0)
                      .map((i) {
                    final qty = int.tryParse(i['qty'].toString()) ?? 0;
                    final price =
                        int.tryParse(i['price'].toString()) ?? 0;
                    final gstPercent = _normalizeGstPercent(
                      i['gstPercent'],
                      '${i['name']}',
                    );
                    final net = qty * price;
                    final gstAmount = (net * gstPercent / 100).round();
                    final lineTotal = net + gstAmount;
                    return {
                      'name': i['name'],
                      'qty': qty,
                      'price': price,
                      'gstPercent': gstPercent,
                      'gstAmount': gstAmount,
                      'lineTotal': lineTotal,
                    };
                  }).toList();

                  final billId = (data['billId']?.toString().isNotEmpty == true)
                      ? data['billId'].toString()
                      : DateTime.now().millisecondsSinceEpoch.toString();
                  // Persist so a later Preview (after Back) updates the same bill.
                  data['billId'] = billId;

                  final billData = {
                    ...data,
                    'items': previewItems,
                    /// Total including GST (shown as "Total" on bill)
                    'subtotal': total,
                    'gst': gst,
                    'advance': advanceAmount,
                    'discount': discount,
                    'balance': balance,
                    'billId': billId,
                  };

                  Navigator.pushNamed(
                    context,
                    '/bill_preview',
                    arguments: billData,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var item in items) {
      item['nameCtrl']?.dispose();
      item['qtyCtrl']?.dispose();
      item['priceCtrl']?.dispose();
    }
    discountCtrl.dispose();
    super.dispose();
  }

  Widget _itemEditor(int index) {
    final item = items[index];
    final gstPercent =
        _normalizeGstPercent(item['gstPercent'], '${item['name']}');
    item['gstPercent'] = gstPercent;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TextField(
              controller: item['nameCtrl'],
              decoration: const InputDecoration(labelText: 'Item Name'),
              onChanged: (v) {
                final previous = '${item['name']}';
                item['name'] = v;
                final wasMineral =
                    previous.trim().toLowerCase() == 'mineral water';
                final isMineral = v.trim().toLowerCase() == 'mineral water';
                if (wasMineral != isMineral) {
                  item['gstPercent'] = _defaultGstPercent(v);
                }
                setState(() {});
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item['qtyCtrl'],
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item['qty'] = int.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item['priceCtrl'],
                    decoration: const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item['price'] = int.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'GST %',
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: gstPercent,
                        items: _gstOptions
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text('$p%'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => item['gstPercent'] = value);
                        },
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 48),
                child: Text(
                  'GST ₹${_itemGstAmount(item)}  ·  Total ₹${_itemLineTotal(item)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, int value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text(
          '₹$value',
          style: TextStyle(fontWeight: bold ? FontWeight.bold : null),
        ),
      ],
    );
  }
}
