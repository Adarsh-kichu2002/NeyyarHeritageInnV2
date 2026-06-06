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

    final filtered = store.quotations.where((q) {
      final DateTime? checkIn =
          q['checkInDate'] as DateTime?;
      if (checkIn == null) return false;

      if (from != null &&
          checkIn.isBefore(_startOfDay(from!))) {
        return false;
      }
      if (to != null &&
          checkIn.isAfter(_endOfDay(to!))) {
        return false;
      }

      return true;
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
                                Text('Advance')),        
                        DataColumn(
                            label:
                                Text('Actions')),
                      ],
                      rows: List.generate(filtered.length, (i) {
  final q = filtered[i];
  final String quotationId = q['id'];

  final bool isConfirmed =
      confirmStore.isConfirmed(quotationId);

  final DateTime? checkIn = q['checkInDate'] as DateTime?;
  final DateTime? checkOut = q['checkOutDate'] as DateTime?;

  final TextEditingController advanceCtrl =
      TextEditingController(
          text: (q['advance'] ?? 0).toString());

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
              await confirmStore.confirmQuotation(q);
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

      /// 🔥 NEW ADVANCE FIELD
      DataCell(
        SizedBox(
          width: 80,
          child: TextField(
            controller: advanceCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Advance",
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: (val) async {
              final int advance =
                  int.tryParse(val) ?? 0;

              await context
                  .read<QuotationHistoryStore>()
                  .updateQuotation(
                quotationId,
                {
                  ...q,
                  'advance': advance,
                },
              );
            },
          ),
        ),
      ),

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
}
