import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../history/bill_history_store.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  DateTime? from;
  DateTime? to;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillHistoryStore>();

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        title: const Text('Bills'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,

        /// DOWNLOAD BUTTON
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.download),

            onSelected: _handleDownloadSelection,

            itemBuilder: (context) => const [
              PopupMenuItem(value: '7days', child: Text('Last 7 Days')),
              PopupMenuItem(value: '1month', child: Text('1 Month')),
              PopupMenuItem(
                value: 'currentMonth',
                child: Text('Current Month'),
              ),
              PopupMenuItem(value: 'custom', child: Text('Custom')),
            ],
          ),
        ],
      ),

      body: store.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                /// FILTER
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(8),

                  child: Row(
                    children: [
                      _dateBox('From', from, (d) => setState(() => from = d)),

                      const SizedBox(width: 8),

                      _dateBox('To', to, (d) => setState(() => to = d)),

                      IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () {
                          setState(() {});
                        },
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

                Expanded(child: _buildTable(store)),
              ],
            ),
    );
  }

  /// DOWNLOAD MENU
  Future<void> _handleDownloadSelection(String value) async {
    DateTime start;
    DateTime end;

    final now = DateTime.now();

    if (value == '7days') {
      start = now.subtract(const Duration(days: 7));
      end = now;
    } else if (value == '1month') {
      start = DateTime(now.year, now.month - 1, now.day);
      end = now;
    } else if (value == 'currentMonth') {
      start = DateTime(now.year, now.month, 1);
      end = now;
    } else {
      final result = await _showCustomDialog();

      if (result == null) return;

      final month = result['month']!;
      final year = result['year']!;

      start = DateTime(year, month, 1);
      end = DateTime(year, month + 1, 0, 23, 59, 59);
    }

    await _downloadBillsPdf(start, end);
  }

  /// CUSTOM MONTH/YEAR POPUP
  Future<Map<String, int>?> _showCustomDialog() async {
    final monthCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    return showDialog<Map<String, int>>(
      context: context,

      builder: (_) {
        return AlertDialog(
          title: const Text('Enter Month & Year'),

          content: Column(
            mainAxisSize: MainAxisSize.min,

            children: [
              TextField(
                controller: monthCtrl,
                keyboardType: TextInputType.number,

                decoration: const InputDecoration(labelText: 'Month'),
              ),

              TextField(
                controller: yearCtrl,
                keyboardType: TextInputType.number,

                decoration: const InputDecoration(labelText: 'Year'),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'month': int.parse(monthCtrl.text),
                  'year': int.parse(yearCtrl.text),
                });
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadBillsPdf(DateTime startDate, DateTime endDate) async {
    final store = context.read<BillHistoryStore>();

    final bills = store.bills.where((bill) {
      final DateTime? checkOut = bill['checkOutDate'];

      if (checkOut == null) return false;

      return !checkOut.isBefore(startDate) && !checkOut.isAfter(endDate);
    }).toList();

    if (bills.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No bills found')));
      return;
    }

    /// LOAD ASSETS
    final fontRegular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Regular.ttf'),
    );

    final fontBold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Roboto-Bold.ttf'),
    );

    final logoBytes = (await rootBundle.load(
      'assets/images/neyyar_logo.png',
    )).buffer.asUint8List();

    final pdf = pw.Document();

    final green = PdfColor.fromInt(
      const Color.fromARGB(255, 52, 191, 59).toARGB32(),
    );

    for (final data in bills) {
      final items = data['items'] as List? ?? [];

      const bodyStyle = pw.TextStyle(fontSize: 12, height: 1.4);

      final boldStyle = pw.TextStyle(
        fontSize: 12,
        height: 1.4,
        fontWeight: pw.FontWeight.bold,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,

          margin: const pw.EdgeInsets.all(24),

          theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),

          build: (_) {
            return [
              /// HEADER
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,

                children: [
                  pw.Image(pw.MemoryImage(logoBytes), height: 90),

                  pw.Spacer(),

                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,

                    children: [
                      pw.Text(
                        'Invoice: ${data['invoiceNo'] ?? ''}',

                        style: pw.TextStyle(
                          color: green,

                          fontWeight: pw.FontWeight.bold,

                          fontSize: 13,
                        ),
                      ),

                      pw.Text(
                        'Date: ${_fmt(data['checkOutDate'])}',

                        style: pw.TextStyle(color: green, fontSize: 12),
                      ),

                      pw.Text(
                        'GST NO: 32BUMPR0206G1ZX',

                        style: pw.TextStyle(color: green, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 16),

              /// RECEIPT TITLE
              pw.Center(
                child: pw.Text(
                  'RECEIPT',

                  style: pw.TextStyle(
                    color: green,

                    fontSize: 20,

                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 16),

              /// PARTY INFO
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,

                      children: [
                        pw.Text(data['customerName'] ?? '', style: boldStyle),

                        pw.Text(
                          'Mob: ${data['phone1'] ?? ''}',

                          style: bodyStyle,
                        ),
                      ],
                    ),
                  ),

                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,

                      children: [
                        pw.Text(
                          'Check In: ${_fmt(data['checkInDate'])}',

                          style: bodyStyle,
                        ),

                        pw.Text(
                          'Check Out: ${_fmt(data['checkOutDate'])}',

                          style: bodyStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),

              /// ITEMS TABLE
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey),

                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(2),
                  2: pw.FlexColumnWidth(2),
                  3: pw.FlexColumnWidth(2),
                },

                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: green),

                    children: [
                      _pdfHeaderCell('Description'),
                      _pdfHeaderCell('Price'),
                      _pdfHeaderCell('Qty'),
                      _pdfHeaderCell('Total'),
                    ],
                  ),

                  ...items.map((i) {
                    final qty = int.tryParse(i['qty']?.toString() ?? '') ?? 0;

                    final price =
                        int.tryParse(i['price']?.toString() ?? '') ?? 0;

                    return pw.TableRow(
                      children: [
                        _pdfCell(i['name'] ?? ''),

                        _pdfCell('₹$price'),

                        _pdfCell('$qty'),

                        _pdfCell('₹${qty * price}'),
                      ],
                    );
                  }),
                ],
              ),

              pw.SizedBox(height: 20),

              /// SUMMARY
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,

                children: [
                  pw.Expanded(
                    flex: 3,

                    child: pw.Text(
                      'Thank you for choosing us.\n'
                      'We look forward to hosting you again.\n'
                      'Best Regards,\n'
                      'Neyyar Heritage Inn.',

                      style: bodyStyle,
                    ),
                  ),

                  pw.Expanded(
                    flex: 2,

                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,

                      children: [
                        _pdfTotalRow('Total', data['subtotal'], bodyStyle),

                        _pdfTotalRow('GST (5%)', data['gst'], bodyStyle),

                        _pdfTotalRow('Advance', data['advance'], bodyStyle),

                        _pdfTotalRow('Discount', data['discount'], bodyStyle),

                        pw.Divider(),

                        _pdfTotalRow('Balance', data['balance'], boldStyle),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 24),

              /// FOOTER
              pw.Container(
                color: green,

                padding: const pw.EdgeInsets.all(10),

                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        '9656763391',

                        style: const pw.TextStyle(color: PdfColors.white),
                      ),
                    ),

                    pw.Expanded(
                      child: pw.Text(
                        'neyyarheritageinn@gmail.com',

                        textAlign: pw.TextAlign.center,

                        style: const pw.TextStyle(color: PdfColors.white),
                      ),
                    ),

                    pw.Expanded(
                      child: pw.Text(
                        'www.neyyarheritage.in',

                        textAlign: pw.TextAlign.right,

                        style: const pw.TextStyle(color: PdfColors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (_) async {
        return pdf.save();
      },
    );
  }

  Widget _buildTable(BillHistoryStore store) {
    final filtered = store.bills.where((bill) {
      final DateTime? checkOut = bill['checkOutDate'];

      if (from == null && to == null) {
        return true;
      }

      if (checkOut == null) {
        return false;
      }

      if (from != null && checkOut.isBefore(_startOfDay(from!))) {
        return false;
      }

      if (to != null && checkOut.isAfter(_endOfDay(to!))) {
        return false;
      }

      return true;
    }).toList();

    /// SORT DESCENDING
    filtered.sort((a, b) {
      final DateTime? dateA = a['checkOutDate'];

      final DateTime? dateB = b['checkOutDate'];

      if (dateA == null && dateB == null) {
        return 0;
      }

      if (dateA == null) {
        return 1;
      }

      if (dateB == null) {
        return -1;
      }

      return dateB.compareTo(dateA);
    });

    if (filtered.isEmpty) {
      return const Center(child: Text('No bills found'));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,

      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,

        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),

          columns: const [
            DataColumn(label: Text('SI')),
            DataColumn(label: Text('Invoice')),
            DataColumn(label: Text('Guest')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Check In')),
            DataColumn(label: Text('Check Out')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Actions')),
          ],

          rows: List.generate(filtered.length, (i) {
            final b = filtered[i];

            final payment = b['payment'];

            final paidAmount = payment != null
                ? int.tryParse(payment['paidAmount']?.toString() ?? '') ?? 0
                : 0;

            final isPaid = paidAmount > 0;

            return DataRow(
              color: WidgetStateProperty.resolveWith((_) {
                if (isPaid) {
                  return const Color.fromARGB(255, 245, 221, 8);
                }

                return Colors.white;
              }),

              cells: [
                DataCell(Text('${i + 1}')),

                DataCell(Text('${b['invoiceNo']}')),

                DataCell(Text(b['customerName'] ?? '')),

                DataCell(Text('${b['phone1']}')),

                DataCell(Text(_fmt(b['checkInDate']))),

                DataCell(Text(_fmt(b['checkOutDate']))),

                DataCell(Text('₹${b['balance']}')),

                DataCell(
                  Row(
                    children: [
                      /// VIEW
                      IconButton(
                        icon: const Icon(Icons.visibility, color: Colors.green),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/bill_preview',
                            arguments: {...b, 'isViewOnly': true},
                          );
                        },
                      ),

                      /// EDIT DISABLED AFTER PAYMENT
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: isPaid ? Colors.grey : Colors.blue,
                        ),

                        onPressed: isPaid
                            ? null
                            : () {
                                Navigator.pushNamed(
                                  context,
                                  '/bill_screen',
                                  arguments: {
                                    ...b,
                                    'isViewOnly': false,
                                    'isEdit': true,
                                    'billId': b['billId'],
                                  },
                                );
                              },
                      ),

                      /// PAYMENT
                      IconButton(
                        icon: const Icon(
                          Icons.currency_rupee,
                          color: Colors.purple,
                        ),

                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/payment_screen',
                            arguments: {...b, 'isReadOnlyPayment': true},
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
    );
  }

  Widget _dateBox(String label, DateTime? value, Function(DateTime) onPick) {
    return OutlinedButton(
      onPressed: () async {
        final d = await showDatePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          initialDate: value ?? DateTime.now(),
        );

        if (d != null) {
          onPick(d);
        }
      },

      child: Text(
        value == null ? label : DateFormat('dd/MM/yyyy').format(value),
      ),
    );
  }

  String _fmt(DateTime? d) {
    if (d == null) {
      return '';
    }

    return DateFormat('dd/MM/yyyy').format(d);
  }

  DateTime _startOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day);
  }

  DateTime _endOfDay(DateTime d) {
    return DateTime(d.year, d.month, d.day, 23, 59, 59);
  }

  /// PDF TABLE HEADER
  pw.Widget _pdfHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  /// PDF NORMAL CELL
  pw.Widget _pdfCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text),
    );
  }

  /// PDF TOTAL ROW
  pw.Widget _pdfTotalRow(String label, dynamic value, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text('₹${int.tryParse(value?.toString() ?? '') ?? 0}', style: style),
      ],
    );
  }
}
