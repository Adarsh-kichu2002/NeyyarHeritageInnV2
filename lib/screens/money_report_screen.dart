import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/bill_history_store.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:sticky_headers/sticky_headers.dart';

class MoneyReportScreen extends StatelessWidget {
  const MoneyReportScreen({super.key});

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatDate(dynamic value) {
    if (value is DateTime) {
      return DateFormat('dd/MM/yyyy').format(value);
    }

    return '-';
  }

  Future<void> _generatePdf(List<Map<String, dynamic>> paidBills) async {
    final pdf = pw.Document();

    double totalAdvance = 0;
    double totalGpay = 0;
    double totalCash = 0;
    double totalAccount = 0;

    for (var bill in paidBills) {
      final payment = bill['payment'] ?? {};

      totalAdvance += _toDouble(bill['advance']);

      totalGpay += _toDouble(payment['gpay']);

      totalCash += _toDouble(payment['cash']);

      totalAccount += _toDouble(payment['account']);
    }

    final grandTotal = totalAdvance + totalGpay + totalCash + totalAccount;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Money Report',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),

          pw.SizedBox(height: 15),

          pw.TableHelper.fromTextArray(
            headers: [
              'Sl',
              'Invoice',
              'Customer',
              'Date',
              'Advance',
              'GPay',
              'Cash',
              'Account',
              'Total',
            ],
            data: List.generate(paidBills.length, (index) {
              final bill = paidBills[index];

              final payment = bill['payment'] ?? {};

              final advance = _toDouble(bill['advance']);

              final gpay = _toDouble(payment['gpay']);

              final cash = _toDouble(payment['cash']);

              final account = _toDouble(payment['account']);

              final total = advance + gpay + cash + account;

              return [
                '${index + 1}',
                '${bill['invoiceNo'] ?? ''}',
                '${bill['customerName'] ?? ''}',
                _formatDate(bill['checkOutDate']),
                advance.toStringAsFixed(0),
                gpay.toStringAsFixed(0),
                cash.toStringAsFixed(0),
                account.toStringAsFixed(0),
                total.toStringAsFixed(0),
              ];
            }),
          ),

          pw.SizedBox(height: 20),

          pw.Text('Advance Total : Rs${totalAdvance.toStringAsFixed(0)}'),
          pw.Text('GPay Total : Rs${totalGpay.toStringAsFixed(0)}'),
          pw.Text('Cash Total : Rs${totalCash.toStringAsFixed(0)}'),
          pw.Text('Account Total : Rs${totalAccount.toStringAsFixed(0)}'),

          pw.Divider(),

          pw.Text(
            'Grand Total : Rs${grandTotal.toStringAsFixed(0)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final bills = context.watch<BillHistoryStore>().bills;

    final paidBills = bills.where((bill) {
      final payment = bill['payment'];
      return payment != null;
    }).toList();

    double totalAdvance = 0;
    double totalGpay = 0;
    double totalCash = 0;
    double totalAccount = 0;

    for (var bill in paidBills) {
      final payment = bill['payment'] ?? {};

      totalAdvance += _toDouble(bill['advance']);

      totalGpay += _toDouble(payment['gpay']);

      totalCash += _toDouble(payment['cash']);

      totalAccount += _toDouble(payment['account']);
    }

    final grandTotal = totalAdvance + totalGpay + totalCash + totalAccount;

    Map<String, List<Map<String, dynamic>>> groupedBills = {};

    for (var bill in paidBills) {
      final DateTime? checkoutDate = bill['checkOutDate'];

      if (checkoutDate == null) continue;

      final monthKey = DateFormat('MMMM yyyy').format(checkoutDate);

      groupedBills.putIfAbsent(monthKey, () => []);

      groupedBills[monthKey]!.add(bill);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Money Report"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _generatePdf(paidBills),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: groupedBills.entries.map((entry) {
                final monthBills = entry.value;

                double monthTotal = 0;

                for (var bill in monthBills) {
                  final payment = bill['payment'] ?? {};

                  monthTotal +=
                      _toDouble(bill['advance']) +
                      _toDouble(payment['gpay']) +
                      _toDouble(payment['cash']) +
                      _toDouble(payment['account']);
                }

                return StickyHeader(
                  header: Container(
                    padding: const EdgeInsets.all(12),
                    color: const Color.fromARGB(255, 75, 98, 249),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '₹${monthTotal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  content: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text("Sl")),
                        DataColumn(label: Text("Invoice")),
                        DataColumn(label: Text("Customer")),
                        DataColumn(label: Text("Date")),
                        DataColumn(label: Text("Advance")),
                        DataColumn(label: Text("GPay")),
                        DataColumn(label: Text("Cash")),
                        DataColumn(label: Text("Account")),
                        DataColumn(label: Text("Total")),
                      ],
                      rows: List.generate(monthBills.length, (index) {
                        final bill = monthBills[index];

                        final payment = bill['payment'] ?? {};

                        final advance = _toDouble(bill['advance']);

                        final gpay = _toDouble(payment['gpay']);

                        final cash = _toDouble(payment['cash']);

                        final account = _toDouble(payment['account']);

                        final total = advance + gpay + cash + account;

                        return DataRow(
                          cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text('${bill['invoiceNo'] ?? ''}')),
                            DataCell(Text(bill['customerName'] ?? '')),
                            DataCell(Text(_formatDate(bill['checkOutDate']))),
                            DataCell(Text('₹${advance.toStringAsFixed(0)}')),
                            DataCell(Text('₹${gpay.toStringAsFixed(0)}')),
                            DataCell(Text('₹${cash.toStringAsFixed(0)}')),
                            DataCell(Text('₹${account.toStringAsFixed(0)}')),
                            DataCell(Text('₹${total.toStringAsFixed(0)}')),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advance Total : ₹${totalAdvance.toStringAsFixed(0)}'),
                Text('GPay Total : ₹${totalGpay.toStringAsFixed(0)}'),
                Text('Cash Total : ₹${totalCash.toStringAsFixed(0)}'),
                Text('Account Total : ₹${totalAccount.toStringAsFixed(0)}'),
                const Divider(),
                Text(
                  'Grand Total : ₹${grandTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
