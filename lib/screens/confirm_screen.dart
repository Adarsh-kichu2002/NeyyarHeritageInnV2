import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/bill_history_store.dart';
import 'package:neyyar_heritage/history/confirm_store.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Future<void> _callNumber(String phone) async {
    final number = phone.trim();
    if (number.isEmpty) return;

    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: number),
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        _showDialerUnavailable();
      }
    } catch (_) {
      if (mounted) _showDialerUnavailable();
    }
  }

  void _showDialerUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Unable to open phone dialer')),
    );
  }

  Future<void> _copyNumber(String phone) async {
    final number = phone.trim();
    if (number.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied: $number'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _dayKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isPastDay(DateTime day) {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    return day.isBefore(yesterday);
  }

  Map<String, bool> _markedDates(List<Map<String, dynamic>> quotations) {
    final marked = <String, bool>{};

    for (final q in quotations) {
      final checkIn = q['checkInDate'];
      final checkOut = q['checkOutDate'];
      if (checkIn is! DateTime) continue;

      final start = _dateOnly(checkIn);
      final end = checkOut is DateTime ? _dateOnly(checkOut) : start;

      for (var d = start;
          !d.isAfter(end);
          d = d.add(const Duration(days: 1))) {
        marked[_dayKey(d)] = true;
      }
    }

    return marked;
  }

  List<Map<String, dynamic>> _quotationsForDay(
    List<Map<String, dynamic>> quotations,
    DateTime day,
  ) {
    final selected = _dateOnly(day);

    return quotations.where((q) {
      final checkIn = q['checkInDate'];
      final checkOut = q['checkOutDate'];
      if (checkIn is! DateTime) return false;

      final start = _dateOnly(checkIn);
      final end = checkOut is DateTime ? _dateOnly(checkOut) : start;

      return !selected.isBefore(start) && !selected.isAfter(end);
    }).toList();
  }

  int _totalPaxForDay(List<Map<String, dynamic>> dayQuotations) {
    return dayQuotations.fold<int>(0, (sum, q) {
      final pax = q['totalPax'];
      if (pax is int) return sum + pax;
      return sum + (int.tryParse(pax?.toString() ?? '') ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConfirmStore>();
    final billStore = context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final quotations = store.confirmedQuotations;
    final markedDates = _markedDates(quotations);

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmed Quotations')),
      body: _selectedDay == null
          ? _buildCalendar(markedDates)
          : _buildDayDisplay(
              _quotationsForDay(quotations, _selectedDay!),
              billStore.bills,
            ),
    );
  }

  Widget _buildCalendar(Map<String, bool> markedDates) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    return TableCalendar(
      firstDay: todayOnly,
      lastDay: DateTime(2100),
      focusedDay: _focusedDay,
      enabledDayPredicate: (day) => !_isPastDay(day),
      onDaySelected: (selectedDay, focusedDay) {
        if (_isPastDay(selectedDay)) return;
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarBuilders: CalendarBuilders(
        todayBuilder: (context, day, focusedDay) {
          final id = _dayKey(day);
          if (markedDates.containsKey(id)) {
            return _redDay(day);
          }
          return Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.blue.shade200,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '${day.day}',
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
        defaultBuilder: (context, day, focusedDay) {
          final id = _dayKey(day);
          if (markedDates.containsKey(id)) {
            return _redDay(day);
          }
          return null;
        },
      ),
    );
  }

  Widget _redDay(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildDayDisplay(
    List<Map<String, dynamic>> dayQuotations,
    List<Map<String, dynamic>> bills,
  ) {
    final dateText = DateFormat('dd MMM yyyy').format(_selectedDay!);
    final totalPax = _totalPaxForDay(dayQuotations);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            dateText,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: dayQuotations.isEmpty
              ? const Center(child: Text('No Confirmed Quotations'))
              : ListView.builder(
                  itemCount: dayQuotations.length,
                  itemBuilder: (context, index) {
                    final q = dayQuotations[index];
                    return _bookingBox(q, bills);
                  },
                ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.grey.shade200,
          child: Column(
            children: [
              Text(
                'Total Pax: $totalPax',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () {
                  setState(() => _selectedDay = null);
                },
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bookingBox(
    Map<String, dynamic> q,
    List<Map<String, dynamic>> bills,
  ) {
    final billId = _generatedBillId(q, bills);
    final billGenerated = billId != null;
    final checkIn = _asDate(q['checkInDate']);
    final checkOut = _asDate(q['checkOutDate']);
    final advance = double.tryParse('${q['advance'] ?? 0}') ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q['customerName'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(q['package'] ?? ''),
                    const SizedBox(height: 4),
                    Text(
                      'Check In: ${checkIn != null ? DateFormat('dd/MM/yyyy').format(checkIn) : ''}',
                    ),
                    Text(
                      'Check Out: ${checkOut != null ? DateFormat('dd/MM/yyyy').format(checkOut) : ''}',
                    ),
                    Text('Total Pax: ${q['totalPax'] ?? 0}'),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  InkWell(
                    onTap: advance < 1
                        ? null
                        : () => _editAdvanceDetails(context, q),
                    child: Text(
                      'Advance: ₹${q['advance'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            _copyNumber((q['phone1'] ?? '').toString()),
                        child: Text(q['phone1'] ?? ''),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.phone,
                          color: Colors.green,
                          size: 20,
                        ),
                        tooltip: 'Call',
                        onPressed: () =>
                            _callNumber((q['phone1'] ?? '').toString()),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.visibility, color: Colors.green),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/quotation_preview_screen',
                    arguments: q,
                  );
                },
              ),
              IconButton(
                tooltip: billGenerated
                    ? 'Bill Already Generated'
                    : 'Generate Bill',
                icon: Icon(
                  Icons.receipt_long,
                  color: billGenerated ? Colors.grey : Colors.orange,
                ),
                onPressed: billGenerated
                    ? null
                    : () {
                        final latestBillId = _generatedBillId(
                          q,
                          context.read<BillHistoryStore>().bills,
                        );

                        if (latestBillId != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Bill already generated for this customer',
                              ),
                            ),
                          );
                          return;
                        }

                        Navigator.pushNamed(
                          context,
                          '/bill_screen',
                          arguments: q,
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _editAdvanceDetails(
    BuildContext context,
    Map<String, dynamic> quotation,
  ) async {
    final existingAdvance =
        double.tryParse('${quotation['advance'] ?? 0}') ?? 0;
    final amountController = TextEditingController(
      text: existingAdvance > 0 ? existingAdvance.round().toString() : '',
    );
    final recordedByController = TextEditingController(
      text: (quotation['advanceRecordedBy'] ?? '').toString(),
    );

    const modes = ['GPay', 'Account', 'Cash'];
    final existingMode = quotation['advancePaymentMode']?.toString();
    String mode = modes.contains(existingMode) ? existingMode! : 'GPay';

    DateTime paidAt = DateTime.now();
    final existingDate = quotation['advancePaymentDate'];
    if (existingDate is DateTime) {
      paidAt = existingDate;
    } else {
      final payments = quotation['advancePayments'];
      if (payments is List && payments.isNotEmpty) {
        final first = payments.first;
        if (first is Map) {
          final paid = first['paidAt'];
          if (paid is DateTime) {
            paidAt = paid;
          } else {
            try {
              final dynamic date = paid?.toDate();
              if (date is DateTime) paidAt = date;
            } catch (_) {}
          }
        }
      }
    }

    String? error;
    Map<String, dynamic>? result;
    try {
      result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Edit advance payment'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Advance amount *',
                      prefixText: '₹ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: mode,
                    decoration: const InputDecoration(
                      labelText: 'Payment mode *',
                      border: OutlineInputBorder(),
                    ),
                    items: modes
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => mode = value ?? mode),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: recordedByController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Recorded by *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Payment date',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(paidAt),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Change date',
                          icon: const Icon(Icons.calendar_today_outlined),
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: dialogContext,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                              initialDate: paidAt,
                            );
                            if (selected != null) {
                              setDialogState(() => paidAt = selected);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount =
                      double.tryParse(amountController.text.trim()) ?? 0;
                  final recordedBy = recordedByController.text.trim();
                  if (amount < 1) {
                    setDialogState(() {
                      error = 'Advance amount must be at least ₹1.';
                    });
                    return;
                  }
                  if (recordedBy.isEmpty) {
                    setDialogState(() {
                      error = 'Recorded by is required.';
                    });
                    return;
                  }
                  Navigator.pop(dialogContext, {
                    'amount': amount,
                    'mode': mode,
                    'recordedBy': recordedBy,
                    'paidAt': paidAt,
                  });
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        amountController.dispose();
        recordedByController.dispose();
      });
    }

    if (result == null || !context.mounted) return;

    try {
      await context.read<ConfirmStore>().updateAdvanceDetails(
            confirmId: quotation['confirmId'].toString(),
            amount: result['amount'] as double,
            mode: result['mode'].toString(),
            recordedBy: result['recordedBy'].toString(),
            paidAt: result['paidAt'] as DateTime,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Advance details updated')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update advance: $e')),
      );
    }
  }

  String? _generatedBillId(
    Map<String, dynamic> quotation,
    List<Map<String, dynamic>> bills,
  ) {
    final existingBillId = quotation['billId']?.toString();
    if (quotation['billGenerated'] == true) {
      return existingBillId != null && existingBillId.isNotEmpty
          ? existingBillId
          : 'generated';
    }

    for (final bill in bills) {
      final billId = bill['billId']?.toString();
      if (billId == null || billId.isEmpty) continue;

      if (_sameValue(bill['confirmId'], quotation['confirmId']) ||
          _sameValue(
            bill['originalQuotationId'],
            quotation['originalQuotationId'],
          )) {
        return billId;
      }

      final sameCustomer =
          _sameText(bill['customerName'], quotation['customerName']) &&
              _sameText(bill['phone1'], quotation['phone1']);
      final sameStay =
          _sameDate(bill['checkInDate'], quotation['checkInDate']) &&
              _sameDate(bill['checkOutDate'], quotation['checkOutDate']);

      if (sameCustomer && sameStay) {
        return billId;
      }
    }

    return null;
  }

  bool _sameValue(dynamic a, dynamic b) {
    final left = a?.toString();
    final right = b?.toString();
    return left != null && left.isNotEmpty && left == right;
  }

  bool _sameText(dynamic a, dynamic b) {
    final left = a?.toString().trim().toLowerCase();
    final right = b?.toString().trim().toLowerCase();
    return left != null && left.isNotEmpty && left == right;
  }

  bool _sameDate(dynamic a, dynamic b) {
    final left = _asDate(a);
    final right = _asDate(b);
    if (left == null || right == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      final dynamic date = value.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
