import 'package:flutter/material.dart';

class RoomSelectScreen extends StatefulWidget {
  const RoomSelectScreen({super.key});

  @override
  State<RoomSelectScreen> createState() => _RoomSelectScreenState();
}

class _RoomSelectScreenState extends State<RoomSelectScreen> {
  late Map<String, dynamic> quotationData;

  /// ROOMS
  late List<Map<String, dynamic>> rooms;

  Map<String, dynamic> _createRoom(String name, int price) {
  return {
    'name': name,
    'price': price,
    'qty': 1,
    'selected': false,
    'qtyController': TextEditingController(text: '1'),
    'priceController': TextEditingController(text: price.toString()),
  };
}

  /// EXTRA PERSONS
  final TextEditingController extraPersonCtrl =
      TextEditingController(text: '0');
  final TextEditingController extraPersonPriceCtrl =
      TextEditingController(text: '1000');

  /// CUSTOM ITEM
  final TextEditingController customItemNameCtrl = TextEditingController();
  final TextEditingController customItemPriceCtrl =
      TextEditingController(text: '0');

  /// DISCOUNT
  final TextEditingController discountCtrl =
      TextEditingController(text: '0');

  /// GST % (default 18, editable)
  final TextEditingController gstPercentCtrl =
      TextEditingController(text: '18');
  bool _editingGstPercent = false;

  /// FACILITIES
  late List<String> facilities;
  final TextEditingController facilityCtrl = TextEditingController();

  bool _initialized = false;

  @override
void didChangeDependencies() {
  super.didChangeDependencies();
  if (_initialized) return;

  quotationData =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

  final isEdit = quotationData['mode'] == 'edit';

  /// ROOMS
  rooms = isEdit && quotationData['rooms'] != null
    ? List<Map<String, dynamic>>.from(
        quotationData['rooms'].map((r) {
          final room = Map<String, dynamic>.from(r);
          room['qtyController'] =
              TextEditingController(text: room['qty'].toString());
          room['priceController'] =
              TextEditingController(text: room['price'].toString());
          return room;
        }),
      )
    : [
        _createRoom('AC Suite Room', 3500),
        _createRoom('Hut', 2500),
        _createRoom('Non-AC Room', 2000),
      ];

  /// EXTRA & DISCOUNT
  extraPersonCtrl.text =
      isEdit ? quotationData['extraPersons']?.toString() ?? '0' : '0';
  extraPersonPriceCtrl.text =
      isEdit ? quotationData['extraPersonPrice']?.toString() ?? '1000' : '1000';
  discountCtrl.text =
      isEdit ? quotationData['discount']?.toString() ?? '0' : '0';

  final savedGst = quotationData['gstPercent'];
  gstPercentCtrl.text = savedGst == null
      ? '18'
      : (savedGst is num
          ? (savedGst % 1 == 0
              ? savedGst.toInt().toString()
              : savedGst.toString())
          : savedGst.toString());

  /// FACILITIES
  facilities = isEdit && quotationData['facilities'] != null
      ? List<String>.from(quotationData['facilities'])
      : [
          'Welcome Drinks',
          'Pool (2 Hrs)',
          'Waterfall & Rain Dance (30 minutes)',
          'Children Play Area',
          'Breakfast (Next Day)',
        ];

  _initialized = true;
}


  int get roomTotal => rooms
      .where((r) => r['selected'] == true)
      .fold<int>(0, (s, r) {
        final price = r['price'];
        final qty = r['qty'];
        final priceInt = price is num
            ? price.round()
            : int.tryParse(price?.toString() ?? '') ?? 0;
        final qtyInt = qty is num
            ? qty.round()
            : int.tryParse(qty?.toString() ?? '') ?? 0;
        return s + (priceInt * qtyInt);
      });

  int get extraTotal =>
      (int.tryParse(extraPersonCtrl.text) ?? 0) *
      (int.tryParse(extraPersonPriceCtrl.text) ?? 0);

  int get discount => int.tryParse(discountCtrl.text) ?? 0;

  double get gstPercent {
    final value = double.tryParse(gstPercentCtrl.text.trim());
    if (value == null || value < 0) return 18;
    return value;
  }

  int get grandTotal =>
      (roomTotal + extraTotal - discount).clamp(0, 999999);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Rooms')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Rooms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          ...rooms.map(_roomTile),

          const SizedBox(height: 12),

          /// CUSTOM ITEM
          Row(children: [
            Expanded(
              child: TextField(
                controller: customItemNameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: customItemPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              if (customItemNameCtrl.text.isEmpty) return;
              setState(() {
                rooms.add({
                  'name': customItemNameCtrl.text.trim(),
                  'price': int.tryParse(customItemPriceCtrl.text) ?? 0,
                  'qty': 1,
                  'selected': true,
                });
                customItemNameCtrl.clear();
                customItemPriceCtrl.text = '0';
              });
            },
            child: const Text('Add Custom Item'),
          ),

          const Divider(height: 32),

          /// EXTRA PERSONS
          const Text('Extra Persons'),
          Row(children: [
            _smallBox(extraPersonCtrl, 'Persons'),
            const SizedBox(width: 8),
            _smallBox(extraPersonPriceCtrl, 'Price'),
            const SizedBox(width: 8),
            Text('₹$extraTotal'),
          ]),

          const Divider(height: 32),

          /// FACILITIES
          const Text('Facilities',
              style: TextStyle(fontWeight: FontWeight.bold)),
          ...facilities.map((f) => Row(children: [
                const Text('• '),
                Expanded(child: Text(f)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => facilities.remove(f)),
                )
              ])),
          Row(children: [
            Expanded(
              child: TextField(
                controller: facilityCtrl,
                decoration: const InputDecoration(hintText: 'Add facility'),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                if (facilityCtrl.text.isEmpty) return;
                setState(() {
                  facilities.add(facilityCtrl.text.trim());
                  facilityCtrl.clear();
                });
              },
            )
          ]),

          const Divider(height: 32),

          /// DISCOUNT
          TextField(
            controller: discountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Discount Amount',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 20),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Total: ₹$grandTotal',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 16),

          /// GST SECTION (before preview)
          _gstSection(),

          const SizedBox(height: 24),

          /// PREVIEW
          ElevatedButton(
  onPressed: () {
    /// 🔥 REMOVE CONTROLLERS BEFORE SENDING
    final cleanedRooms = rooms.map((r) {
      return {
        'name': r['name'],
        'price': r['price'],
        'qty': r['qty'],
        'selected': r['selected'],
      };
    }).toList();

    Navigator.pushNamed(
      context,
      '/quotation_preview_screen',
      arguments: {
        ...quotationData,
        'rooms': cleanedRooms,
        'extraPersons': int.tryParse(extraPersonCtrl.text) ?? 0,
        'extraPersonPrice': int.tryParse(extraPersonPriceCtrl.text) ?? 0,
        'extraTotal': extraTotal,
        'discount': discount,
        'gstPercent': gstPercent,
        'facilities': facilities,
        'total': grandTotal,
      },
    );
  },
  child: const Text('Preview Quotation'),
),
        ]),
      ),
    );
  }

  @override
void dispose() {
  for (var room in rooms) {
    room['qtyController']?.dispose();
    room['priceController']?.dispose();
  }
  extraPersonCtrl.dispose();
  extraPersonPriceCtrl.dispose();
  customItemNameCtrl.dispose();
  customItemPriceCtrl.dispose();
  discountCtrl.dispose();
  gstPercentCtrl.dispose();
  facilityCtrl.dispose();
  super.dispose();
}

  Widget _gstSection() {
    final percentLabel = gstPercent % 1 == 0
        ? gstPercent.toInt().toString()
        : gstPercent.toString();

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _editingGstPercent
                  ? TextField(
                      controller: gstPercentCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'GST %',
                        suffixText: '%',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) =>
                          setState(() => _editingGstPercent = false),
                    )
                  : Text(
                      'GST ($percentLabel%)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
          ],
        ),
      ),
    );
  }

 Widget _roomTile(Map<String, dynamic> room) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(children: [
        Checkbox(
          value: room['selected'],
          onChanged: (v) => setState(() => room['selected'] = v),
        ),

        Expanded(flex: 3, child: Text(room['name'])),

        SizedBox(
          width: 50,
          child: TextField(
            controller: room['qtyController'],
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            onChanged: (v) {
              room['qty'] = (int.tryParse(v) ?? 1).clamp(1, 999);
              setState(() {});
            },
          ),
        ),

        const SizedBox(width: 8),

        SizedBox(
          width: 80,
          child: TextField(
            controller: room['priceController'],
            keyboardType: TextInputType.number,
            onChanged: (v) {
              room['price'] = int.tryParse(v) ?? room['price'];
              setState(() {});
            },
          ),
        ),

        const SizedBox(width: 8),

        Text(
          '₹${room['price'] * room['qty']}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ]),
    ),
  );
}

  Widget _smallBox(TextEditingController c, String label) {
    return Expanded(
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
