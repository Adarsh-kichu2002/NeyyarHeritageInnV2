import 'dart:math' as math;

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

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? fallback;
  }

  int _displayAdvance(Map<String, dynamic> data) {
    final direct = _toInt(data['advance']);
    if (direct > 0) return direct;

    final payments = data['advancePayments'];
    if (payments is List) {
      var total = 0;
      for (final entry in payments) {
        if (entry is Map) {
          total += _toInt(entry['amount']);
        }
      }
      if (total > 0) return total;
    }

    final subtotal = _toInt(data['subtotal']);
    final discount = _toInt(data['discount']);
    final balance = _toInt(data['balance']);
    // Legacy bills: subtotal was pre-discount (incl. GST).
    final implied = subtotal - discount - balance;
    return implied > 0 ? implied : 0;
  }

  /// Discount reduces taxable amounts before GST.
  /// Allocation order: highest GST % first (display order unchanged).
  _BillTotals _computeBillTotals(Map<String, dynamic> data) {
    final rawItems = data['items'] as List? ?? const [];
    final discountRequested = math.max(0, _toInt(data['discount']));
    final advance = _displayAdvance(data);

    final working = <_BillLineWork>[];
    for (var i = 0; i < rawItems.length; i++) {
      final item = rawItems[i];
      if (item is! Map) continue;
      final qty = _toInt(item['qty']);
      final price = _toInt(item['price']);
      final taxable = math.max(0, qty * price);
      final gstPercent = _toInt(item['gstPercent'], 5);
      working.add(
        _BillLineWork(
          index: i,
          name: '${item['name'] ?? ''}',
          qty: qty,
          price: price,
          taxable: taxable,
          gstPercent: gstPercent,
        ),
      );
    }

    // Cap discount so it never exceeds total taxable.
    final totalTaxable =
        working.fold<int>(0, (sum, line) => sum + line.taxable);
    var remainingDiscount = math.min(discountRequested, totalTaxable);

    final discountByIndex = List<int>.filled(working.length, 0);

    // Sort only for allocation — highest GST first, original index as tie-break.
    final allocationOrder = List<_BillLineWork>.from(working)
      ..sort((a, b) {
        final byGst = b.gstPercent.compareTo(a.gstPercent);
        if (byGst != 0) return byGst;
        return a.index.compareTo(b.index);
      });

    for (final line in allocationOrder) {
      if (remainingDiscount <= 0) break;
      final take = math.min(line.taxable, remainingDiscount);
      discountByIndex[line.index] = take;
      remainingDiscount -= take;
    }

    final lines = <_BillLineResult>[];
    var gstTotal = 0;
    var subtotal = 0;
    var discountApplied = 0;

    for (final line in working) {
      final allocated = discountByIndex[line.index];
      final discountedTaxable = line.taxable - allocated;
      // GST % unchanged; only the taxable base is reduced.
      final gstAmount = (discountedTaxable * line.gstPercent / 100).round();
      final lineTotal = discountedTaxable + gstAmount;
      discountApplied += allocated;
      gstTotal += gstAmount;
      subtotal += lineTotal;
      lines.add(
        _BillLineResult(
          name: line.name,
          qty: line.qty,
          price: line.price,
          gstPercent: line.gstPercent,
          taxable: line.taxable,
          discountAllocated: allocated,
          discountedTaxable: discountedTaxable,
          gstAmount: gstAmount,
          lineTotal: lineTotal,
        ),
      );
    }

    // Discount already baked into taxable/GST — do not subtract it again.
    final balance = math.max(0, subtotal - advance);

    return _BillTotals(
      lines: lines,
      gst: gstTotal,
      subtotal: subtotal,
      discount: discountApplied,
      discountRequested: discountRequested,
      advance: advance,
      balance: balance,
    );
  }

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
    final totals = _computeBillTotals(data);

    return Scaffold(
      appBar: AppBar(title: const Text('Bill Preview')),
      bottomNavigationBar: _actions(context, data, totals),
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
            _itemsTable(totals),
            const SizedBox(height: 16),
            _summaryWithNotes(totals),
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
            Text('GST NO: 32BUMPR0206G1ZX', style: TextStyle(color: green))
          ],
        ),
      ],
    );
  }

  Widget _receiptTitle() => Text(
        'RECEIPT',
        style:
            TextStyle(color: green, fontSize: 20, fontWeight: FontWeight.bold),
      );

  Widget _partyInfo(Map<String, dynamic> data) {
    final address = (data['address'] ?? '').toString().trim();
    final customerGst =
        (data['customerGst'] ?? data['gstNo'] ?? '').toString().trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['customerName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Mob: ${data['phone1'] ?? ''}'),
                if (address.isNotEmpty) Text(address),
                if (customerGst.isNotEmpty) Text('GST: $customerGst'),
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

  Widget _itemsTable(_BillTotals totals) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.4),
        // 4: FlexColumnWidth(1.4), // GST amount
        4: FlexColumnWidth(1.6),
      },
      children: [
        TableRow(
          decoration: BoxDecoration(color: green),
          children: const [
            _HeaderCell('Description'),
            _HeaderCell('Price'),
            _HeaderCell('Qty'),
            _HeaderCell('GST (%)'),
            // _HeaderCell('GST'),
            _HeaderCell('Total'),
          ],
        ),
        ...totals.lines.map((line) {
          return TableRow(
            children: [
              _Cell(line.name),
              _Cell('₹${line.price}'),
              _Cell('${line.qty}'),
              _Cell('${line.gstPercent}'),
              // _Cell('₹${line.gstAmount}'),
              _Cell('₹${line.lineTotal}'),
            ],
          );
        }),
      ],
    );
  }

  Widget _summaryWithNotes(_BillTotals totals) {
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
              // _totalRow('GST', totals.gst),
              _totalRow('Total', totals.subtotal),
              _totalRow('Advance', totals.advance),
              if (totals.discountRequested > 0)
                _totalRow('Discount', totals.discountRequested),
              const Divider(),
              _totalRow('Balance', totals.balance, bold: true),
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

  Widget _actions(
    BuildContext context,
    Map<String, dynamic> data,
    _BillTotals totals,
  ) {
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
                        : (_saving ? 'Saving...' : 'Save & Download'),
              ),
              onPressed: (isViewOnly || _saving || _savedInThisSession)
                  ? null
                  : () async {
                      setState(() {
                        _saving = true;
                      });

                      final billId = data['billId'] ??
                          DateTime.now().millisecondsSinceEpoch.toString();

                      final cleanItems = totals.lines
                          .map<Map<String, dynamic>>(
                            (line) => {
                              'name': line.name,
                              'qty': line.qty,
                              'price': line.price,
                              'gstPercent': line.gstPercent,
                              'gstAmount': line.gstAmount,
                              'lineTotal': line.lineTotal,
                            },
                          )
                          .toList();

                      final finalData = {
                        ...data,
                        'billId': billId,
                        'items': cleanItems,
                        'gst': totals.gst,
                        'subtotal': totals.subtotal,
                        'discount': totals.discountRequested,
                        'advance': totals.advance,
                        'balance': totals.balance,
                      };

                      try {
                        await context
                            .read<BillHistoryStore>()
                            .addOrUpdateBill(finalData);

                        final confirmId = data['confirmId'];

                        if (confirmId != null) {
                          await context.read<ConfirmStore>().markBillGenerated(
                                confirmId: confirmId,
                                billId: billId,
                              );
                        }

                        if (!mounted) return;

                        await _downloadPdf(finalData, totals);

                        setState(() {
                          _saving = false;
                          _savedInThisSession = true;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Bill saved successfully'),
                          ),
                        );
                      } catch (e) {
                        if (!mounted) return;

                        setState(() {
                          _saving = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(
    Map<String, dynamic> data,
    _BillTotals totals,
  ) async {
    final fontRegular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    final fontBold =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));

    final logoBytes =
        (await rootBundle.load('assets/images/neyyar_logo.png'))
            .buffer
            .asUint8List();

    final pdf = pw.Document();

    final green =
        PdfColor.fromInt(const Color.fromARGB(255, 52, 191, 59).value);

    pw.TextStyle body = const pw.TextStyle(fontSize: 12, height: 1.4);
    pw.TextStyle bold = pw.TextStyle(
        fontSize: 12, fontWeight: pw.FontWeight.bold, height: 1.4);

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
                      style: pw.TextStyle(color: green, fontSize: 12)),
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
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(data['customerName'] ?? '', style: bold),
                    pw.Text('Mob: ${data['phone1'] ?? ''}', style: body),
                    if ((data['address'] ?? '').toString().trim().isNotEmpty)
                      pw.Text(data['address'].toString().trim(), style: body),
                    if ((data['customerGst'] ?? data['gstNo'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty)
                      pw.Text(
                        'GST: ${(data['customerGst'] ?? data['gstNo']).toString().trim()}',
                        style: body,
                      ),
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
              1: pw.FlexColumnWidth(1.5),
              2: pw.FlexColumnWidth(1.2),
              3: pw.FlexColumnWidth(1.4),
              // 4: pw.FlexColumnWidth(1.4), // GST amount
              4: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(
                decoration: pw.BoxDecoration(color: green),
                children: [
                  _pdfHeaderCell('Description'),
                  _pdfHeaderCell('Price'),
                  _pdfHeaderCell('Qty'),
                  _pdfHeaderCell('GST (%)'),
                  // _pdfHeaderCell('GST'),
                  _pdfHeaderCell('Total'),
                ],
              ),
              ...totals.lines.map((line) {
                return pw.TableRow(
                  children: [
                    _pdfCell(line.name),
                    _pdfCell('₹${line.price}'),
                    _pdfCell('${line.qty}'),
                    _pdfCell('${line.gstPercent}'),
                    // _pdfCell('₹${line.gstAmount}'),
                    _pdfCell('₹${line.lineTotal}'),
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
                    // _pdfTotalRow('GST', totals.gst, body),
                    _pdfTotalRow('Total', totals.subtotal, body),
                    _pdfTotalRow('Advance', totals.advance, body),
                    if (totals.discountRequested > 0)
                      _pdfTotalRow(
                          'Discount', totals.discountRequested, body),
                    pw.Divider(),
                    _pdfTotalRow('Balance', totals.balance, bold),
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

class _BillLineWork {
  const _BillLineWork({
    required this.index,
    required this.name,
    required this.qty,
    required this.price,
    required this.taxable,
    required this.gstPercent,
  });

  final int index;
  final String name;
  final int qty;
  final int price;
  final int taxable;
  final int gstPercent;
}

class _BillLineResult {
  const _BillLineResult({
    required this.name,
    required this.qty,
    required this.price,
    required this.gstPercent,
    required this.taxable,
    required this.discountAllocated,
    required this.discountedTaxable,
    required this.gstAmount,
    required this.lineTotal,
  });

  final String name;
  final int qty;
  final int price;
  final int gstPercent;
  final int taxable;
  final int discountAllocated;
  final int discountedTaxable;
  final int gstAmount;
  final int lineTotal;
}

class _BillTotals {
  const _BillTotals({
    required this.lines,
    required this.gst,
    required this.subtotal,
    required this.discount,
    required this.discountRequested,
    required this.advance,
    required this.balance,
  });

  final List<_BillLineResult> lines;
  final int gst;
  final int subtotal;
  final int discount;
  final int discountRequested;
  final int advance;
  final int balance;
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
