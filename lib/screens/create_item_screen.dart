import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant_report_item_model.dart';
import '../providers/restaurant_stock_provider.dart';

class CreateItemScreen extends StatefulWidget {
  const CreateItemScreen({
    super.key,
    this.initialName = '',
  });

  final String initialName;

  @override
  State<CreateItemScreen> createState() => _CreateItemScreenState();
}

class _CreateItemScreenState extends State<CreateItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _minStockCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _categoryCtrl = TextEditingController();
    _unitCtrl = TextEditingController(text: 'Bottle');
    _minStockCtrl = TextEditingController(text: '10');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _unitCtrl.dispose();
    _minStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final item = await context.read<RestaurantStockProvider>().createItem(
            name: _nameCtrl.text.trim(),
            category: _categoryCtrl.text.trim(),
            unit: _unitCtrl.text.trim(),
            minimumStock: int.parse(_minStockCtrl.text.trim()),
          );
      if (!mounted) return;
      Navigator.pop(context, item);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create item: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Item'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Category is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unitCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Unit',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Unit is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minStockCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Stock',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) {
                    return 'Enter a valid minimum stock';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saving ? null : _create,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens create item and returns the created [RestaurantItemModel].
Future<RestaurantItemModel?> openCreateItemScreen(
  BuildContext context, {
  String initialName = '',
}) {
  return Navigator.push<RestaurantItemModel>(
    context,
    MaterialPageRoute(
      builder: (_) => CreateItemScreen(initialName: initialName),
    ),
  );
}
