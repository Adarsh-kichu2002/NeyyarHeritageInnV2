import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../history/bill_history_store.dart';

class BillHistoryTab extends StatefulWidget {
  const BillHistoryTab({super.key});

  @override
  State<BillHistoryTab> createState() => _BillHistoryTabState();
}

class _BillHistoryTabState extends State<BillHistoryTab> {
  DateTime? from;
  DateTime? to;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = store.bills.where((bill) {
      final DateTime? checkOut = bill['checkOutDate'];

      if (from == null && to == null) return true;
      if (checkOut == null) return false;

      if (from != null && checkOut.isBefore(_startOfDay(from!))) return false;
      if (to != null && checkOut.isAfter(_endOfDay(to!))) return false;

      return true;
    }).toList();

    return Column(
      children: [
        /// FILTER
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _dateBox('From', from, (d) => setState(() => from = d)),
              const SizedBox(width: 8),
              _dateBox('To', to, (d) => setState(() => to = d)),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {}),
              ),
              if (from != null || to != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      from = null;
                      to = null;
                    });
                  },
                ),
            ],
          ),
        ),

        /// TABLE
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No bills found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('SI')),
                        DataColumn(label: Text('Invoice')),
                        DataColumn(label: Text('Guest')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Check In')),
                        DataColumn(label: Text('Check Out')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Status')), // ✅ NEW
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: List.generate(filtered.length, (i) {
                        final b = filtered[i];

                        /// 🔥 PAYMENT LOGIC
final payment = b['payment'];

final int paidAmount =
    payment != null ? (payment['paidAmount'] ?? 0) : 0;

/// ✅ NEW LOGIC
/// If any amount is entered → PAID
/// If no amount entered → UNPAID
final bool isPaid = paidAmount > 0;

                        return DataRow(
                          /// ✅ ROW COLOR
                          color:
                              WidgetStateProperty.resolveWith<Color?>(
                            (states) {
                              if (isPaid) {
                                return const Color.fromARGB(255, 245, 221, 8);
                              }
                              return null;
                            },
                          ),
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text('${b['invoiceNo']}')),
                            DataCell(Text(b['customerName'] ?? '')),
                            DataCell(Text('${b['phone1']}')),
                            DataCell(Text(_fmt(b['checkInDate']))),
                            DataCell(Text(_fmt(b['checkOutDate']))),

                            /// ✅ TOTAL + PAID INFO
                            DataCell(
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text('₹${b['balance']}'),
                                  Text(
                                    'Paid: ₹$paidAmount',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),

                            /// ✅ STATUS BADGE
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      isPaid ? Colors.green : Colors.red,
                                  borderRadius:
                                      BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPaid ? 'PAID' : 'UNPAID',
                                  style: const TextStyle(
                                      color: Colors.white),
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
  '/bill_preview',
  arguments: {
    ...b,
    'isViewOnly': true,
  },
);
                                    },
                                  ),

                                  /// EDIT
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        color: Colors.blue),
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/bill_screen',
                                        arguments: {
                                          ...b,
                                          'isEdit': true,
                                          'isViewOnly': false,
                                          'billId': b['billId'],
                                        },
                                      );
                                    },
                                  ),

                                  /// PAYMENT
                                  IconButton(
                                    icon: const Icon(
                                      Icons.currency_rupee,
                                      color: Color.fromARGB(
                                          255, 204, 3, 239),
                                    ),
                                    onPressed: () {
                                      Navigator.pushNamed(
  context,
  '/payment_screen',
  arguments: {
    ...b,
    'isReadOnlyPayment': false, // ✅ editable
  },
);
                                    },
                                  ),

                                  /// DELETE
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _confirmDelete(
                                        context, b['billId']),
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

  /// DELETE CONFIRM
  Future<void> _confirmDelete(
      BuildContext context, String billId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (ok == true) {
      context.read<BillHistoryStore>().deleteBill(billId);
    }
  }

  /// DATE PICKER
  Widget _dateBox(
      String label, DateTime? value, Function(DateTime) onPick) {
    return OutlinedButton(
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );
        if (d != null) onPick(d);
      },
      child: Text(
        value == null
            ? label
            : DateFormat('dd/MM/yyyy').format(value),
      ),
    );
  }

  String _fmt(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

  DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);
}
