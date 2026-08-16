import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ListFilterValues {
  const ListFilterValues({
    this.customerName = '',
    this.from,
    this.to,
  });

  final String customerName;
  final DateTime? from;
  final DateTime? to;
}

Future<ListFilterValues?> showListFilterDialog(
  BuildContext context, {
  required ListFilterValues initial,
  Widget? extra,
}) {
  return showDialog<ListFilterValues>(
    context: context,
    builder: (dialogContext) => _ListFilterDialog(
      initial: initial,
      extra: extra,
    ),
  );
}

class _ListFilterDialog extends StatefulWidget {
  const _ListFilterDialog({required this.initial, this.extra});

  final ListFilterValues initial;
  final Widget? extra;

  @override
  State<_ListFilterDialog> createState() => _ListFilterDialogState();
}

class _ListFilterDialogState extends State<_ListFilterDialog> {
  late final TextEditingController _nameController;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial.customerName);
    _from = widget.initial.from;
    _to = widget.initial.to;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      if (isFrom) {
        _from = selected;
      } else {
        _to = selected;
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
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Customer name',
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
                          ? 'From'
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
                          ? 'To'
                          : DateFormat('dd/MM/yyyy').format(_to!),
                    ),
                  ),
                ),
              ],
            ),
            if (widget.extra != null) ...[
              const SizedBox(height: 12),
              widget.extra!,
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _nameController.clear();
            setState(() {
              _from = null;
              _to = null;
            });
            Navigator.pop(
              context,
              const ListFilterValues(),
            );
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
              ListFilterValues(
                customerName: _nameController.text.trim(),
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
