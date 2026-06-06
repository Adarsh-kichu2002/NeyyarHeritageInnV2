import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/bill_history_store.dart';
import 'package:neyyar_heritage/history/confirm_store.dart';
import 'package:provider/provider.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  DateTime? from;
  DateTime? to;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConfirmStore>();
    final billStore = context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filtered = store.confirmedQuotations.where((q) {
      final DateTime? checkInDate = q['checkInDate'];

      if (checkInDate == null) return false;

      /// From date filter
      if (from != null) {
        final fromDate = DateTime(from!.year, from!.month, from!.day);

        if (checkInDate.isBefore(fromDate)) {
          return false;
        }
      }

      /// To date filter
      if (to != null) {
        final toDate = DateTime(to!.year, to!.month, to!.day, 23, 59, 59);

        if (checkInDate.isAfter(toDate)) {
          return false;
        }
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Confirmed Quotations")),
      body: Column(
        children: [
          /// FILTER BAR
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _dateBox('From', from, (d) => setState(() => from = d)),
                const SizedBox(width: 8),
                _dateBox('To', to, (d) => setState(() => to = d)),
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

          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text("No Confirmed Quotations"))
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('SI')),
                          DataColumn(label: Text('Advance')),
                          DataColumn(label: Text('Guest')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Created On')),
                          DataColumn(label: Text('Package')),
                          DataColumn(label: Text('Check In')),
                          DataColumn(label: Text('Check Out')),
                          DataColumn(label: Text('Total Pax')), // 🔥 Added
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: List.generate(filtered.length, (i) {
                          final q = filtered[i];
                          final billId = _generatedBillId(q, billStore.bills);
                          final billGenerated = billId != null;

                          final DateTime? created =
                              q['createdAt']; // 🔥 FIXED KEY

                          return DataRow(
                            cells: [
                              DataCell(Text('${i + 1}')),
                              DataCell(
                                Text('${q['advance'] ?? 0}'),
                              ), // 🔥 Added
                              DataCell(Text(q['customerName'] ?? '')),
                              DataCell(Text(q['phone1'] ?? '')),
                              DataCell(
                                Text(
                                  created != null
                                      ? DateFormat('dd/MM/yyyy').format(created)
                                      : '',
                                ),
                              ),
                              DataCell(Text(q['package'] ?? '')),
                              DataCell(
                                Text(
                                  q['checkInDate'] != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(q['checkInDate'])
                                      : '',
                                ),
                              ),
                              DataCell(
                                Text(
                                  q['checkOutDate'] != null
                                      ? DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(q['checkOutDate'])
                                      : '',
                                ),
                              ),
                              DataCell(
                                Text('${q['totalPax'] ?? 0}'),
                              ), // 🔥 Added
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.visibility,
                                        color: Colors.green,
                                      ),
                                      onPressed: () {
                                        Navigator.pushNamed(
                                          context,
                                          '/quotation_preview_screen',
                                          arguments: q,
                                        );
                                      },
                                    ),

                                    IconButton(
                                      tooltip: billGenerated
                                          ? 'Bill Already Generated'
                                          : 'Generate Bill',
                                      icon: Icon(
                                        Icons.receipt_long,
                                        color: billGenerated
                                            ? Colors.grey
                                            : Colors.orange,
                                      ),
                                      onPressed: billGenerated
                                          ? null
                                          : () {
                                              final latestBillId =
                                                  _generatedBillId(
                                                    q,
                                                    context
                                                        .read<
                                                          BillHistoryStore
                                                        >()
                                                        .bills,
                                                  );

                                              if (latestBillId != null) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Bill already generated for this customer',
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }

                                              Navigator.pushNamed(
                                                context,
                                                '/bill_screen',
                                                arguments: q,
                                              );
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
      ),
    );
  }

  Widget _dateBox(String label, DateTime? value, Function(DateTime) onPick) {
    return OutlinedButton(
      child: Text(
        value == null ? label : DateFormat('dd/MM/yyyy').format(value),
      ),
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );
        if (d != null) onPick(d);
      },
    );
  }

  String? _generatedBillId(
    Map<String, dynamic> quotation,
    List<Map<String, dynamic>> bills,
  ) {
    final existingBillId = quotation['billId']?.toString();
    if (quotation['billGenerated'] == true) {
      return existingBillId != null && existingBillId.isNotEmpty
          ? existingBillId
          : 'generated';
    }

    for (final bill in bills) {
      final billId = bill['billId']?.toString();
      if (billId == null || billId.isEmpty) continue;

      if (_sameValue(bill['confirmId'], quotation['confirmId']) ||
          _sameValue(
            bill['originalQuotationId'],
            quotation['originalQuotationId'],
          )) {
        return billId;
      }

      final sameCustomer =
          _sameText(bill['customerName'], quotation['customerName']) &&
          _sameText(bill['phone1'], quotation['phone1']);
      final sameStay =
          _sameDate(bill['checkInDate'], quotation['checkInDate']) &&
          _sameDate(bill['checkOutDate'], quotation['checkOutDate']);

      if (sameCustomer && sameStay) {
        return billId;
      }
    }

    return null;
  }

  bool _sameValue(dynamic a, dynamic b) {
    final left = a?.toString();
    final right = b?.toString();
    return left != null && left.isNotEmpty && left == right;
  }

  bool _sameText(dynamic a, dynamic b) {
    final left = a?.toString().trim().toLowerCase();
    final right = b?.toString().trim().toLowerCase();
    return left != null && left.isNotEmpty && left == right;
  }

  bool _sameDate(dynamic a, dynamic b) {
    if (a is! DateTime || b is! DateTime) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
