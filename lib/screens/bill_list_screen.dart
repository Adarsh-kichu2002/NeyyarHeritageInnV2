import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillListScreen extends StatefulWidget {
  const BillListScreen({super.key});

  @override
  State<BillListScreen> createState() => _BillListScreenState();
}

class _BillListScreenState extends State<BillListScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> data = {};
  bool _initialized = false;

  /// 🔴 ADVANCE (READ ONLY)
  int advanceAmount = 0;

  /// 🟢 DISCOUNT (EDITABLE)
  final discountCtrl = TextEditingController(text: '0');

  /// GST % (default 18, editable)
  final gstPercentCtrl = TextEditingController(text: '18');
  bool _editingGstPercent = false;

  final List<Map<String, dynamic>> items = [];

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  Map<String, dynamic> _createItem(String name, int qty, int price) {
    return {
      'name': name,
      'qty': qty,
      'price': price,
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

    data = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final bool isEdit = data['isEdit'] == true;

    /// 🔴 GET ADVANCE FROM QUOTATION (READ ONLY)
    advanceAmount = _toInt(data['advance']);

    /// 🟢 LOAD DISCOUNT IF EXISTS
    discountCtrl.text = _toInt(data['discount']).toString();

    /// GST % — default 18; keep saved value when editing
    final savedGst = data['gstPercent'];
    gstPercentCtrl.text = savedGst == null
        ? '18'
        : (savedGst is num
            ? (savedGst % 1 == 0
                ? savedGst.toInt().toString()
                : savedGst.toString())
            : savedGst.toString());

    items.clear();

    /// ===============================
    /// EDIT MODE
    /// ===============================
    if (isEdit && data['items'] != null) {
      final savedItems = (data['items'] as List).map((e) {
        final item = Map<String, dynamic>.from(e);
        item['qty'] = _toInt(item['qty']);
        item['price'] = _toInt(item['price']);
        item['nameCtrl'] = TextEditingController(text: item['name']?.toString() ?? '');
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

  int get subtotal => items.fold(
        0,
        (s, i) =>
            s +
            ((int.tryParse(i['qty'].toString()) ?? 0) *
                (int.tryParse(i['price'].toString()) ?? 0)),
      );

  /// Discount
int get discount =>
    int.tryParse(discountCtrl.text) ?? 0;

/// Amount after discount
int get discountedSubtotal {
  final amount = subtotal - discount;

  /// Prevent negative values
  return amount < 0 ? 0 : amount;
}

double get gstPercent {
  final value = double.tryParse(gstPercentCtrl.text.trim());
  if (value == null || value < 0) return 18;
  return value;
}

/// GST after discount (percentage)
int get gst =>
    (discountedSubtotal * gstPercent / 100).round();

/// Final balance
int get balance =>
    discountedSubtotal + gst - advanceAmount;

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
              decoration:
                  const InputDecoration(labelText: 'Discount'),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 8),

            _amountRow('Subtotal', subtotal),
            _gstPercentRow(),
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
      .map((i) => {
            'name': i['name'],
            'qty': int.tryParse(i['qty'].toString()) ?? 0,
            'price': int.tryParse(i['price'].toString()) ?? 0,
          })
      .toList();

  final billData = {
    ...data,
    'items': previewItems,
    'subtotal': subtotal,
    'gst': gst,
    'gstPercent': gstPercent,
    'advance': advanceAmount,
    'discount': discount,
    'balance': balance,

    /// 🔥 VERY IMPORTANT
    'billId': data['billId'] ??
        DateTime.now().millisecondsSinceEpoch.toString(),
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
    gstPercentCtrl.dispose();
    super.dispose();
  }

  Widget _gstPercentRow() {
    final percentLabel = gstPercent % 1 == 0
        ? gstPercent.toInt().toString()
        : gstPercent.toString();

    return Row(
      children: [
        Expanded(
          child: _editingGstPercent
              ? TextField(
                  controller: gstPercentCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'GST %',
                    suffixText: '%',
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) =>
                      setState(() => _editingGstPercent = false),
                )
              : Text('GST ($percentLabel%)'),
        ),
        IconButton(
          tooltip: 'Change GST %',
          icon: Icon(
            _editingGstPercent ? Icons.check : Icons.edit,
            color: Colors.blue,
          ),
          onPressed: () {
            setState(() => _editingGstPercent = !_editingGstPercent);
          },
        ),
        Text(
          '₹$gst',
          style: const TextStyle(fontWeight: FontWeight.normal),
        ),
      ],
    );
  }

  Widget _itemEditor(int index) {
    final item = items[index];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TextField(
              controller: item['nameCtrl'],
              decoration:
                  const InputDecoration(labelText: 'Item Name'),
              onChanged: (v) => item['name'] = v,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item['qtyCtrl'],
                    decoration:
                        const InputDecoration(labelText: 'Qty'),
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
                    decoration:
                        const InputDecoration(labelText: 'Price'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      item['price'] = int.tryParse(v) ?? 0;
                      setState(() {});
                    },
                  ),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeItem(index),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, int value,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight:
                    bold ? FontWeight.bold : null)),
        Text(
          '₹$value',
          style: TextStyle(
              fontWeight:
                  bold ? FontWeight.bold : null),
        ),
      ],
    );
  }
}
