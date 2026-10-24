import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant_report_item_model.dart';
import '../providers/restaurant_stock_provider.dart';
import '../utils/restaurant_stock_utils.dart';
import '../widgets/item_search_field.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key, this.initialItem});

  final RestaurantItemModel? initialItem;

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  RestaurantItemModel? _selectedItem;
  final _quantityCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedItem = widget.initialItem;
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) return;
    setState(() => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ));
  }

  Future<void> _createNewItem(String name) async {
    try {
      final created = await context.read<RestaurantStockProvider>().createItem(
            name: name,
            category: '',
            unit: 'Unit',
            minimumStock: 0,
          );
      if (mounted) setState(() => _selectedItem = created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create item: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final item = _selectedItem;
    if (item == null || item.id.isEmpty) return;
    final quantity = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    setState(() => _saving = true);
    try {
      await context.read<RestaurantStockProvider>().addStock(
            item: item,
            quantity: quantity,
            date: _date,
            note: _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock added successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add stock: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Stock')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ItemSearchField(
                key: ValueKey(_selectedItem?.id ?? 'item-search'),
                selectedItem: _selectedItem,
                onItemSelected: (item) =>
                  setState(() => _selectedItem = item as RestaurantItemModel?),
                onCreateNew: _createNewItem,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Enter a quantity greater than 0'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: Text(formatReportDateTime(_date)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                  hintText: 'New stock received',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.add),
                label: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add Stock'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool?> openAddStockScreen(
  BuildContext context, {
  RestaurantItemModel? initialItem,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => AddStockScreen(initialItem: initialItem),
    ),
  );
}
