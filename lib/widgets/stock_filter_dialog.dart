import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
}) {
  return showDialog<StockFilterValues>(
    context: context,
    builder: (dialogContext) => _StockFilterDialog(initial: initial),
  );
}

class _StockFilterDialog extends StatefulWidget {
  const _StockFilterDialog({required this.initial});

  final StockFilterValues initial;

  @override
  State<_StockFilterDialog> createState() => _StockFilterDialogState();
}

class _StockFilterDialogState extends State<_StockFilterDialog> {
  late final TextEditingController _itemController;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _itemController = TextEditingController(text: widget.initial.itemQuery);
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  void dispose() {
    _itemController.dispose();
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
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        (isFrom ? _from : _to) ?? DateTime.now(),
      ),
    );
    if (selectedTime == null) return;
    setState(() {
      final value = DateTime(
        selected.year,
        selected.month,
        selected.day,
        selectedTime.hour,
        selectedTime.minute,
      );
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
            TextField(
              controller: _itemController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Search / Item',
                border: OutlineInputBorder(),
              ),
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
                          : DateFormat('dd/MM/yy HH:mm').format(_from!),
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
                          : DateFormat('dd/MM/yy HH:mm').format(_to!),
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
