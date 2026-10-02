import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant_item_model.dart';
import '../services/restaurant_item_service.dart';

/// Bottom sheet / dialog for selecting a master item or creating a manual one.
Future<Map<String, dynamic>?> showRestaurantItemSelector(
  BuildContext context, {
  required bool isAdmin,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _RestaurantItemSelectorSheet(isAdmin: isAdmin),
  );
}

class _RestaurantItemSelectorSheet extends StatefulWidget {
  const _RestaurantItemSelectorSheet({required this.isAdmin});

  final bool isAdmin;

  @override
  State<_RestaurantItemSelectorSheet> createState() =>
      _RestaurantItemSelectorSheetState();
}

class _RestaurantItemSelectorSheetState
    extends State<_RestaurantItemSelectorSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickMaster(RestaurantItem item) async {
    final qtyCtrl = TextEditingController(text: '1');
    final qty = await showDialog<int>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(item.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Price: ₹${item.price % 1 == 0 ? item.price.toInt() : item.price}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Price is fixed and cannot be changed.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final q = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (q <= 0) return;
                Navigator.pop(dialogCtx, q);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    qtyCtrl.dispose();
    if (qty == null || !mounted) return;

    Navigator.pop(context, {
      'itemName': item.name,
      'quantity': qty,
      'price': item.price,
      'total': qty * item.price,
      'isManual': false,
      'masterItemId': item.id,
    });
  }

  Future<void> _createManual() async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Create New Item'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Item Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Price',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                if (name.isEmpty || price <= 0 || qty <= 0) return;
                Navigator.pop(dialogCtx, {
                  'itemName': name,
                  'quantity': qty,
                  'price': price,
                  'total': qty * price,
                  'isManual': true,
                });
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    priceCtrl.dispose();
    qtyCtrl.dispose();
    if (result == null || !mounted) return;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RestaurantItemStore>();
    final filtered = store.search(_query);
    final height = MediaQuery.of(context).size.height * 0.75;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Items',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  onPressed: _createManual,
                  icon: const Icon(Icons.add),
                  label: const Text('Create New Item'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search item...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: store.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            store.items.isEmpty
                                ? (widget.isAdmin
                                    ? 'No restaurant items yet.\nUse Manage Items to add some.'
                                    : 'No restaurant items available.\nPlease ask an Admin to add items.')
                                : 'No matching items',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final item = filtered[i];
                          final priceLabel = item.price % 1 == 0
                              ? item.price.toInt().toString()
                              : item.price.toString();
                          return ListTile(
                            title: Text(item.name),
                            trailing: Text(
                              '₹$priceLabel',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onTap: () => _pickMaster(item),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
