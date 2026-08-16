import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/bill_history_store.dart';
import 'package:neyyar_heritage/history/confirm_store.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:neyyar_heritage/widgets/advance_payments_dialog.dart';

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

  /// Last calendar day a booking is shown (check-in through day before checkout).
  DateTime _calendarEndDate(DateTime checkIn, DateTime? checkOut) {
    final start = _dateOnly(checkIn);
    if (checkOut == null) return start;
    final checkout = _dateOnly(checkOut);
    if (!checkout.isAfter(start)) return start;
    return checkout.subtract(const Duration(days: 1));
  }

  bool _isOnStayCalendar(DateTime day, DateTime checkIn, DateTime? checkOut) {
    final selected = _dateOnly(day);
    final start = _dateOnly(checkIn);
    final end = _calendarEndDate(checkIn, checkOut);
    return !selected.isBefore(start) && !selected.isAfter(end);
  }

  bool _isPastDay(DateTime day) {
    return _dateOnly(day).isBefore(_earliestSelectableDay());
  }

  /// Yesterday and today are tappable (generate bill on last stay day when checkout is today).
  DateTime _earliestSelectableDay() {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day - 1);
  }

  DateTime _todayOnly() {
    final today = DateTime.now();
    return DateTime(today.year, today.month, today.day);
  }

  Map<String, bool> _markedDates(List<Map<String, dynamic>> quotations) {
    final marked = <String, bool>{};

    for (final q in quotations) {
      final checkIn = q['checkInDate'];
      final checkOut = q['checkOutDate'];
      if (checkIn is! DateTime) continue;

      final start = _dateOnly(checkIn);
      final end = _calendarEndDate(
        checkIn,
        checkOut is DateTime ? checkOut : null,
      );

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
    return quotations.where((q) {
      final checkIn = q['checkInDate'];
      final checkOut = q['checkOutDate'];
      if (checkIn is! DateTime) return false;

      return _isOnStayCalendar(
        day,
        checkIn,
        checkOut is DateTime ? checkOut : null,
      );
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

    return PopScope(
      canPop: _selectedDay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _selectedDay = null);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Confirmed Quotations')),
        body: _selectedDay == null
            ? _buildCalendar(markedDates)
            : _buildDayDisplay(
                _quotationsForDay(quotations, _selectedDay!),
                billStore.bills,
              ),
      ),
    );
  }

  Widget _buildCalendar(Map<String, bool> markedDates) {
    final todayOnly = _todayOnly();
    final earliestDay = _earliestSelectableDay();
    final focusedDay =
        _focusedDay.isBefore(earliestDay) ? todayOnly : _focusedDay;

    return TableCalendar(
      firstDay: earliestDay,
      lastDay: DateTime(2100),
      focusedDay: focusedDay,
      enabledDayPredicate: (day) => !_isPastDay(day),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false, // hide "2 weeks" format button
      ),
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
            return _isYesterday(day) ? _orangeDay(day) : _redDay(day);
          }
          if (_isYesterday(day)) {
            return _orangeDay(day);
          }
          return null;
        },
      ),
    );
  }

  bool _isYesterday(DateTime day) =>
      _dateOnly(day) == _earliestSelectableDay();

  Widget _orangeDay(DateTime day) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.orange.shade400,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: const TextStyle(color: Colors.white),
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
              // Phone back returns to the calendar (PopScope).
              // ElevatedButton(
              //   onPressed: () {
              //     setState(() => _selectedDay = null);
              //   },
              //   child: const Text('Back'),
              // ),
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
                        : () => AdvancePaymentsViewDialog.show(
                              context,
                              record: q,
                            ),
                    child: Text(
                      'Advance: ₹${q['advance'] ?? 0}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red,
                      ),
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
