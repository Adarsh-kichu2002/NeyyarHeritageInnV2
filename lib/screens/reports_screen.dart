import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/screens/money_chart_screen.dart';
import 'package:neyyar_heritage/screens/money_report_screen.dart';
import 'package:provider/provider.dart';

import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sticky_headers/sticky_headers.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../history/bill_history_store.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  DateTime? from;
  DateTime? to;
  bool _showAll = false;
  String customerName = '';

  String selectedPackage = 'All';
  String selectedMonth = 'All';
  String selectedYear = 'All';

  final List<String> packages = [
    'All',
    'Stay',
    'Stay Package',
    'Day Out Package',
    'Others',
  ];

  final List<String> months = [
    'All',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '10',
    '11',
    '12',
  ];

  final List<String> years = [
    'All',
    '2026',
    '2027',
    '2028',
    '2029',
    '2030',
    '2031',
    '2032',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    from = today;
    to = today;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final filteredBills = store.bills.where((bill) {
      final payment = bill['payment'];

      final paidAmount =
          payment != null ? (payment['paidAmount'] ?? 0) : 0;

      /// ONLY PAID BILLS
      if (paidAmount <= 0) {
        return false;
      }

      final DateTime? reportDate = _reportDate(bill);

      if (reportDate == null) {
        return false;
      }

      /// DATE FILTER
      if (from != null &&
          reportDate.isBefore(_startOfDay(from!))) {
        return false;
      }

      if (to != null &&
          reportDate.isAfter(_endOfDay(to!))) {
        return false;
      }

      final nameQuery = customerName.trim().toLowerCase();
      if (nameQuery.isNotEmpty) {
        final name = (bill['customerName'] ?? '').toString().toLowerCase();
        if (!name.contains(nameQuery)) {
          return false;
        }
      }

      /// PACKAGE FILTER
      if (selectedPackage != 'All') {
        final packageName =
            (bill['package'] ?? 'Others').toString();

        if (packageName != selectedPackage) {
          return false;
        }
      }

      /// MONTH FILTER
      if (selectedMonth != 'All') {
        if (reportDate.month !=
            int.parse(selectedMonth)) {
          return false;
        }
      }

      /// YEAR FILTER
      if (selectedYear != 'All') {
        if (reportDate.year !=
            int.parse(selectedYear)) {
          return false;
        }
      }

      return true;
    }).toList();

    final int totalBill = filteredBills.fold(
      0,
      (sum, bill) => sum + _toInt(bill['balance']),
    );

    final int totalAdvance = filteredBills.fold(
      0,
      (sum, bill) => sum + _billAdvance(bill),
    );

    final int totalPaid = filteredBills.fold(
      0,
      (sum, bill) {
        final payment = bill['payment'];

        final paid =
            payment != null ? payment['paidAmount'] : 0;

        return sum + _toInt(paid);
      },
    );

    final int netTotal =
        totalAdvance + totalPaid;

    /// MONTHLY BREAKUP
    Map<String, int> monthlyBreakup = {};

    for (var bill in filteredBills) {
      final date = _reportDate(bill);
      if (date == null) continue;

      final payment = bill['payment'];

      final paid =
          payment != null ? payment['paidAmount'] : 0;

      final monthKey =
          DateFormat('MMMM yyyy').format(date);

      monthlyBreakup[monthKey] =
          (monthlyBreakup[monthKey] ?? 0) +
              _toInt(paid);
    }

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
  title: const Text("Reports"),
  actions: [
    IconButton(
      tooltip: 'Filter',
      icon: const Icon(Icons.filter_list),
      onPressed: _openFilters,
    ),
    PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'money_page') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MoneyReportScreen(),
            ),
          );
        }

        if (value == 'money_chart') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MoneyChartScreen(),
            ),
          );
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'money_page',
          child: Text('Money Page'),
        ),
        const PopupMenuItem(
          value: 'money_chart',
          child: Text('Money Chart'),
        ),
      ],
    ),
  ],
),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: ElevatedButton.icon(
          onPressed: () => _downloadPdf(
            filteredBills,
            totalBill,
            totalAdvance,
            totalPaid,
            netTotal,
            monthlyBreakup,
          ),
          icon: const Icon(Icons.download),
          label: const Text("Download PDF"),
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
                  children: [
                    Expanded(
                      child: _dropdown(
                        selectedPackage,
                        packages,
                        (v) {
                          setState(() {
                            selectedPackage = v ?? 'All';
                          });
                        },
                        hint: 'Package',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dropdown(
                        selectedMonth,
                        months,
                        (v) {
                          setState(() {
                            selectedMonth = v ?? 'All';
                          });
                        },
                        hint: 'Month',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _dropdown(
                        selectedYear,
                        years,
                        (v) {
                          setState(() {
                            selectedYear = v ?? 'All';
                          });
                        },
                        hint: 'Year',
                      ),
                    ),
                  ],
            ),
          ),

          /// TABLE WITH STICKY MONTH HEADER
Expanded(
  child: ListView(
    children: monthlyBreakup.keys.map((monthKey) {
      final monthBills = filteredBills.where((bill) {
        final date = _reportDate(bill);
        if (date == null) return false;

        final billMonth = DateFormat(
          'MMMM yyyy',
        ).format(date);

        return billMonth == monthKey;
      }).toList();

      /// MONTH NET TOTAL
      final int monthAdvance = monthBills.fold(
        0,
        (sum, bill) => sum + _billAdvance(bill),
      );

      final int monthPaid = monthBills.fold(
        0,
        (sum, bill) {
          final payment = bill['payment'];

          final paid = payment != null
              ? payment['paidAmount']
              : 0;

          return sum + _toInt(paid);
        },
      );

      final int monthNetTotal =
          monthAdvance + monthPaid;

      return StickyHeader(
        header: Container(
          height: 50,
          color: Colors.blue,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children: [
              Text(
                monthKey,
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              /// NET TOTAL IN HEADER
              Text(
                '₹$monthNetTotal',
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        content: SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(
                label: Text(
                  "Invoice No",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Date",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Guest Name",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Package",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Advance",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Bill Amount",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  "Paid Amount",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
               DataColumn(
                label: Text(
                  "Total Amount",
                  style: TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],

            rows: monthBills.map((bill) {
  final payment = bill['payment'];

  final int paid = payment != null
      ? _toInt(payment['paidAmount'])
      : 0;

  final int advance =
      _billAdvance(bill);

  final int totalAmount =
      advance + paid;

  return DataRow(
    cells: [

      /// Invoice No
      DataCell(
        Text(
          '${bill['invoiceNo']}',
        ),
      ),

      /// Payment Date
      DataCell(
        Text(
          _fmt(
            _reportDate(bill),
          ),
        ),
      ),

      /// Guest Name
      DataCell(
        Text(
          '${bill['customerName']}',
        ),
      ),

      /// Package
      DataCell(
        Text(
          '${bill['package'] ?? 'Others'}',
        ),
      ),

      /// Advance
      DataCell(
        Text(
          '₹$advance',
        ),
      ),

      /// Bill Amount
      DataCell(
        Text(
          '₹${_toInt(bill['balance'])}',
        ),
      ),

      /// Paid Amount
      DataCell(
        Text(
          '₹$paid',
        ),
      ),

      /// Total Amount
      DataCell(
        Text(
          '₹$totalAmount',
          style: const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}).toList(),
          ),
        ),
      );
    }).toList(),
  ),
),

          /// MONTHLY BREAKUP
          Container(
            color: Colors.grey.shade100,
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [

                _totalRow(
                  "Total Advance",
                  totalAdvance,
                ),

                _totalRow(
                  "Total Bill Amount",
                  totalBill,
                ),

                _totalRow(
                  "Total Paid",
                  totalPaid,
                ),

                _totalRow(
                  "Net Total",
                  netTotal,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(
  List<Map<String, dynamic>> bills,
  int totalBill,
  int totalAdvance,
  int totalPaid,
  int netTotal,
  Map<String, int> monthlyBreakup,
) async {
  try {
    debugPrint("STEP 1: Loading fonts...");

    final fontRegular = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/Roboto-Regular.ttf',
      ),
    );

    final fontBold = pw.Font.ttf(
      await rootBundle.load(
        'assets/fonts/Roboto-Bold.ttf',
      ),
    );

    debugPrint("STEP 2: Fonts loaded");

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (context) {
          return [
            pw.Text(
              "Neyyar Heritage Reports",
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Table.fromTextArray(
  headers: [
    'Invoice',
    'Date',
    'Guest',
    'Package',
    'Advance',
    'Bill',
    'Paid',
    'Total',
  ],
  headerStyle: pw.TextStyle(
    fontWeight: pw.FontWeight.bold,
    fontSize: 9,
  ),
  cellStyle: const pw.TextStyle(
    fontSize: 8,
  ),
  columnWidths: {
    0: const pw.FlexColumnWidth(1.2),
    1: const pw.FlexColumnWidth(1.5),
    2: const pw.FlexColumnWidth(2),
    3: const pw.FlexColumnWidth(2),
    4: const pw.FlexColumnWidth(1.2),
    5: const pw.FlexColumnWidth(1.2),
    6: const pw.FlexColumnWidth(1.2),
    7: const pw.FlexColumnWidth(1.2),
  },
  data: bills.map((bill) {
    final payment = bill['payment'];

    final int paid = payment != null
        ? _toInt(payment['paidAmount'])
        : 0;

    final int advance =
        _billAdvance(bill);

    final int billAmount =
        _toInt(bill['balance']);

    final int totalAmount =
        advance + paid;

    return [
      '${bill['invoiceNo']}',
      _fmt(
        _reportDate(bill),
      ),
      '${bill['customerName']}',
      '${bill['package'] ?? 'Others'}',
      'Rs $advance',
      'Rs $billAmount',
      'Rs $paid',
      'Rs $totalAmount',
    ];
  }).toList(),
),

            pw.SizedBox(height: 20),

            ...monthlyBreakup.entries.map(
              (e) => pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(e.key),
                  pw.Text("Rs ${e.value}"),
                ],
              ),
            ),

            pw.Divider(),

            pw.Text("Total Advance : Rs $totalAdvance"),
            pw.Text("Total Bill : Rs $totalBill"),
            pw.Text("Total Paid : Rs $totalPaid"),
            pw.Text("Net Total : Rs $netTotal"),
          ];
        },
      ),
    );

    debugPrint("STEP 3: PDF created");

    /// OPEN PDF FIRST
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
    );

    debugPrint("STEP 4: PDF opened");

    /// SAVE TEMP FILE
    final dir =
        await getTemporaryDirectory();

    final file = File(
      '${dir.path}/report.pdf',
    );

    await file.writeAsBytes(
      await pdf.save(),
    );

    debugPrint("STEP 5: File saved");

    /// FIREBASE STORAGE
    final ref =
        FirebaseStorage.instance
            .ref()
            .child(
              'reports/report_${DateTime.now().millisecondsSinceEpoch}.pdf',
            );

    await ref.putFile(file);

    final url =
        await ref.getDownloadURL();

    debugPrint("STEP 6: Uploaded");

    await _db.collection('reports').add({
      'pdfUrl': url,
      'createdAt':
          FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Report created successfully",
        ),
      ),
    );
  } catch (e, stack) {
    debugPrint("PDF ERROR = $e");
    debugPrint("$stack");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "PDF Error: $e",
        ),
      ),
    );
  }
}

  Future<void> _openFilters() async {
    var dialogName = customerName;
    var dialogFrom = from;
    var dialogTo = to;
    final nameController = TextEditingController(text: dialogName);

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Filter'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _dateBox(
                          'From',
                          dialogFrom,
                          (d) {
                            setDialogState(() {
                              dialogFrom = d;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _dateBox(
                          'To',
                          dialogTo,
                          (d) {
                            setDialogState(() {
                              dialogTo = d;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogName = '';
                    dialogFrom = null;
                    dialogTo = null;
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    dialogName = nameController.text.trim();
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    if (applied != true || !mounted) return;

    setState(() {
      customerName = dialogName;
      from = dialogFrom;
      to = dialogTo;
      _showAll = from == null && to == null && customerName.isEmpty;
    });
  }

  Widget _dropdown(
  String value,
  List<String> list,
  Function(String?) onChanged, {
  String? hint,
}) {
  final visibleItems = list.where((e) => e != 'All').toList();
  final selected = value == 'All' ? null : value;
  return DropdownButtonFormField<String>(
    isExpanded: true, // ✅ FIX
    value: selected,
    hint: Text(hint ?? 'Select'),
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
    ),
    items: visibleItems.map((e) {
      return DropdownMenuItem<String>(
        value: e,
        child: Text(
          e,
          overflow: TextOverflow.ellipsis, // ✅ FIX
          maxLines: 1,
        ),
      );
    }).toList(),
    onChanged: onChanged,
  );
}

  Widget _dateBox(
    String label,
    DateTime? value,
    Function(DateTime) onPick,
  ) {
    return OutlinedButton(
      onPressed: () async {

        final d =
            await showDatePicker(
          context: context,
          firstDate:
              DateTime(2020),
          lastDate:
              DateTime(2100),
          initialDate:
              value ??
                  DateTime.now(),
        );

        if (d != null) {
          onPick(d);
        }
      },
      child: Text(
        value == null
            ? label
            : DateFormat(
                'dd/MM/yyyy',
              ).format(value),
      ),
    );
  }

  Widget _totalRow(
    String label,
    int amount,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,
      children: [

        Text(
          label,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        Text(
          '₹$amount',
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _fmt(
    DateTime? d,
  ) {
    if (d == null) {
      return '';
    }

    return DateFormat(
      'dd/MM/yyyy',
    ).format(d);
  }

  DateTime? _reportDate(Map<String, dynamic> bill) {
    final payment = bill['payment'];
    if (payment is Map) {
      final paymentDate = _dateValue(payment['paymentDate']) ??
          _dateValue(payment['updatedAt']);
      if (paymentDate != null) return paymentDate;
    }
    return _dateValue(bill['checkOutDate']);
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

  int _billAdvance(Map<String, dynamic> bill) {
    final direct = _toInt(bill['advance']);
    if (direct > 0) return direct;

    final payments = bill['advancePayments'];
    if (payments is List) {
      var total = 0;
      for (final entry in payments) {
        if (entry is Map) {
          total += _toInt(entry['amount']);
        }
      }
      if (total > 0) return total;
    }

    final subtotal = _toInt(bill['subtotal']);
    final discount = _toInt(bill['discount']);
    final balance = _toInt(bill['balance']);
    // subtotal already includes GST on new bills
    final implied = subtotal - discount - balance;
    if (implied > 0) return implied;

    return 0;
  }

  int _toInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.round();
    return int.tryParse(value.toString()) ?? fallback;
  }

  DateTime _startOfDay(
    DateTime d,
  ) {
    return DateTime(
      d.year,
      d.month,
      d.day,
    );
  }

  DateTime _endOfDay(
    DateTime d,
  ) {
    return DateTime(
      d.year,
      d.month,
      d.day,
      23,
      59,
      59,
    );
  }
}
