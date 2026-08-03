import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/confirm_store.dart';
import 'package:provider/provider.dart';
import '../history/quotation_history_store.dart';

class QuotationHistoryTab extends StatefulWidget {
  const QuotationHistoryTab({super.key});

  @override
  State<QuotationHistoryTab> createState() =>
      _QuotationHistoryTabState();
}

class _QuotationHistoryTabState
    extends State<QuotationHistoryTab> {
  DateTime? from;
  DateTime? to;

  @override
  Widget build(BuildContext context) {
    final store =
        context.watch<QuotationHistoryStore>();
    final confirmStore =
        context.watch<ConfirmStore>();

    if (store.isLoading) {
      return const Center(
          child: CircularProgressIndicator());
    }

    final hasDateFilter = from != null || to != null;

    final filtered = store.quotations.where((q) {
      final DateTime? checkIn = _asDate(q['checkInDate']);
      if (checkIn == null) return false;

      if (from != null &&
          checkIn.isBefore(_startOfDay(from!))) {
        return false;
      }
      if (to != null &&
          checkIn.isAfter(_endOfDay(to!))) {
        return false;
      }

      // Date search bypasses the 30-day UI hide rule.
      if (hasDateFilter) return true;

      final quotationId = q['id']?.toString() ?? '';
      final isConfirmed = confirmStore.isConfirmed(quotationId);
      return _isWithinUiRetention(q, isConfirmed: isConfirmed);
    }).toList();

    return Column(
      children: [
        /// FILTER BAR
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _dateBox('From', from,
                  (d) => setState(() => from = d)),
              const SizedBox(width: 8),
              _dateBox(
                  'To', to, (d) => setState(() => to = d)),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () =>
                    setState(() {}),
              ),
              if (from != null || to != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    from = null;
                    to = null;
                  }),
                ),
            ],
          ),
        ),

        /// TABLE
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                      'No quotations found'))
              : SingleChildScrollView(
                  scrollDirection:
                      Axis.vertical,
                  child:
                      SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(
                            label: SizedBox()),
                        DataColumn(
                            label: Text('SI')),    
                        DataColumn(
                            label: Text('Guest')),
                        DataColumn(
                            label: Text('Phone')),
                        DataColumn(
                            label: Text('Package')),
                        DataColumn(
                            label:
                                Text('Check In')),
                        DataColumn(
                            label:
                                Text('Check Out')),
                        DataColumn(
                            label:
                                Text('Actions')),
                      ],
                      rows: List.generate(filtered.length, (i) {
  final q = filtered[i];
  final String quotationId = q['id'];

  final bool isConfirmed =
      confirmStore.isConfirmed(quotationId);

  final DateTime? checkIn = _asDate(q['checkInDate']);
  final DateTime? checkOut = _asDate(q['checkOutDate']);

  return DataRow(
    color: WidgetStateProperty.resolveWith<Color?>(
      (states) {
        if (isConfirmed) {
          return Colors.yellow.shade700;
        }
        return null;
      },
    ),
    cells: [
      /// CHECKBOX
      DataCell(
        Checkbox(
          value: isConfirmed,
          activeColor: Colors.green,
          onChanged: (value) async {
            if (value == true) {
              final paymentDetails =
                  await _selectAdvancePaymentDetails(
                context,
                quotation: q,
              );
              if (paymentDetails == null || !context.mounted) return;

              final advance = (double.tryParse(
                        paymentDetails['advance'] ?? '0',
                      ) ??
                      0)
                  .round();
              final paidAt = _dateOnly(
                DateTime.tryParse(paymentDetails['paidAt'] ?? '') ??
                    DateTime.now(),
              );
              final mode = paymentDetails['mode']!;
              final recordedBy = paymentDetails['recordedBy']!;

              try {
                await context
                    .read<QuotationHistoryStore>()
                    .updateQuotation(quotationId, {
                  'advance': advance,
                  'advancePaymentMode': mode,
                  'advanceRecordedBy': recordedBy,
                  'advancePaymentDate': paidAt,
                });

                if (!context.mounted) return;
                await confirmStore.confirmQuotation(
                  {
                    ...q,
                    'advance': advance,
                  },
                  advancePaymentMode: mode,
                  advanceRecordedBy: recordedBy,
                  advancePaymentDate: paidAt,
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not confirm: $e')),
                );
              }
            } else {
              await confirmStore
                  .removeByOriginalId(quotationId);
            }
          },
        ),
      ),

      DataCell(Text('${i + 1}')),
      DataCell(Text(q['customerName'] ?? '')),
      DataCell(Text(q['phone1'] ?? '')),
      DataCell(Text(q['package'] ?? '')),
      DataCell(Text(checkIn != null
          ? DateFormat('dd/MM/yyyy').format(checkIn)
          : '')),
      DataCell(Text(checkOut != null
          ? DateFormat('dd/MM/yyyy').format(checkOut)
          : '')),

      /// ACTIONS
      DataCell(
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.visibility,
                  color: Colors.green),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/quotation_preview_screen',
                  arguments: q,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit,
                  color: Colors.blue),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/create_quotation',
                  arguments: {
                    ...q,
                    'quotationId': quotationId,
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  color: Colors.red),
              onPressed: () {
                _confirmDelete(context, quotationId);
              },
            ),
          ],
        ),
      ),
    ],
  );
}),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _dateBox(String label,
      DateTime? value,
      Function(DateTime) onPick) {
    return OutlinedButton(
      child: Text(value == null
          ? label
          : DateFormat('dd/MM/yyyy')
              .format(value)),
      onPressed: () async {
        final d =
            await showDatePicker(
          context: context,
          firstDate:
              DateTime(2020),
          lastDate:
              DateTime(2100),
          initialDate:
              value ??
                  DateTime.now(),
        );
        if (d != null) onPick(d);
      },
    );
  }

  Future<Map<String, String>?> _selectAdvancePaymentDetails(
    BuildContext context, {
    required Map<String, dynamic> quotation,
  }) async {
    final existingAdvance = quotation['advance'];
    final advanceText = existingAdvance == null
        ? ''
        : (existingAdvance is num
            ? existingAdvance.round().toString()
            : existingAdvance.toString());

    final advanceController = TextEditingController(text: advanceText);
    final recordedByController = TextEditingController(
      text: (quotation['advanceRecordedBy'] ?? '').toString(),
    );

    final existingMode = quotation['advancePaymentMode']?.toString();
    const modes = ['GPay', 'Account', 'Cash'];
    String? selectedMode =
        modes.contains(existingMode) ? existingMode : null;

    DateTime paidAt = DateTime.now();
    final existingDate = quotation['advancePaymentDate'];
    if (existingDate is DateTime) {
      paidAt = existingDate;
    }

    String? error;
    try {
      final result = await showDialog<Map<String, String>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Record advance payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: advanceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Advance amount *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: selectedMode,
                    decoration: const InputDecoration(
                      labelText: 'Payment mode *',
                      border: OutlineInputBorder(),
                    ),
                    items: modes
                        .map(
                          (mode) => DropdownMenuItem(
                            value: mode,
                            child: Text(mode),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => selectedMode = value),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: recordedByController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Recorded by *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(paidAt),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change date',
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: paidAt,
                            );
                            if (selected != null) {
                              setDialogState(() => paidAt = selected);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final recordedBy = recordedByController.text.trim();
                  final parsedAdvance =
                      double.tryParse(advanceController.text.trim()) ?? 0;
                  if (parsedAdvance < 1) {
                    setDialogState(() {
                      error = 'Advance amount must be at least ₹1.';
                    });
                    return;
                  }
                  if (selectedMode == null || recordedBy.isEmpty) {
                    setDialogState(() {
                      error =
                          'Payment mode and recorded by are required.';
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'advance': parsedAdvance.round().toString(),
                    'mode': selectedMode!,
                    'recordedBy': recordedBy,
                    'paidAt': paidAt.toIso8601String(),
                  });
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ),
      );
      return result;
    } finally {
      // Dispose after the dialog route is fully gone to avoid
      // "used after disposed" crashes on Cancel/Confirm.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        advanceController.dispose();
        recordedByController.dispose();
      });
    }
  }

  Future<void> _confirmDelete(
      BuildContext context,
      String quotationId) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
        title: const Text(
            'Delete Quotation'),
        content: const Text(
            'Are you sure you want to delete this quotation?'),
        actions: [
          TextButton(
            child:
                const Text('No'),
            onPressed: () =>
                Navigator.pop(
                    context,
                    false),
          ),
          ElevatedButton(
            child:
                const Text('Yes'),
            onPressed: () =>
                Navigator.pop(
                    context,
                    true),
          ),
        ],
      ),
    );

   if (confirmed == true && context.mounted) {

  await context
      .read<QuotationHistoryStore>()
      .deleteQuotation(quotationId);

  await context
      .read<ConfirmStore>()
      .removeByOriginalId(quotationId);
}
  }

  /// Hide from UI after 30 days (DB unchanged).
  /// Confirmed: no 30-day rule until after checkout, then 30 days from checkout.
  /// Unconfirmed: 30 days from createdAt (fallback check-in).
  bool _isWithinUiRetention(
    Map<String, dynamic> q, {
    required bool isConfirmed,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final checkOut = _asDate(q['checkOutDate']);
    final advance = _toNum(q['advance']);
    final wasConfirmed = isConfirmed ||
        q['advancePaymentMode'] != null ||
        advance >= 1;

    if (isConfirmed) {
      return true;
    }

    if (wasConfirmed && checkOut != null) {
      final checkoutDay =
          DateTime(checkOut.year, checkOut.month, checkOut.day);
      if (!today.isAfter(checkoutDay)) return true;
      final hideAfter = checkoutDay.add(const Duration(days: 30));
      return !today.isAfter(hideAfter);
    }

    final created =
        _asDate(q['createdAt']) ?? _asDate(q['checkInDate']);
    if (created == null) return true;

    final createdDay =
        DateTime(created.year, created.month, created.day);
    final hideAfter = createdDay.add(const Duration(days: 30));
    return !today.isAfter(hideAfter);
  }

  DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      // Firestore Timestamp / anything with toDate()
      final dynamic date = value.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _startOfDay(
          DateTime d) =>
      DateTime(
          d.year,
          d.month,
          d.day);

  DateTime _endOfDay(
          DateTime d) =>
      DateTime(
          d.year,
          d.month,
          d.day,
          23,
          59,
          59);

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
