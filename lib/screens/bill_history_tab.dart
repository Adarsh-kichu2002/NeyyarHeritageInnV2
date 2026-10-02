import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../history/bill_history_store.dart';

class BillHistoryTab extends StatefulWidget {
  const BillHistoryTab({
    super.key,
    this.customerName = '',
    this.from,
    this.to,
    this.bottomInset = 0,
  });

  final String customerName;
  final DateTime? from;
  final DateTime? to;

  /// Scroll-only clearance for a parent floating nav (not structural padding).
  final double bottomInset;

  @override
  State<BillHistoryTab> createState() => _BillHistoryTabState();
}

class _BillHistoryTabState extends State<BillHistoryTab> {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final nameQuery = widget.customerName.trim().toLowerCase();
    final filtered = store.bills.where((bill) {
      if (nameQuery.isNotEmpty) {
        final name = (bill['customerName'] ?? '').toString().toLowerCase();
        if (!name.contains(nameQuery)) return false;
      }

      final DateTime? checkOut = bill['checkOutDate'];

      if (widget.from == null && widget.to == null) return true;
      if (checkOut == null) return false;

      if (widget.from != null && checkOut.isBefore(_startOfDay(widget.from!))) {
        return false;
      }
      if (widget.to != null && checkOut.isAfter(_endOfDay(widget.to!))) {
        return false;
      }

      return true;
    }).toList();

    return Column(
      children: [
        /// TABLE
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No bills found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: EdgeInsets.only(bottom: widget.bottomInset),
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

  String _fmt(DateTime? d) =>
      d == null ? '' : DateFormat('dd/MM/yyyy').format(d);

  DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);
}
