import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../history/bill_history_store.dart';
import '../history/confirm_store.dart';
import '../widgets/list_filter_dialog.dart';

class TotalIncomeScreen extends StatefulWidget {
  const TotalIncomeScreen({super.key});

  @override
  State<TotalIncomeScreen> createState() => _TotalIncomeScreenState();
}

class _TotalIncomeScreenState extends State<TotalIncomeScreen> {
  DateTime? _from;
  DateTime? _to;
  String _paymentFilter = 'All';
  bool _showAll = false;
  String _customerName = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _from = today;
    _to = today;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillHistoryStore>();
    final confirmedStore = context.watch<ConfirmStore>();
    final records = _filteredRecords(
      _paymentRecords(store.bills, confirmedStore.confirmedQuotations),
    );
    final total = records.fold<double>(0, (sum, record) => sum + record.amount);
    final advanceTotal = records
        .where((record) => record.type == 'Advance')
        .fold<double>(0, (sum, record) => sum + record.amount);
    final finalBillTotal = records
        .where((record) => record.type == 'Final Bill')
        .fold<double>(0, (sum, record) => sum + record.amount);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Total Income'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilter,
          ),
          IconButton(
            tooltip: 'Download PDF',
            icon: const Icon(Icons.download_outlined),
            onPressed: records.isEmpty ? null : () => _downloadPdf(records),
          ),
        ],
      ),
      body: store.isLoading || confirmedStore.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: records.isEmpty
                      ? _emptyState()
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
                                      headingRowColor:
                                          WidgetStatePropertyAll(
                                        Theme.of(context).primaryColor,
                                      ),
                                      headingTextStyle: const TextStyle(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      dataRowMinHeight: 54,
                                      dataRowMaxHeight: 66,
                                      columns: const [
                                        DataColumn(label: Text('SL #')),
                                        DataColumn(label: Text('Guest Name')),
                                        DataColumn(label: Text('Package Name')),
                                        DataColumn(label: Text('Payment Date')),
                                        DataColumn(label: Text('Payment Type')),
                                        DataColumn(label: Text('Payment Mode')),
                                        DataColumn(
                                          numeric: true,
                                          label: Text('Paid Amount'),
                                        ),
                                        DataColumn(
                                          label: Text('Payment Recorded By'),
                                        ),
                                        DataColumn(label: Text('Bill')),
                                      ],
                                      rows: List.generate(records.length,
                                          (index) {
                                        final record = records[index];
                                        return DataRow(
                                          cells: [
                                            DataCell(Text('${index + 1}')),
                                            DataCell(Text(record.guestName)),
                                            DataCell(Text(record.packageName)),
                                            DataCell(
                                              Text(_formatDate(record.date)),
                                            ),
                                            DataCell(_typeBadge(record.type)),
                                            DataCell(Text(record.mode)),
                                            DataCell(Text(
                                              _currency.format(record.amount),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            )),
                                            DataCell(Text(record.recordedBy)),
                                            DataCell(
                                              record.bill == null
                                                  ? const Text('—')
                                                  : IconButton(
                                                      tooltip: 'View bill',
                                                      icon: const Icon(
                                                        Icons.visibility,
                                                        color: Colors.green,
                                                      ),
                                                      onPressed: () {
                                                        Navigator.pushNamed(
                                                          context,
                                                          '/bill_preview',
                                                          arguments: {
                                                            ...record.bill!,
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
                              ),
                            );
                          },
                        ),
                ),
                _totalBar(total, advanceTotal, finalBillTotal),
              ],
            ),
    );
  }

  Future<void> _openFilter() async {
    final payment = ValueNotifier<String>(_paymentFilter);
    final result = await showListFilterDialog(
      context,
      initial: ListFilterValues(
        customerName: _customerName,
        from: _from,
        to: _to,
      ),
      extra: ValueListenableBuilder<String>(
        valueListenable: payment,
        builder: (_, value, __) {
          return Wrap(
            spacing: 8,
            children: ['All', 'Advance', 'Final Bill'].map((filter) {
              return ChoiceChip(
                label: Text(filter),
                selected: value == filter,
                onSelected: (_) => payment.value = filter,
              );
            }).toList(),
          );
        },
      ),
    );
    final selectedPayment = payment.value;
    payment.dispose();
    if (result == null || !mounted) return;
    setState(() {
      _customerName = result.customerName;
      _from = result.from;
      _to = result.to;
      _paymentFilter = selectedPayment;
      _showAll = _from == null && _to == null && _customerName.isEmpty;
    });
  }

  Widget _typeBadge(String type) {
    final isAdvance = type == 'Advance';
    final color = isAdvance ? const Color(0xffa96600) : const Color(0xff186a52);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)),
      child: Text(type, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: Colors.blueGrey.shade300),
          const SizedBox(height: 12),
          const Text('No payments found for this filter'),
        ]),
      );

  Widget _totalBar(double total, double advance, double finalBill) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: Colors.green,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total Income', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 16)),
            Text(_currency.format(total), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text('Advance: ${_currency.format(advance)}', style: const TextStyle(color: Colors.black))),
            Text('Final Bill: ${_currency.format(finalBill)}', style: const TextStyle(color: Colors.black)),
          ]),
        ]),
      ),
    );
  }

  List<_IncomeRecord> _filteredRecords(List<_IncomeRecord> records) {
    return records.where((record) {
      if (_paymentFilter != 'All' && record.type != _paymentFilter) return false;
      if (_customerName.trim().isNotEmpty) {
        if (!record.guestName.toLowerCase().contains(
              _customerName.trim().toLowerCase(),
            )) {
          return false;
        }
      }
      if (_from != null && record.date.isBefore(DateTime(_from!.year, _from!.month, _from!.day))) return false;
      if (_to != null && record.date.isAfter(DateTime(_to!.year, _to!.month, _to!.day, 23, 59, 59))) return false;
      return true;
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  List<_IncomeRecord> _paymentRecords(
    List<Map<String, dynamic>> bills,
    List<Map<String, dynamic>> confirmedQuotations,
  ) {
    final records = <_IncomeRecord>[];
    final activeConfirmationKeys = <String>{};
    final activeStayKeys = <String>{};

    // Advances are recorded at booking confirmation, before a bill exists.
    // This keeps an advance in the month it was received, even when the stay
    // and bill belong to a later month.
    for (final booking in confirmedQuotations) {
      final advance = _amount(booking['advance']);
      if (advance <= 0) continue;

      final confirmId = booking['confirmId']?.toString();
      final quotationId = booking['originalQuotationId']?.toString();
      if (confirmId != null && confirmId.isNotEmpty) {
        activeConfirmationKeys.add(confirmId);
      }
      if (quotationId != null && quotationId.isNotEmpty) {
        activeConfirmationKeys.add(quotationId);
      }
      final stayKey = _stayKey(booking);
      if (stayKey.isNotEmpty) activeStayKeys.add(stayKey);

      final payments = _advancePayments(
        booking,
        fallbackAmount: advance,
        fallbackDate: _advanceDate(booking) ??
            _dateValue(booking['checkInDate']) ??
            _dateValue(booking['createdAt']),
      );
      records.addAll(payments.map((payment) => _IncomeRecord(
            guestName: (booking['customerName'] ?? '—').toString(),
            packageName: (booking['package'] ?? 'Others').toString(),
            date: payment.date,
            type: 'Advance',
            mode: payment.mode,
            amount: payment.amount,
            recordedBy: payment.recordedBy,
          )));
    }

    for (final bill in bills) {
      final guest = (bill['customerName'] ?? '—').toString();
      final package = (bill['package'] ?? 'Others').toString();
      final billDate = bill['checkOutDate'] is DateTime
          ? bill['checkOutDate'] as DateTime
          : DateTime.now();
      final advance = _amount(bill['advance']);
      final billConfirmId = bill['confirmId']?.toString();
      final billQuotationId = bill['originalQuotationId']?.toString();
      final stayKey = _stayKey(bill);
      final hasActiveConfirmation =
          activeConfirmationKeys.contains(billConfirmId) ||
              activeConfirmationKeys.contains(billQuotationId) ||
              (stayKey.isNotEmpty && activeStayKeys.contains(stayKey));

      // This fallback preserves advances from older bookings whose confirmed
      // record has already been removed after checkout.
      if (advance > 0 && !hasActiveConfirmation) {
        final payments = _advancePayments(
          bill,
          fallbackAmount: advance,
          fallbackDate: _advanceDate(bill) ??
              _dateValue(bill['createdAt']) ??
              billDate,
        );
        records.addAll(payments.map((payment) => _IncomeRecord(
              guestName: guest,
              packageName: package,
              date: payment.date,
              type: 'Advance',
              mode: payment.mode,
              amount: payment.amount,
              recordedBy: payment.recordedBy,
            )));
      }
      final payment = bill['payment'];
      if (payment is Map) {
        final paymentDate = _dateValue(payment['paymentDate']) ??
            _dateValue(payment['updatedAt']) ??
            billDate;
        final recordedBy =
            (payment['paymentRecordedBy'] ?? 'Not recorded').toString();
        const modes = {'gpay': 'GPay', 'cash': 'Cash', 'account': 'Account'};
        modes.forEach((key, label) {
          final amount = _amount(payment[key]);
          if (amount > 0) {
            records.add(_IncomeRecord(
              guestName: guest,
              packageName: package,
              date: paymentDate,
              type: 'Final Bill',
              mode: label,
              amount: amount,
              recordedBy: recordedBy,
              bill: bill,
            ));
          }
        });
      }
    }
    return records;
  }

  String _stayKey(Map<String, dynamic> data) {
    final name =
        (data['customerName'] ?? '').toString().trim().toLowerCase();
    if (name.isEmpty) return '';
    final checkIn = _dateValue(data['checkInDate']);
    final checkOut = _dateValue(data['checkOutDate']);
    String day(DateTime? d) =>
        d == null ? '' : '${d.year}-${d.month}-${d.day}';
    return '$name|${day(checkIn)}|${day(checkOut)}';
  }

  List<_AdvancePayment> _advancePayments(
    Map<String, dynamic> data, {
    required double fallbackAmount,
    required DateTime? fallbackDate,
  }) {
    final savedDate = _advanceDate(data);
    final values = data['advancePayments'];
    if (values is List && values.isNotEmpty) {
      return values.whereType<Map>().map((entry) {
        return _AdvancePayment(
          amount: _amount(entry['amount']),
          mode: (entry['mode'] ?? 'Not recorded').toString(),
          recordedBy: (entry['recordedBy'] ?? 'Admin').toString(),
          date: _dateValue(entry['paidAt']) ??
              _dateValue(entry['recordedDate']) ??
              fallbackDate ??
              DateTime(2000),
        );
      }).where((payment) => payment.amount > 0).toList();
    }
    return [
      _AdvancePayment(
        amount: fallbackAmount,
        mode: (data['advancePaymentMode'] ?? data['advanceMode'] ?? 'Not recorded')
            .toString(),
        recordedBy: (data['advanceRecordedBy'] ?? data['createdBy'] ?? 'Admin')
            .toString(),
        date: savedDate ?? fallbackDate ?? DateTime(2000),
      ),
    ];
  }

  DateTime? _advanceDate(Map<String, dynamic> data) =>
      _dateValue(data['advancePaymentDate']);

  Future<void> _downloadPdf(List<_IncomeRecord> records) async {
    final pdf = pw.Document();
    final total = records.fold<double>(0, (sum, record) => sum + record.amount);
    final advance = records
        .where((record) => record.type == 'Advance')
        .fold<double>(0, (sum, record) => sum + record.amount);
    final finalBill = records
        .where((record) => record.type == 'Final Bill')
        .fold<double>(0, (sum, record) => sum + record.amount);
    final range = _from == null && _to == null
        ? 'All payment dates'
        : '${_from == null ? 'Start' : _formatDate(_from!)} to ${_to == null ? 'Today' : _formatDate(_to!)}';

    pdf.addPage(
      pw.MultiPage(
        build: (_) => [
          pw.Text('Neyyar Heritage - Total Income',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Period: $range'),
          pw.Text('Payment type: $_paymentFilter'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'SL #',
              'Guest',
              'Package',
              'Payment Date',
              'Type',
              'Mode',
              'Paid Amount',
              'Recorded By',
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xffe6eef8)),
            cellStyle: const pw.TextStyle(fontSize: 8),
            data: List.generate(records.length, (index) {
              final record = records[index];
              return [
                '${index + 1}',
                record.guestName,
                record.packageName,
                _formatDate(record.date),
                record.type,
                record.mode,
                'Rs ${record.amount.toStringAsFixed(0)}',
                record.recordedBy,
              ];
            }),
          ),
          pw.SizedBox(height: 16),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Advance: Rs ${advance.toStringAsFixed(0)}'),
                pw.Text('Final Bill: Rs ${finalBill.toStringAsFixed(0)}'),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Total Income: Rs ${total.toStringAsFixed(0)}',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
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

  DateTime? _dateValue(dynamic value) {
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    try {
      final dynamic date = value?.toDate();
      return date is DateTime ? date : null;
    } catch (_) {
      return null;
    }
  }

  double _amount(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  String _formatDate(DateTime date) => DateFormat('dd MMM yyyy').format(date);
  NumberFormat get _currency => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
}

class _IncomeRecord {
  const _IncomeRecord({
    required this.guestName,
    required this.packageName,
    required this.date,
    required this.type,
    required this.mode,
    required this.amount,
    required this.recordedBy,
    this.bill,
  });
  final String guestName;
  final String packageName;
  final DateTime date;
  final String type;
  final String mode;
  final double amount;
  final String recordedBy;
  final Map<String, dynamic>? bill;
}

class _AdvancePayment {
  const _AdvancePayment({
    required this.amount,
    required this.mode,
    required this.recordedBy,
    required this.date,
  });

  final double amount;
  final String mode;
  final String recordedBy;
  final DateTime date;
}
