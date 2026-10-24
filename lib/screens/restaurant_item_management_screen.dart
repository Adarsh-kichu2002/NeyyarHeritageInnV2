import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant_item_model.dart';
import '../services/restaurant_item_service.dart';

/// Admin-only master list for restaurant menu items.
class RestaurantItemManagementScreen extends StatefulWidget {
  const RestaurantItemManagementScreen({super.key});

  @override
  State<RestaurantItemManagementScreen> createState() =>
      _RestaurantItemManagementScreenState();
}

class _RestaurantItemManagementScreenState
    extends State<RestaurantItemManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showItemEditor({RestaurantItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
      text: existing == null
          ? ''
          : (existing.price % 1 == 0
              ? existing.price.toInt().toString()
              : existing.price.toString()),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing == null ? 'Add Item' : 'Edit Item'),
          content: Column(
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
                if (name.isEmpty || price <= 0) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) {
      nameCtrl.dispose();
      priceCtrl.dispose();
      return;
    }

    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    nameCtrl.dispose();
    priceCtrl.dispose();

    final store = context.read<RestaurantItemStore>();
    try {
      if (existing == null) {
        await store.addItem(name: name, price: price);
      } else {
        await store.updateItem(id: existing.id, name: name, price: price);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Item added' : 'Item updated'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save item: $e')),
      );
    }
  }

  Future<void> _deleteItem(RestaurantItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from the master list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<RestaurantItemStore>().deleteItem(item.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }

  String _money(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RestaurantItemStore>();
    final query = _searchQuery.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final visibleItems = store.items.where((item) {
      final name = item.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      return query.isEmpty || name.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Restaurant Items'),
        actions: const [
          // IconButton(
          //   tooltip: 'Add Item',
          //   icon: const Icon(Icons.add),
          //   onPressed: () => _showItemEditor(),
          // ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemEditor(),
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Item',
        ),
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search restaurant items...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF4F7F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: store.items.isEmpty
                      ? const Center(
                          child: Text(
                            'No restaurant items yet.\n+ Add Item',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : visibleItems.isEmpty
                          ? const Center(child: Text('No matching items found.'))
                          : ListView.separated(
                              itemCount: visibleItems.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final item = visibleItems[i];
                                return ListTile(
                                  title: Text(item.name),
                                  subtitle: Text('₹${_money(item.price)}'),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit',
                                        icon: const Icon(Icons.edit,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _showItemEditor(existing: item),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete',
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteItem(item),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
