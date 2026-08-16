import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/utils/advance_payment_utils.dart';

/// Multi-entry advance payment dialog (confirm + edit booking).
class AdvancePaymentsDialog extends StatefulWidget {
  final String title;
  final String confirmLabel;
  final List<Map<String, dynamic>> initialPayments;

  const AdvancePaymentsDialog({
    super.key,
    required this.title,
    this.confirmLabel = 'Confirm',
    required this.initialPayments,
  });

  static Future<List<Map<String, dynamic>>?> show(
    BuildContext context, {
    required String title,
    String confirmLabel = 'Confirm',
    required Map<String, dynamic> quotation,
    Map<String, dynamic>? confirmedRecord,
  }) {
    final source = confirmedRecord ?? quotation;
    final initial = AdvancePaymentUtils.paymentsFromRecord(source);

    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AdvancePaymentsDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialPayments: initial,
      ),
    );
  }

  @override
  State<AdvancePaymentsDialog> createState() => _AdvancePaymentsDialogState();
}

class _AdvancePaymentFormEntry {
  _AdvancePaymentFormEntry({
    required this.amountController,
    required this.recordedByController,
    required this.mode,
    required this.paidAt,
  });

  final TextEditingController amountController;
  final TextEditingController recordedByController;
  String mode;
  DateTime paidAt;

  void dispose() {
    amountController.dispose();
    recordedByController.dispose();
  }
}

class _AdvancePaymentsDialogState extends State<AdvancePaymentsDialog> {
  final List<_AdvancePaymentFormEntry> _entries = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries(widget.initialPayments);
  }

  void _loadEntries(List<Map<String, dynamic>> payments) {
    for (final entry in _entries) {
      entry.dispose();
    }
    _entries.clear();

    final source = payments.isEmpty
        ? [
            {
              'amount': 0,
              'mode': AdvancePaymentUtils.paymentModes.first,
              'recordedBy': '',
              'paidAt': DateTime.now(),
            },
          ]
        : payments;

    for (final payment in source) {
      final amount = AdvancePaymentUtils.toAmount(payment['amount']);
      _entries.add(
        _AdvancePaymentFormEntry(
          amountController: TextEditingController(
            text: amount >= 1 ? amount.round().toString() : '',
          ),
          recordedByController: TextEditingController(
            text: (payment['recordedBy'] ?? '').toString(),
          ),
          mode: AdvancePaymentUtils.paymentModes
                  .contains(payment['mode']?.toString())
              ? payment['mode'].toString()
              : AdvancePaymentUtils.paymentModes.first,
          paidAt: AdvancePaymentUtils.parseDate(payment['paidAt']) ??
              DateTime.now(),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final entry in _entries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() {
      _entries.add(
        _AdvancePaymentFormEntry(
          amountController: TextEditingController(),
          recordedByController: TextEditingController(),
          mode: AdvancePaymentUtils.paymentModes.first,
          paidAt: DateTime.now(),
        ),
      );
    });
  }

  void _removeEntry(int index) {
    if (_entries.length <= 1) return;
    setState(() {
      _entries.removeAt(index).dispose();
    });
  }

  void _submit() {
    final results = <Map<String, dynamic>>[];

    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      final amount =
          double.tryParse(entry.amountController.text.trim()) ?? 0;
      final recordedBy = entry.recordedByController.text.trim();

      if (amount < 1) {
        setState(() {
          _error = 'Advance #${i + 1}: amount must be at least ₹1.';
        });
        return;
      }
      if (recordedBy.isEmpty) {
        setState(() {
          _error = 'Advance #${i + 1}: recorded by is required.';
        });
        return;
      }

      results.add({
        'amount': amount,
        'mode': entry.mode,
        'recordedBy': recordedBy,
        'paidAt': AdvancePaymentUtils.dateOnly(entry.paidAt),
      });
    }

    Navigator.pop(context, results);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _entries.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                _buildEntry(i, _entries[i]),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addEntry,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Advance'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  Widget _buildEntry(int index, _AdvancePaymentFormEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Advance #${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (_entries.length > 1)
              IconButton(
                tooltip: 'Remove advance',
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => _removeEntry(index),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: entry.amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Advance amount *',
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: entry.mode,
          decoration: const InputDecoration(
            labelText: 'Payment mode *',
            border: OutlineInputBorder(),
          ),
          items: AdvancePaymentUtils.paymentModes
              .map(
                (mode) => DropdownMenuItem(value: mode, child: Text(mode)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            setState(() => entry.mode = value);
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: entry.recordedByController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Recorded by *',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Payment date',
            border: OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(DateFormat('dd/MM/yyyy').format(entry.paidAt)),
              ),
              IconButton(
                tooltip: 'Change date',
                icon: const Icon(Icons.calendar_today_outlined),
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: entry.paidAt,
                  );
                  if (selected != null) {
                    setState(() => entry.paidAt = selected);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// View-only popup for Bookings screen advance list.
class AdvancePaymentsViewDialog extends StatelessWidget {
  final List<Map<String, dynamic>> payments;

  const AdvancePaymentsViewDialog({super.key, required this.payments});

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> record,
  }) {
    final list = AdvancePaymentUtils.paymentsFromRecord(record);
    return showDialog(
      context: context,
      builder: (_) => AdvancePaymentsViewDialog(payments: list),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Advance Payments'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < payments.length; i++) ...[
                if (i > 0) const Divider(height: 24),
                Text(
                  'Advance #${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Amount: ₹${AdvancePaymentUtils.toAmount(payments[i]['amount']).round()}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text('Payment Mode: ${payments[i]['mode']}'),
                const SizedBox(height: 4),
                Text('Recorded By: ${payments[i]['recordedBy']}'),
                const SizedBox(height: 4),
                Text(
                  'Recorded Date: ${DateFormat('dd/MM/yyyy').format(AdvancePaymentUtils.parseDate(payments[i]['paidAt']) ?? DateTime.now())}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
