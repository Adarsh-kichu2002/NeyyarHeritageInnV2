import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/restaurant_stock_utils.dart';

class StockFilterValues {
  const StockFilterValues({
    this.itemQuery = '',
    this.from,
    this.to,
  });

  final String itemQuery;
  final DateTime? from;
  final DateTime? to;
}

Future<StockFilterValues?> showStockFilterDialog(
  BuildContext context, {
  required StockFilterValues initial,
  List<String> itemNames = const [],
}) {
  return showDialog<StockFilterValues>(
    context: context,
    builder: (dialogContext) =>
        _StockFilterDialog(initial: initial, itemNames: itemNames),
  );
}

class _StockFilterDialog extends StatefulWidget {
  const _StockFilterDialog({required this.initial, required this.itemNames});

  final StockFilterValues initial;
  final List<String> itemNames;

  @override
  State<_StockFilterDialog> createState() => _StockFilterDialogState();
}

class _StockFilterDialogState extends State<_StockFilterDialog> {
  late final TextEditingController _itemController;
  late final FocusNode _itemFocusNode;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _itemController = TextEditingController(text: widget.initial.itemQuery);
    _itemFocusNode = FocusNode();
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  void dispose() {
    _itemController.dispose();
    _itemFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      final value = DateTime(selected.year, selected.month, selected.day);
      if (isFrom) {
        _from = value;
      } else {
        _to = value;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Filter'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RawAutocomplete<String>(
              textEditingController: _itemController,
              focusNode: _itemFocusNode,
              optionsBuilder: (value) {
                final query = normalizeItemName(value.text);
                if (query.isEmpty) return const <String>[];
                return widget.itemNames
                    .where((name) => matchesItemSearch(name, query))
                    .take(8);
              },
              optionsViewBuilder: (context, onSelected, options) {
                final matches = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        maxWidth: 300,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: matches.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (_, index) => ListTile(
                          dense: true,
                          title: Text(matches[index]),
                          onTap: () => onSelected(matches[index]),
                        ),
                      ),
                    ),
                  ),
                );
              },
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Search / Item',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(true),
                    child: Text(
                      _from == null
                          ? 'From Date'
                          : DateFormat('dd/MM/yyyy').format(_from!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(false),
                    child: Text(
                      _to == null
                          ? 'To Date'
                          : DateFormat('dd/MM/yyyy').format(_to!),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context, const StockFilterValues());
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              StockFilterValues(
                itemQuery: _itemController.text.trim(),
                from: _from,
                to: _to,
              ),
            );
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
}
