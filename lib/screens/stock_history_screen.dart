import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_activity_model.dart';
import '../models/stock_entry_model.dart';
import '../models/stock_report_row.dart';
import '../providers/restaurant_stock_provider.dart';
import '../utils/restaurant_stock_utils.dart';
import 'add_stock_screen.dart';

class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({
    super.key,
    required this.row,
  });

  final StockReportRow row;

  static const Color _forest = Color(0xFF1B5E3B);
  static const Color _subtitle = Color(0xFF6B7C72);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantStockProvider>();
    final entries = provider.stockHistoryForItem(row.item.id);
    final currentRow = provider.reportRowForItem(row.item.id) ?? row;
    final timeline = <Object>[];
    DateTime? currentDay;
    for (final entry in entries) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (currentDay != day) {
        timeline.add(day);
        currentDay = day;
      }
      timeline.add(entry);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: Text(currentRow.item.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAddStockScreen(
          context,
          initialItem: currentRow.item,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: entries.isEmpty
          ? const Center(
              child: Text('No stock or sales in the selected dates.'),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: timeline.length,
              itemBuilder: (_, index) {
                final item = timeline[index];
                if (item is DateTime) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8),
                    child: Text(
                      formatReportDay(item),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _forest,
                      ),
                    ),
                  );
                }
                final entry = item as StockActivity;
                final isSale = entry.type == StockActivityType.sold;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    color: Colors.white,
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      title: Text(
                        '${isSale ? '−' : '+'}${entry.quantity} ${entry.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSale ? Colors.red.shade700 : null,
                        ),
                      ),
                      subtitle: Text(
                        entry.note.isNotEmpty
                            ? entry.note
                            : (isSale ? 'Sold' : 'Stock added'),
                      ),
                      trailing: entry.stockEntry == null
                          ? Text(
                              formatReportDateTime(entry.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: _subtitle,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  formatReportDateTime(entry.date),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _subtitle,
                                  ),
                                ),
                                PopupMenuButton<_HistoryAction>(
                                  onSelected: (action) {
                                    if (action == _HistoryAction.update) {
                                      _updateEntry(context, entry.stockEntry!);
                                    } else {
                                      _deleteEntry(context, entry.stockEntry!);
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: _HistoryAction.update,
                                      child: Text('Update'),
                                    ),
                                    PopupMenuItem(
                                      value: _HistoryAction.delete,
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: Container(
        width: double.infinity,
        color: const Color(0xFFD7EEDC),
        padding: const EdgeInsets.all(16),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _totalLine('Total Added', currentRow.totalAdded, currentRow.unit),
              const SizedBox(height: 4),
              _totalLine('Sold', currentRow.totalSold, currentRow.unit),
              const SizedBox(height: 4),
              _totalLine('Balance', currentRow.balance, currentRow.unit,
                  bold: true),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateEntry(
      BuildContext context, StockEntryModel entry) async {
    final result = await showDialog<_EditedStockEntry>(
      context: context,
      builder: (_) => _EditStockEntryDialog(entry: entry),
    );
    if (result == null || !context.mounted) return;
    try {
      await context.read<RestaurantStockProvider>().updateStockEntry(
            entry: entry,
            quantity: result.quantity,
            date: result.date,
            note: result.note,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D4F)),
          title: const Text('Update successful'),
          content: const Text('The stock entry was updated successfully.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update stock entry: $error')),
      );
    }
  }

  Future<void> _deleteEntry(
      BuildContext context, StockEntryModel entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete stock entry?'),
        content: Text(
          'Delete the ${entry.quantity} ${entry.unit} entry for ${entry.itemName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context
          .read<RestaurantStockProvider>()
          .deleteStockEntry(entry.id);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete stock entry: $error')),
      );
    }
  }

  Widget _totalLine(String label, int value, String unit, {bool bold = false}) {
    return Text(
      '$label: $value $unit',
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: bold ? _forest : Colors.black87,
        fontSize: bold ? 15 : 13,
      ),
    );
  }
}

enum _HistoryAction { update, delete }

class _EditedStockEntry {
  const _EditedStockEntry(this.quantity, this.date, this.note);
  final int quantity;
  final DateTime date;
  final String note;
}

class _EditStockEntryDialog extends StatefulWidget {
  const _EditStockEntryDialog({required this.entry});
  final StockEntryModel entry;

  @override
  State<_EditStockEntryDialog> createState() => _EditStockEntryDialogState();
}

class _EditStockEntryDialogState extends State<_EditStockEntryDialog> {
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: '${widget.entry.quantity}');
    _noteCtrl = TextEditingController(text: widget.entry.note);
    _date = widget.entry.date;
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _EditedStockEntry(
        int.parse(_quantityCtrl.text.trim()),
        _date,
        _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update ${widget.entry.itemName} stock'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Enter a quantity greater than 0'
                      : null;
                },
              ),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: Text(formatReportDateTime(_date)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Update')),
      ],
    );
  }
}
