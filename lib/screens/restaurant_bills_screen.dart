import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../widgets/list_filter_dialog.dart';
import '../services/restaurant_bill_service.dart';

/// List of saved Restaurant Bills — View / Edit / Payment (no GST column).
class RestaurantBillsScreen extends StatefulWidget {
  const RestaurantBillsScreen({super.key});

  @override
  State<RestaurantBillsScreen> createState() => _RestaurantBillsScreenState();
}

class _RestaurantBillsScreenState extends State<RestaurantBillsScreen> {
  DateTime? from;
  DateTime? to;
  String customerName = '';
  String role = 'staff';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    role = (args?['role'] ?? 'staff').toString().trim().toLowerCase();
  }

  Future<void> _openFilter() async {
    final result = await showListFilterDialog(
      context,
      initial: ListFilterValues(
        customerName: customerName,
        from: from,
        to: to,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      customerName = result.customerName;
      from = result.from;
      to = result.to;
    });
  }

  String _money(dynamic v) {
    final n = v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  }

  String _fmtDate(dynamic d) {
    if (d is DateTime) return DateFormat('dd/MM/yyyy').format(d);
    return '—';
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> bills) {
    final nameQuery = customerName.trim().toLowerCase();
    return bills.where((b) {
      if (nameQuery.isNotEmpty) {
        final name = (b['customerName'] ?? '').toString().toLowerCase();
        if (!name.contains(nameQuery)) return false;
      }
      final created = b['createdAt'];
      if (created is! DateTime) return from == null && to == null;
      if (from != null) {
        final start = DateTime(from!.year, from!.month, from!.day);
        if (created.isBefore(start)) return false;
      }
      if (to != null) {
        final end = DateTime(to!.year, to!.month, to!.day, 23, 59, 59);
        if (created.isAfter(end)) return false;
      }
      return true;
    }).toList();
  }

  bool _isPaid(Map<String, dynamic> bill) {
    return _paidAmount(bill) > 0;
  }

  double _paidAmount(Map<String, dynamic> bill) {
    final payment = bill['payment'];
    if (payment is! Map) return 0;
    final paid = payment['paidAmount'];
    if (paid is num) return paid.toDouble();
    final parsed = double.tryParse(paid?.toString() ?? '');
    if (parsed != null) return parsed;

    double readAmount(dynamic value) => value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    return readAmount(payment['gpay']) +
        readAmount(payment['cash']) +
        readAmount(payment['account']);
  }

  bool get _isAdmin => role == 'admin';

  Future<void> _confirmDelete(Map<String, dynamic> bill) async {
    if (!_isAdmin) return;

    final billId = bill['billId']?.toString() ?? '';
    if (billId.isEmpty) return;

    final label = bill['billNumber'] != null
        ? 'Bill #${bill['billNumber']}'
        : 'this restaurant bill';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bill'),
        content: Text(
          'Delete $label permanently from the database?\n'
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    try {
      await context.read<RestaurantBillStore>().deleteBill(billId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restaurant bill deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete bill: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RestaurantBillStore>();
    final bills = _filtered(store.bills);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Bills'),
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : bills.isEmpty
              ? const Center(child: Text('No restaurant bills found'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return Scrollbar(
                      child: SingleChildScrollView(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minWidth: constraints.maxWidth,
                            ),
                            child: DataTable(
                              headingRowColor: WidgetStatePropertyAll(
                                Theme.of(context).primaryColor,
                              ),
                              columns: const [
                                DataColumn(label: Text('SI')),
                                DataColumn(label: Text('Bill #')),
                                DataColumn(label: Text('Guest')),
                                DataColumn(label: Text('Phone')),
                                DataColumn(label: Text('Date')),
                                DataColumn(
                                  label: Text('Total'),
                                  numeric: true,
                                ),
                                DataColumn(label: Text('Paid'), numeric: true),
                                DataColumn(label: Text('Actions')),
                              ],
                              rows: List.generate(bills.length, (i) {
                                final b = bills[i];
                                final isPaid = _isPaid(b);
                                final canEditBill = !isPaid || _isAdmin;

                                return DataRow(
                                  color: WidgetStateProperty.resolveWith((_) {
                                    if (isPaid) {
                                      return const Color.fromARGB(
                                          255, 245, 221, 8);
                                    }
                                    return Colors.white;
                                  }),
                                  cells: [
                                    DataCell(Text('${i + 1}')),
                                    DataCell(
                                      Text('${b['billNumber'] ?? ''}'),
                                    ),
                                    DataCell(
                                      Text('${b['customerName'] ?? ''}'),
                                    ),
                                    DataCell(
                                      Text('${b['phoneNumber'] ?? ''}'),
                                    ),
                                    DataCell(Text(_fmtDate(b['createdAt']))),
                                    DataCell(
                                      Text('₹${_money(b['grandTotal'])}'),
                                    ),
                                    DataCell(
                                      Text('₹${_money(_paidAmount(b))}'),
                                    ),
                                    DataCell(
                                      Row(
                                        children: [
                                          /// VIEW
                                          IconButton(
                                            tooltip: 'View',
                                            icon: const Icon(
                                              Icons.visibility,
                                              color: Colors.green,
                                            ),
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                context,
                                                '/restaurant_bill_preview',
                                                arguments: {
                                                  ...b,
                                                  'isViewOnly': true,
                                                  'role': role,
                                                },
                                              );
                                            },
                                          ),

                                          /// Paid bills remain editable by admins.
                                          IconButton(
                                            tooltip: canEditBill
                                                ? 'Edit'
                                                : 'Paid — staff cannot edit',
                                            icon: Icon(
                                              Icons.edit,
                                              color: canEditBill
                                                  ? Colors.blue
                                                  : Colors.grey,
                                            ),
                                            onPressed: !canEditBill
                                                ? null
                                                : () {
                                                    Navigator.pushNamed(
                                                      context,
                                                      '/restaurant_customer',
                                                      arguments: {
                                                        ...b,
                                                        'isEdit': true,
                                                        'isViewOnly': false,
                                                        'role': role,
                                                        'billId': b['billId'],
                                                      },
                                                    );
                                                  },
                                          ),

                                          /// PAYMENT
                                          IconButton(
                                            tooltip: 'Payment',
                                            icon: const Icon(
                                              Icons.currency_rupee,
                                              color: Colors.purple,
                                            ),
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                context,
                                                '/restaurant_payment',
                                                arguments: {
                                                  ...b,
                                                  'role': role,
                                                },
                                              );
                                            },
                                          ),

                                          /// DELETE (admin only)
                                          if (_isAdmin)
                                            IconButton(
                                              tooltip: 'Delete',
                                              icon: const Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                              ),
                                              onPressed: () =>
                                                  _confirmDelete(b),
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
                    );
                  },
                ),
    );
  }
}
