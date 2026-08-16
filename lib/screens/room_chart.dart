import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoomChartScreen extends StatefulWidget {
  const RoomChartScreen({super.key});

  @override
  State<RoomChartScreen> createState() => _RoomChartScreenState();
}

class _RoomChartScreenState extends State<RoomChartScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, bool> markedDates = {};
  Map<String, dynamic> selectedRooms = {};

  List<int> _parsePax(String pax) {
  if (pax.isEmpty) return [0, 0, 0];

  return pax
      .split("+")
      .map((e) => int.tryParse(e.trim()) ?? 0)
      .toList();
}

String _mergePax(List<int> a, List<int> b) {
  int length = a.length > b.length ? a.length : b.length;

  List<int> result = List.generate(length, (index) {
    int valA = index < a.length ? a[index] : 0;
    int valB = index < b.length ? b[index] : 0;
    return valA + valB;
  });

  return result.join("+");
}

Map<String, String> _calculateNameWiseTotals() {
  Map<String, String> totals = {};

  for (var entry in selectedRooms.entries) {
    final name = entry.value["name"] ?? "";
    final pax = entry.value["pax"] ?? "";

    if (name.isEmpty || pax.isEmpty) continue;

    if (!totals.containsKey(name)) {
      totals[name] = pax;
    } else {
      totals[name] = _mergePax(
        _parsePax(totals[name]!),
        _parsePax(pax),
      );
    }
  }

  return totals;
}

String _calculateGrandTotal() {
  List<int> total = [0, 0, 0];

  for (var entry in selectedRooms.entries) {
    final pax = entry.value["pax"] ?? "";
    final parsed = _parsePax(pax);

    for (int i = 0; i < parsed.length; i++) {
      if (i >= total.length) total.add(0);
      total[i] += parsed[i];
    }
  }

  return total.join("+");
}

  @override
  void initState() {
    super.initState();
    _loadMarkedDates();
  }

  /// LOAD RED MARKED DATES
  Future<void> _loadMarkedDates() async {
    markedDates.clear();

    final snapshot =
        await _firestore.collection("room_occupancy").get();

    for (var doc in snapshot.docs) {
      markedDates[doc.id] = true;
    }

    setState(() {});
  }

  /// LOAD DATA FOR SELECTED DATE
  Future<void> _loadDateData(DateTime date) async {
    final id = DateFormat('yyyy-MM-dd').format(date);

    final doc =
        await _firestore.collection("room_occupancy").doc(id).get();

    if (doc.exists) {
      selectedRooms =
          Map<String, dynamic>.from(doc.data()!["rooms"]);
    } else {
      selectedRooms = {};
    }

    setState(() {});
  }

  bool _isPastDay(DateTime day) {
    final today = DateTime.now();
    final yesterday =
        DateTime(today.year, today.month, today.day - 1);
    return day.isBefore(yesterday);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedDay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _selectedDay = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Room Chart"),
        ),
        body: _selectedDay == null
            ? _buildCalendar()
            : _buildRoomDisplay(),
      ),
    );
  }

  /// ================= CALENDAR =================

  Widget _buildCalendar() {
    final today = DateTime.now();
    final todayOnly =
        DateTime(today.year, today.month, today.day);

    return TableCalendar(
      firstDay: todayOnly,
      lastDay: DateTime(2100),
      focusedDay: _focusedDay,
      enabledDayPredicate: (day) => !_isPastDay(day),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false, // hide "2 weeks" format button
      ),

      onDaySelected: (selectedDay, focusedDay) async {
        if (_isPastDay(selectedDay)) return;

        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });

        await _loadDateData(selectedDay);
      },

      calendarBuilders: CalendarBuilders(

  /// 🔴 TODAY (IMPORTANT FIX)
  todayBuilder: (context, day, focusedDay) {
    final id = DateFormat('yyyy-MM-dd').format(day);

    if (markedDates.containsKey(id)) {
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

    /// fallback default today UI
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

  /// 🔴 OTHER DAYS
  defaultBuilder: (context, day, focusedDay) {
    final id = DateFormat('yyyy-MM-dd').format(day);

    if (markedDates.containsKey(id)) {
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
    return null;
  },
      ),
    );
  }

  /// ================= ROOM DISPLAY =================

  Widget _buildRoomDisplay() {
  final dateText =
      DateFormat('dd MMM yyyy').format(_selectedDay!);

  final nameTotals = _calculateNameWiseTotals();
  final grandTotal = _calculateGrandTotal();

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          dateText,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),

      /// ROOM LIST
      Expanded(
        child: selectedRooms.isEmpty
            ? const Center(child: Text("No Rooms Booked"))
            : ListView(
                children: selectedRooms.entries.map((entry) {
                  final roomType = entry.key;
                  final name = entry.value["name"];
                  final pax = entry.value["pax"];

                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          roomType,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold),
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(name),
                            Text("PAX: $pax"),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
      ),

      /// 🔽 FIXED BOTTOM SUMMARY
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ...nameTotals.entries.map(
              (e) => Text(
                "${e.key}  →  ${e.value}",
                style: const TextStyle(
                    fontWeight: FontWeight.w500),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              "Grand Total: $grandTotal",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
            ),

            const SizedBox(height: 10),

            // Phone back returns to the calendar (PopScope).
            // ElevatedButton(
            //   onPressed: () {
            //     setState(() {
            //       _selectedDay = null;
            //     });
            //   },
            //   child: const Text("Back"),
            // ),
          ],
        ),
      )
    ],
  );
}
}
