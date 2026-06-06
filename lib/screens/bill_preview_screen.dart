import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../history/bill_history_store.dart';
import '../history/confirm_store.dart';

class BillPreviewScreen extends StatefulWidget {
  const BillPreviewScreen({super.key});

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  final Color green = const Color.fromARGB(255, 52, 191, 59);

  bool _saving = false;

  /// Prevent double-click only while this screen is open
  bool _savedInThisSession = false;

  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  String _fmtDate(dynamic d) {
    if (d is DateTime) {
      return DateFormat('dd/MM/yyyy').format(d);
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args == null || args is! Map<String, dynamic>) {
      return const Scaffold(
        body: Center(child: Text('No bill data available')),
      );
    }

    final Map<String, dynamic> data = args;

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Preview')),
      bottomNavigationBar: _actions(context, data),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _header(data),
            const SizedBox(height: 12),
            _receiptTitle(),
            const SizedBox(height: 12),
            _partyInfo(data),
            const SizedBox(height: 16),
            _itemsTable(data),
            const SizedBox(height: 16),
            _summaryWithNotes(data),
            const SizedBox(height: 16),
            _footer(),
          ],
        ),
      ),
    );
  }

  /// ---------------- UI ----------------

  Widget _header(Map<String, dynamic> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Image.asset(
            'assets/images/neyyar_logo.png',
            height: 90,
            fit: BoxFit.contain,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Invoice: ${data['invoiceNo']}',
              style: TextStyle(color: green, fontWeight: FontWeight.bold),
            ),
            Text(
              'Date: ${_fmtDate(data['checkOutDate'])}',
              style: TextStyle(color: green),
            ),
            Text('GST NO: 32BUMPR0206G1ZX', style: TextStyle(color: green) 
            )
          ],
        ),
      ],
    );
  }

  Widget _receiptTitle() => Text(
        'RECEIPT',
        style: TextStyle(color: green, fontSize: 20, fontWeight: FontWeight.bold),
      );

  Widget _partyInfo(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['customerName'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Mob: ${data['phone1'] ?? ''}'),
          ]),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Check In: ${_fmtDate(data['checkInDate'])}'),
            Text('Check Out: ${_fmtDate(data['checkOutDate'])}'),
          ]),
        ),
      ],
    );
  }

  Widget _itemsTable(Map<String, dynamic> data) {
    final items = data['items'] as List? ?? [];

    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(2),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: green),
          children: const [
            _HeaderCell('Description'),
            _HeaderCell('Price'),
            _HeaderCell('Qty'),
            _HeaderCell('Total'),
          ],
        ),
        ...items.map((i) {
          final qty = _toInt(i['qty']);
          final price = _toInt(i['price']);
          return TableRow(
            children: [
              _Cell(i['name'] ?? ''),
              _Cell('₹$price'),
              _Cell('$qty'),
              _Cell('₹${qty * price}'),
            ],
          );
        }),
      ],
    );
  }

  Widget _summaryWithNotes(Map<String, dynamic> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          flex: 3,
          child: Text(
            'Thank you for choosing us.\n'
            'We look forward to hosting you again.\n'
            'Best Regards,\nNeyyar Heritage Inn.',
          ),
        ),
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _totalRow('Total', data['subtotal']),
              _totalRow('GST (5%)', data['gst']),
              _totalRow('Advance', data['advance']),
              _totalRow('Discount', data['discount']),
              const Divider(),
              _totalRow('Balance', data['balance'], bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, dynamic value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
        Text('₹${_toInt(value)}',
            style: TextStyle(fontWeight: bold ? FontWeight.bold : null)),
      ],
    );
  }

  Widget _footer() {
    return Container(
      color: green,
      padding: const EdgeInsets.all(8),
      child: const Row(
        children: [
          Expanded(
              child:
                  Text('9656763391', style: TextStyle(color: Colors.white))),
          Expanded(
              child: Text('neyyarheritageinn@gmail.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white))),
          Expanded(
              child: Text('www.neyyarheritage.in',
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
 // Actions like Save & Download PDF
Widget _actions(BuildContext context, Map<String, dynamic> data) {
  final bool isViewOnly = data['isViewOnly'] == true;

  return Padding(
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(
              (isViewOnly || _savedInThisSession)
                  ? Icons.check_circle
                  : Icons.save,
            ),
            label: Text(
              isViewOnly
                  ? 'Saved'
                  : _savedInThisSession
                      ? 'Saved'
                      : (_saving
                          ? 'Saving...'
                          : 'Save & Download'),
            ),
            onPressed: (isViewOnly ||
                    _saving ||
                    _savedInThisSession)
                ? null
                : () async {
                    setState(() {
                      _saving = true;
                    });

                    final billId = data['billId'] ??
                        DateTime.now()
                            .millisecondsSinceEpoch
                            .toString();

                    List<Map<String, dynamic>> cleanItems(
                        List items) {
                      return items.map<Map<String, dynamic>>((i) {
                        return {
                          'name': i['name'],
                          'qty': i['qty'],
                          'price': i['price'],
                        };
                      }).toList();
                    }

                    final finalData = {
                      ...data,
                      'billId': billId,

                      if (data['items'] != null)
                        'items': cleanItems(
                          data['items'],
                        ),
                    };

                    try {
                      await context
                          .read<BillHistoryStore>()
                          .addOrUpdateBill(finalData);

                          final confirmId = data['confirmId'];

if (confirmId != null) {
  await context
      .read<ConfirmStore>()
      .markBillGenerated(
        confirmId: confirmId,
        billId: billId,
      );
}

                      if (!mounted) return;

                      await _downloadPdf(finalData);

                      setState(() {
                        _saving = false;

                        // Prevent duplicate save only
                        // while this screen remains open
                        _savedInThisSession = true;
                      });

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Bill saved successfully',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;

                      setState(() {
                        _saving = false;
                      });

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error: $e',
                          ),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    ),
  );
}

    
    // PDF Generation
  Future<void> _downloadPdf(Map<String, dynamic> data) async {
  final fontRegular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final fontBold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

  final logoBytes = (await rootBundle.load('assets/images/neyyar_logo.png'))
      .buffer
      .asUint8List();

  final pdf = pw.Document();

  final green = PdfColor.fromInt(const Color.fromARGB(255, 52, 191, 59).value);

  final items = data['items'] as List? ?? [];

  pw.TextStyle body = const pw.TextStyle(fontSize: 12, height: 1.4);
  pw.TextStyle bold =
      pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, height: 1.4);

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => [
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
                      fontSize: 13),
                ),
                pw.Text(
                  'Date: ${_fmtDate(data['checkOutDate'])}',
                  style: pw.TextStyle(color: green, fontSize: 12),
                ),
                pw.Text('GST NO: 32BUMPR0206G1ZX',
                    style: pw.TextStyle(color: green, fontSize: 12))
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
                  pw.Text(data['customerName'] ?? '', style: bold),
                  pw.Text('Mob: ${data['phone1'] ?? ''}', style: body),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('Check In: ${_fmtDate(data['checkInDate'])}',
                      style: body),
                  pw.Text('Check Out: ${_fmtDate(data['checkOutDate'])}',
                      style: body),
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
              final qty = _toInt(i['qty']);
              final price = _toInt(i['price']);
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

        /// SUMMARY + NOTES
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
                style: body,
              ),
            ),
            pw.Expanded(
              flex: 2,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _pdfTotalRow('Total', data['subtotal'], body),
                  _pdfTotalRow('GST (5%)', data['gst'], body),
                  _pdfTotalRow('Advance', data['advance'], body),
                  _pdfTotalRow('Discount', data['discount'], body),
                  pw.Divider(),
                  _pdfTotalRow('Balance', data['balance'], bold),
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
      ],
    ),
  );

  await Printing.layoutPdf(onLayout: (_) => pdf.save());
}
}

pw.Widget _pdfHeaderCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(
      text,
      style: pw.TextStyle(
          color: PdfColors.white, fontWeight: pw.FontWeight.bold),
    ),
  );
}

pw.Widget _pdfCell(String text) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(8),
    child: pw.Text(text),
  );
}

pw.Widget _pdfTotalRow(String label, dynamic value, pw.TextStyle style) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: style),
      pw.Text('₹${int.tryParse(value?.toString() ?? '') ?? 0}', style: style),
    ],
  );
}


class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

class _Cell extends StatelessWidget {
  final String text;
  const _Cell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(8), child: Text(text));
  }
}
