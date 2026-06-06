import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/bill_history_store.dart';
import 'package:provider/provider.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MoneyChartScreen extends StatelessWidget {
  const MoneyChartScreen({super.key});

  Future<void> _downloadPdf(
    BuildContext context,
    Map<String, List<Map<String, dynamic>>> groupedBills,
  ) async {
    final pdf = pw.Document();

    double grandAdvance = 0;
    double grandGpay = 0;
    double grandCash = 0;
    double grandAccount = 0;

    pdf.addPage(
      pw.MultiPage(
        build: (context) {
          final widgets = <pw.Widget>[];

          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                'Money Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );

          groupedBills.forEach((month, bills) {
            double monthAdvance = 0;
            double monthGpay = 0;
            double monthCash = 0;
            double monthAccount = 0;

            final rows = <List<String>>[];

            for (final bill in bills) {
              final payment =
                  bill['payment'] ?? {};

              final advance =
                  (bill['advance'] ?? 0)
                      .toDouble();

              final gpay =
                  (payment['gpay'] ?? 0)
                      .toDouble();

              final cash =
                  (payment['cash'] ?? 0)
                      .toDouble();

              final account =
                  (payment['account'] ?? 0)
                      .toDouble();

              monthAdvance += advance;
              monthGpay += gpay;
              monthCash += cash;
              monthAccount += account;

              grandAdvance += advance;
              grandGpay += gpay;
              grandCash += cash;
              grandAccount += account;

              rows.add([
                DateFormat('dd/MM/yyyy').format(
                  bill['checkOutDate'],
                ),
                advance.toStringAsFixed(0),
                gpay.toStringAsFixed(0),
                cash.toStringAsFixed(0),
                account.toStringAsFixed(0),
              ]);
            }

            widgets.add(
              pw.SizedBox(height: 15),
            );

            widgets.add(
              pw.Text(
                month,
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight:
                      pw.FontWeight.bold,
                ),
              ),
            );

            widgets.add(
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Date',
                  'Advance',
                  'GPay',
                  'Cash',
                  'Account',
                ],
                data: rows,
              ),
            );

            widgets.add(
              pw.Container(
                padding:
                    const pw.EdgeInsets.all(8),
                child: pw.Text(
                  'Month Total - Advance: Rs${monthAdvance.toStringAsFixed(0)} | GPay: Rs${monthGpay.toStringAsFixed(0)} | Cash: Rs${monthCash.toStringAsFixed(0)} | Account: Rs${monthAccount.toStringAsFixed(0)}',
                ),
              ),
            );
          });

          widgets.add(
            pw.Divider(),
          );

          widgets.add(
            pw.Text(
              'GRAND TOTAL',
              style: pw.TextStyle(
                fontWeight:
                    pw.FontWeight.bold,
                fontSize: 18,
              ),
            ),
          );

          widgets.add(
            pw.Text(
              'Advance : Rs${grandAdvance.toStringAsFixed(0)}',
            ),
          );

          widgets.add(
            pw.Text(
              'GPay : Rs${grandGpay.toStringAsFixed(0)}',
            ),
          );

          widgets.add(
            pw.Text(
              'Cash : Rs${grandCash.toStringAsFixed(0)}',
            ),
          );

          widgets.add(
            pw.Text(
              'Account : Rs${grandAccount.toStringAsFixed(0)}',
            ),
          );

          return widgets;
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'money_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store =
        context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    final bills = store.bills;

    final paidBills = bills.where((bill) {
      return bill['payment'] != null;
    }).toList();

    final Map<String,
            List<Map<String, dynamic>>>
        groupedBills = {};

    for (final bill in paidBills) {
      final DateTime date =
          bill['checkOutDate'];

      final monthKey =
          DateFormat('MMMM yyyy')
              .format(date);

      groupedBills.putIfAbsent(
        monthKey,
        () => [],
      );

      groupedBills[monthKey]!.add(bill);
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Money Chart'),
        actions: [
          IconButton(
            icon: const Icon(
                Icons.picture_as_pdf),
            onPressed: () =>
                _downloadPdf(
              context,
              groupedBills,
            ),
          ),
        ],
      ),
      body: ListView(
        children:
            groupedBills.entries.map(
          (entry) {
            double monthAdvance = 0;
            double monthGpay = 0;
            double monthCash = 0;
            double monthAccount = 0;

            for (final bill
                in entry.value) {
              final payment =
                  bill['payment'] ?? {};

              monthAdvance +=
                  ((bill['advance'] ??
                          0)
                      as num)
                      .toDouble();

              monthGpay +=
                  ((payment['gpay'] ?? 0)
                          as num)
                      .toDouble();

              monthCash +=
                  ((payment['cash'] ?? 0)
                          as num)
                      .toDouble();

              monthAccount +=
                  ((payment['account'] ??
                          0)
                      as num)
                      .toDouble();
            }

            return StickyHeader(
              header: Container(
                width: double.infinity,
                color: const Color.fromARGB(255, 75, 98, 249),
                padding:
                    const EdgeInsets.all(
                        12),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      entry.key,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    const SizedBox(
                        height: 4),
                    Text(
                      'Advance ₹${monthAdvance.toStringAsFixed(0)} | GPay ₹${monthGpay.toStringAsFixed(0)} | Cash ₹${monthCash.toStringAsFixed(0)} | Account ₹${monthAccount.toStringAsFixed(0)}',
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              content:
                  SingleChildScrollView(
                scrollDirection:
                    Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(
                      label:
                          Text('Date'),
                    ),
                    DataColumn(
                      label: Text(
                          'Advance'),
                    ),
                    DataColumn(
                      label:
                          Text('GPay'),
                    ),
                    DataColumn(
                      label:
                          Text('Cash'),
                    ),
                    DataColumn(
                      label: Text(
                          'Account'),
                    ),
                  ],
                  rows: entry.value
                      .map(
                    (bill) {
                      final payment =
                          bill['payment'] ??
                              {};

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              DateFormat(
                                      'dd/MM/yyyy')
                                  .format(
                                bill[
                                    'checkOutDate'],
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${bill['advance'] ?? 0}',
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${payment['gpay'] ?? 0}',
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${payment['cash'] ?? 0}',
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${payment['account'] ?? 0}',
                            ),
                          ),
                        ],
                      );
                    },
                  ).toList(),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }
}
