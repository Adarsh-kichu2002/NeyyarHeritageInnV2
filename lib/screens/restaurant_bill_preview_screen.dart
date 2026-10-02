import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../services/restaurant_bill_service.dart';

/// Restaurant bill preview — same visual language as Homestay preview,
/// but no GST column, no GST summary, no Advance.
class RestaurantBillPreviewScreen extends StatefulWidget {
  const RestaurantBillPreviewScreen({super.key});

  @override
  State<RestaurantBillPreviewScreen> createState() =>
      _RestaurantBillPreviewScreenState();
}

class _RestaurantBillPreviewScreenState
    extends State<RestaurantBillPreviewScreen> {
  final Color green = const Color.fromARGB(255, 52, 191, 59);

  bool _saving = false;
  bool _savedInThisSession = false;
  bool _initialized = false;
  bool _billNumberReady = false;
  late Map<String, dynamic> data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    data = args is Map<String, dynamic>
        ? Map<String, dynamic>.from(args)
        : <String, dynamic>{};

    final isViewOnly = data['isViewOnly'] == true;
    if (isViewOnly || data['billNumber'] != null) {
      _billNumberReady = true;
    } else {
      _loadBillNumber();
    }
  }

  Future<void> _loadBillNumber() async {
    try {
      final next = await context.read<RestaurantBillStore>().nextBillNumber();
      if (!mounted) return;
      setState(() {
        data['billNumber'] = next;
        _billNumberReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        data['billNumber'] = 1;
        _billNumberReady = true;
      });
    }
  }

  Future<void> _ensureBillNumber() async {
    if (data['billNumber'] != null) return;
    final next = await context.read<RestaurantBillStore>().nextBillNumber();
    data['billNumber'] = next;
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  String _money(dynamic v) {
    final n = _toDouble(v);
    return n % 1 == 0 ? n.toInt().toString() : n.toStringAsFixed(2);
  }

  double get _itemsTotal {
    if (data['itemsTotal'] != null) return _toDouble(data['itemsTotal']);
    final items = data['items'] as List? ?? [];
    return items.fold<double>(0, (sum, raw) {
      final i = Map<String, dynamic>.from(raw as Map);
      return sum + _toDouble(i['total']);
    });
  }

  double get _discount => _toDouble(data['discount']);

  double get _grandTotal {
    if (data['grandTotal'] != null) return _toDouble(data['grandTotal']);
    final total = _itemsTotal - _discount;
    return total < 0 ? 0 : total;
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || data.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No restaurant bill data')),
      );
    }

    final isViewOnly = data['isViewOnly'] == true;

    if (!_billNumberReady && !isViewOnly) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Bill Preview')),
      bottomNavigationBar: _actions(isViewOnly),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'RECEIPT',
                style: TextStyle(
                  color: green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _partyInfo(),
            const SizedBox(height: 16),
            _itemsTable(),
            const SizedBox(height: 16),
            _summary(),
            const SizedBox(height: 16),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final date = data['createdAt'] is DateTime
        ? data['createdAt'] as DateTime
        : DateTime.now();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Image.asset(
            'assets/images/neyyar_restaurant_logo.png',
            height: 90,
            fit: BoxFit.contain,
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Invoice: ${data['billNumber'] ?? '...'}',
              style: TextStyle(color: green, fontWeight: FontWeight.bold),
            ),
            Text(
              'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
              style: TextStyle(color: green),
            ),
          ],
        ),
      ],
    );
  }

  Widget _partyInfo() {
    final gst = (data['gstNumber'] ?? '').toString().trim();
    final address = (data['address'] ?? '').toString().trim();
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['customerName'] ?? '',
            textAlign: TextAlign.left,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Mob: ${data['phoneNumber'] ?? ''}', textAlign: TextAlign.left),
          if (address.isNotEmpty) Text(address, textAlign: TextAlign.left),
          if (gst.isNotEmpty) Text('GST: $gst', textAlign: TextAlign.left),
        ],
      ),
    );
  }

  Widget _itemsTable() {
    final items = data['items'] as List? ?? [];
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.6),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: green),
          children: const [
            _HeaderCell('Item'),
            _HeaderCell('Qty'),
            _HeaderCell('Price'),
            _HeaderCell('Total'),
          ],
        ),
        ...items.map((raw) {
          final i = Map<String, dynamic>.from(raw as Map);
          return TableRow(
            children: [
              _Cell('${i['itemName'] ?? ''}'),
              _Cell('${i['quantity'] ?? 0}'),
              _Cell('₹${_money(i['price'])}'),
              _Cell('₹${_money(i['total'])}'),
            ],
          );
        }),
      ],
    );
  }

  Widget _summary() {
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
              _totalRow('Items Total', _itemsTotal),
              if (_discount > 0) _totalRow('Discount', _discount),
              const Divider(),
              _totalRow('Grand Total', _grandTotal, bold: true),
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
        Text('₹${_money(value)}',
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
            child: Text('9656763391', style: TextStyle(color: Colors.white)),
          ),
          Expanded(
            child: Text(
              'neyyarheritageinn@gmail.com',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
          Expanded(
            child: Text(
              'www.neyyarheritage.in',
              textAlign: TextAlign.end,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(bool isViewOnly) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: Icon(
            (isViewOnly || _savedInThisSession)
                ? Icons.check_circle
                : Icons.save,
          ),
          label: Text(
            isViewOnly || _savedInThisSession
                ? (isViewOnly ? 'Download' : 'Saved')
                : (_saving ? 'Saving...' : 'Save & Download'),
          ),
          onPressed: _saving
              ? null
              : () async {
                  if (isViewOnly) {
                    await _downloadPdf();
                    return;
                  }
                  if (_savedInThisSession) return;

                  setState(() => _saving = true);
                  try {
                    await _ensureBillNumber();
                    final billId = data['billId'] ??
                        DateTime.now().millisecondsSinceEpoch.toString();
                    data['billId'] = billId;
                    data['itemsTotal'] = _itemsTotal;
                    data['discount'] = _discount;
                    data['grandTotal'] = _grandTotal;

                    await context.read<RestaurantBillStore>().saveBill(data);
                    await _downloadPdf();

                    if (!mounted) return;
                    setState(() {
                      _saving = false;
                      _savedInThisSession = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Restaurant bill saved successfully'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    setState(() => _saving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not save: $e')),
                    );
                  }
                },
        ),
      ),
    );
  }

  Future<void> _downloadPdf() async {
    final pdf = pw.Document();
    final fontRegular =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final fontBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    final logoData = await rootBundle.load('assets/images/neyyar_restaurant_logo.png');
    final logo = pw.MemoryImage(logoData.buffer.asUint8List());
    final pdfGreen = PdfColor.fromInt(0xFF34BF3B);
    final items = data['items'] as List? ?? [];
    final date = data['createdAt'] is DateTime
        ? data['createdAt'] as DateTime
        : DateTime.now();
    final gst = (data['gstNumber'] ?? '').toString().trim();
    final address = (data['address'] ?? '').toString().trim();

    pdf.addPage(
      pw.MultiPage(
        build: (ctx) {
          return [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Image(logo, height: 70),
                pw.Spacer(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Invoice: ${data['billNumber']}',
                      style: pw.TextStyle(
                        color: pdfGreen,
                        fontWeight: pw.FontWeight.bold,
                        font: fontBold,
                      ),
                    ),
                    pw.Text(
                      'Date: ${DateFormat('dd/MM/yyyy').format(date)}',
                      style: pw.TextStyle(color: pdfGreen, font: fontRegular),
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
                  color: pdfGreen,
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                  font: fontBold,
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Align(
              alignment: pw.Alignment.centerLeft,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '${data['customerName'] ?? ''}',
                    style: pw.TextStyle(font: fontBold),
                  ),
                  pw.Text('Mob: ${data['phoneNumber'] ?? ''}',
                      style: pw.TextStyle(font: fontRegular)),
                  if (address.isNotEmpty)
                    pw.Text(address, style: pw.TextStyle(font: fontRegular)),
                  if (gst.isNotEmpty)
                    pw.Text('GST: $gst', style: pw.TextStyle(font: fontRegular)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1.2),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: pdfGreen),
                  children: [
                    _pdfHeader('Item', fontBold),
                    _pdfHeader('Qty', fontBold),
                    _pdfHeader('Price', fontBold),
                    _pdfHeader('Total', fontBold),
                  ],
                ),
                ...items.map((raw) {
                  final i = Map<String, dynamic>.from(raw as Map);
                  return pw.TableRow(
                    children: [
                      _pdfCell('${i['itemName']}', fontRegular),
                      _pdfCell('${i['quantity']}', fontRegular),
                      _pdfCell('₹${_money(i['price'])}', fontRegular),
                      _pdfCell('₹${_money(i['total'])}', fontRegular),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  flex: 3,
                  child: pw.Text(
                    'Thank you for choosing us.\n'
                    'We look forward to hosting you again.\n'
                    'Best Regards,\nNeyyar Heritage Inn.',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11),
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      _pdfTotalRow(
                          'Items Total', _itemsTotal, fontRegular, false),
                      if (_discount > 0)
                        _pdfTotalRow(
                            'Discount', _discount, fontRegular, false),
                      pw.Divider(),
                      _pdfTotalRow(
                          'Grand Total', _grandTotal, fontBold, true),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Container(
              color: pdfGreen,
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '9656763391',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        font: fontRegular,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'neyyarheritageinn@gmail.com',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        font: fontRegular,
                        fontSize: 9,
                      ),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      'www.neyyarheritage.in',
                      textAlign: pw.TextAlign.right,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        font: fontRegular,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }

  pw.Widget _pdfTotalRow(
    String label,
    double value,
    pw.Font font,
    bool bold,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
        pw.Text(
          '₹${_money(value)}',
          style: pw.TextStyle(font: font, fontSize: 11),
        ),
      ],
    );
  }

  pw.Widget _pdfHeader(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text,
            style: pw.TextStyle(font: font, color: PdfColors.white)),
      );

  pw.Widget _pdfCell(String text, pw.Font font) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 11)),
      );
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Text(text),
    );
  }
}
