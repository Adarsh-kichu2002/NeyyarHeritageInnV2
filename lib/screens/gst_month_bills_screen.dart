import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../history/gst_store.dart';

class GstMonthBillsScreen extends StatefulWidget {
  const GstMonthBillsScreen({super.key});

  @override
  State<GstMonthBillsScreen> createState() => _GstMonthBillsScreenState();
}

class _GstMonthBillsScreenState extends State<GstMonthBillsScreen> {
  String? folderId;
  String label = 'GST Bills';
  bool _initialized = false;
  bool _downloading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    folderId = args?['folderId']?.toString();
    label = args?['label']?.toString() ?? 'GST Bills';
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<GstStore>();
    final bills =
        folderId == null ? <Map<String, dynamic>>[] : store.billsForFolder(folderId!);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(label),
        actions: [
          IconButton(
            tooltip: 'Download PDF',
            icon: _downloading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            onPressed: _downloading || bills.isEmpty
                ? null
                : () => _downloadFolderPdf(bills),
          ),
        ],
      ),
      body: bills.isEmpty
          ? const Center(child: Text('No bills in this folder'))
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(Colors.grey.shade200),
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
                  rows: List.generate(bills.length, (i) {
                    final b = bills[i];
                    return DataRow(
                      cells: [
                        DataCell(Text('${i + 1}')),
                        DataCell(Text('${b['gstInvoiceNo']}')),
                        DataCell(Text(b['customerName'] ?? '')),
                        DataCell(Text('${b['phone1'] ?? ''}')),
                        DataCell(Text(_fmt(b['checkInDate']))),
                        DataCell(Text(_fmt(b['checkOutDate']))),
                        DataCell(Text('₹${b['balance'] ?? 0}')),
                        DataCell(
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/bill_preview',
                                arguments: {
                                  ...b,
                                  // Show GST invoice only in this flow
                                  'invoiceNo': b['gstInvoiceNo'],
                                  'isViewOnly': true,
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
    );
  }

  Future<void> _downloadFolderPdf(List<Map<String, dynamic>> bills) async {
    if (folderId == null) return;

    setState(() => _downloading = true);

    try {
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
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Image(pw.MemoryImage(logoBytes), height: 90),
                    pw.Spacer(),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Invoice: ${data['gstInvoiceNo'] ?? ''}',
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
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            data['customerName'] ?? '',
                            style: boldStyle,
                          ),
                          pw.Text(
                            'Mob: ${data['phone1'] ?? ''}',
                            style: bodyStyle,
                          ),
                          if ((data['address'] ?? '').toString().trim().isNotEmpty)
                            pw.Text(
                              data['address'].toString().trim(),
                              style: bodyStyle,
                            ),
                          if ((data['customerGst'] ?? data['gstNo'] ?? '')
                              .toString()
                              .trim()
                              .isNotEmpty)
                            pw.Text(
                              'GST: ${(data['customerGst'] ?? data['gstNo']).toString().trim()}',
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
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3),
                    1: pw.FlexColumnWidth(1.5),
                    2: pw.FlexColumnWidth(1.2),
                    3: pw.FlexColumnWidth(1.4),
                    4: pw.FlexColumnWidth(1.4),
                    5: pw.FlexColumnWidth(1.6),
                  },
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: green),
                      children: [
                        _pdfHeaderCell('Description'),
                        _pdfHeaderCell('Price'),
                        _pdfHeaderCell('Qty'),
                        _pdfHeaderCell('GST (%)'),
                        _pdfHeaderCell('GST'),
                        _pdfHeaderCell('Total'),
                      ],
                    ),
                    ...items.map((i) {
                      final qty =
                          int.tryParse(i['qty']?.toString() ?? '') ?? 0;
                      final price =
                          int.tryParse(i['price']?.toString() ?? '') ?? 0;
                      final net = qty * price;
                      final gstPercent =
                          int.tryParse(i['gstPercent']?.toString() ?? '') ?? 5;
                      final gstAmount = i['gstAmount'] != null
                          ? (int.tryParse(i['gstAmount']?.toString() ?? '') ??
                              0)
                          : (net * gstPercent / 100).round();
                      final lineTotal = i['lineTotal'] != null
                          ? (int.tryParse(i['lineTotal']?.toString() ?? '') ??
                              net + gstAmount)
                          : net + gstAmount;
                      return pw.TableRow(
                        children: [
                          _pdfCell(i['name'] ?? ''),
                          _pdfCell('₹$price'),
                          _pdfCell('$qty'),
                          _pdfCell('$gstPercent'),
                          _pdfCell('₹$gstAmount'),
                          _pdfCell('₹$lineTotal'),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 20),
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
                          _pdfTotalRow('GST', data['gst'], bodyStyle),
                          _pdfTotalRow('Total', data['subtotal'], bodyStyle),
                          _pdfTotalRow('Advance', data['advance'], bodyStyle),
                          if ((int.tryParse(
                                      data['discount']?.toString() ?? '') ??
                                  0) >
                              0)
                            _pdfTotalRow(
                              'Discount',
                              data['discount'],
                              bodyStyle,
                            ),
                          pw.Divider(),
                          _pdfTotalRow('Balance', data['balance'], boldStyle),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),
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
        onLayout: (_) async => pdf.save(),
      );

      if (!mounted) return;
      await context.read<GstStore>().markFolderDownloaded(folderId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GST bills downloaded')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return DateFormat('dd/MM/yyyy').format(d);
  }

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
        pw.Text(
          '₹${int.tryParse(value?.toString() ?? '') ?? 0}',
          style: style,
        ),
      ],
    );
  }
}
