import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RoomOccupancyScreen extends StatefulWidget {
  const RoomOccupancyScreen({super.key});

  @override
  State<RoomOccupancyScreen> createState() => _RoomOccupancyScreenState();
}

class _RoomOccupancyScreenState extends State<RoomOccupancyScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, List<String>> confirmedNamesByDate = {};

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<String, bool> markedDates = {};

  final List<Map<String, dynamic>> rooms = [
    {"type": "AC-FF-LVB", "color": Colors.blue},
    {"type": "AC-FF-PLV", "color": Colors.blue},
    {"type": "AC-GF-LV", "color": Colors.blue},
    {"type": "AC-GF-PLV", "color": Colors.blue},
    {"type": "Cottage -LV 1", "color": const Color.fromARGB(255, 255, 0, 247)},
    {"type": "Cottage -LV 2", "color": const Color.fromARGB(255, 255, 0, 247)},
    {"type": "Hut-Agastya", "color": Colors.green},
    {"type": "Hut-Pool Side", "color": Colors.green},
    {"type": "A-GF", "color": Colors.orange},
    {"type": "A-FF", "color": Colors.orange},
    {"type": "A frame new", "color": Colors.orange},
    {"type": "Tree Hut-Pool Side", "color": Colors.orange},
    {"type": "No Room 1", "color": const Color.fromARGB(255, 8, 39, 243)},
    {"type": "No Room 2", "color": const Color.fromARGB(255, 8, 39, 243)},
    {"type": "TENT-FAMILY 2", "color": Colors.red},
    {"type": "TENT SML 1", "color": Colors.red},
    {"type": "TENT SML 2", "color": Colors.red},
    {"type": "TENT SML 3", "color": Colors.red},
    {"type": "TENT SML 4", "color": Colors.red},
    {"type": "TENT SML 5", "color": Colors.red},
  ];

  final Map<String, TextEditingController> nameControllers = {};
  final Map<String, TextEditingController> paxControllers = {};
  final Map<String, String?> selectedNames = {};

  @override
  void initState() {
    super.initState();
    _loadMarkedDates();

    for (var room in rooms) {
      nameControllers[room["type"]] = TextEditingController();
      paxControllers[room["type"]] = TextEditingController();
      selectedNames[room["type"]] = null;
    }
  }

  /// ================= FIREBASE =================

  Future<void> _loadMarkedDates() async {
  markedDates.clear();

  /// 🔴 Existing occupancy entries (RED)
  final occupancySnapshot =
      await _firestore.collection("room_occupancy").get();

  for (var doc in occupancySnapshot.docs) {
    markedDates[doc.id] = true; // red circle
  }

  /// 🟢 Confirmed quotations (GREEN)
  final confirmSnapshot =
      await _firestore.collection("confirmed_quotations").get();

  for (var doc in confirmSnapshot.docs) {
  final data = doc.data();
  final checkIn = data['checkInDate'];

  if (checkIn != null) {
    DateTime date =
        (checkIn is Timestamp) ? checkIn.toDate() : checkIn;

    final id = DateFormat('yyyy-MM-dd').format(date);

    // Only mark green if:
    // 1) No occupancy exists
    // 2) There is actually confirmed data
    if (!markedDates.containsKey(id)) {
      markedDates[id] = false; // green
    }
  }
}

  setState(() {});
}

 Future<void> _loadDateData(DateTime date) async {
  final id = DateFormat('yyyy-MM-dd').format(date);
  final doc =
      await _firestore.collection("room_occupancy").doc(id).get();

  if (doc.exists) {
    final roomData =
        Map<String, dynamic>.from(doc.data()!["rooms"]);

    final dateKey = DateFormat('yyyy-MM-dd').format(date);
    final confirmedList = confirmedNamesByDate[dateKey] ?? [];

    for (var room in rooms) {
      final type = room["type"];

      if (roomData.containsKey(type)) {
        final savedName = roomData[type]["name"];
        final savedPax = roomData[type]["pax"];

        nameControllers[type]!.text = savedName ?? '';
        paxControllers[type]!.text = savedPax ?? '';

        // ✅ Restore dropdown selection properly
        if (confirmedList.contains(savedName)) {
          selectedNames[type] = savedName;
        } else {
          selectedNames[type] = "Manual Entry";
        }
      } else {
        nameControllers[type]!.clear();
        paxControllers[type]!.clear();
        selectedNames[type] = null;
      }
    }
  } else {
    for (var room in rooms) {
      nameControllers[room["type"]]!.clear();
      paxControllers[room["type"]]!.clear();
      selectedNames[room["type"]] = null;
    }
  }

  setState(() {});
}

  Future<void> _saveData() async {
  if (_selectedDay == null) return;

  final id = DateFormat('yyyy-MM-dd').format(_selectedDay!);

  Map<String, dynamic> roomData = {};

  for (var room in rooms) {
    final type = room["type"];
    final name = nameControllers[type]!.text.trim();
    final pax = paxControllers[type]!.text.trim();

    if (name.isNotEmpty) {
      roomData[type] = {
        "name": name,
        "pax": pax,
      };
    }
  }

  /// 🔴 IF ALL DATA REMOVED → DELETE DOCUMENT
  if (roomData.isEmpty) {
    await _firestore.collection("room_occupancy").doc(id).delete();
    await _loadMarkedDates();

    setState(() {
      _selectedDay = null;
    });

    return;
  }

  /// ✅ SAVE DATA (NO DELETE AFTER THIS)
  await _firestore.collection("room_occupancy").doc(id).set({
    "date": id,
    "rooms": roomData,
    "timestamp": FieldValue.serverTimestamp(),
  });

  await _loadMarkedDates();

  setState(() {
    _selectedDay = null;
  });
}

  bool _isPastDay(DateTime day) {
    final today = DateTime.now();
    final yesterday =
        DateTime(today.year, today.month, today.day - 1);
    return day.isBefore(yesterday);
  }

  /// ================= PAX LOGIC =================

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
    Map<String, String> nameTotals = {};

    for (var room in rooms) {
      final type = room["type"];
      final name = nameControllers[type]!.text.trim();
      final pax = paxControllers[type]!.text.trim();

      if (name.isEmpty || pax.isEmpty) continue;

      if (!nameTotals.containsKey(name)) {
        nameTotals[name] = pax;
      } else {
        nameTotals[name] = _mergePax(
          _parsePax(nameTotals[name]!),
          _parsePax(pax),
        );
      }
    }

    return nameTotals;
  }

  String _calculateGrandTotal() {
    List<int> total = [0, 0, 0];

    for (var room in rooms) {
      final pax = paxControllers[room["type"]]!.text.trim();
      final parsed = _parsePax(pax);

      for (int i = 0; i < parsed.length; i++) {
        if (i >= total.length) total.add(0);
        total[i] += parsed[i];
      }
    }

    return total.join("+");
  }

  /// ================= UI =================

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
            : _buildRoomEntryScreen(),
      ),
    );
  }

  Widget _buildCalendar() {
  final today = DateTime.now();
  final todayOnly = DateTime(today.year, today.month, today.day);

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

  await _loadConfirmedNames(selectedDay);  // load first
  await _loadDateData(selectedDay);        // then restore selection
},

    calendarBuilders: CalendarBuilders(

      /// 🔴 NORMAL DAYS
     defaultBuilder: (context, day, focusedDay) {
  final id = DateFormat('yyyy-MM-dd').format(day);

  if (markedDates.containsKey(id)) {
    final isRed = markedDates[id]!;

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isRed ? Colors.red : Colors.green,
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

      /// 🔴 TODAY (VERY IMPORTANT)
      todayBuilder: (context, day, focusedDay) {
        final id = DateFormat('yyyy-MM-dd').format(day);

        if (markedDates.containsKey(id)) {
          return _redCircle(day);
        }

        /// If no data, show normal today highlight
        return Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.shade200,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '${day.day}',
            style: const TextStyle(color: Colors.black),
          ),
        );
      },
    ),
  );
}

Widget _redCircle(DateTime day) {
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

Future<void> _loadConfirmedNames(DateTime date) async {
  final snapshot = await _firestore
      .collection("confirmed_quotations")
      .where('checkInDate',
          isGreaterThanOrEqualTo:
              Timestamp.fromDate(DateTime(date.year, date.month, date.day)))
      .where('checkInDate',
          isLessThan:
              Timestamp.fromDate(DateTime(date.year, date.month, date.day + 1)))
      .get();

  List<String> names = [];

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final name = data['customerName'];
    if (name != null && name.toString().isNotEmpty) {
      names.add(name);
    }
  }

  confirmedNamesByDate[
      DateFormat('yyyy-MM-dd').format(date)] = names;

  setState(() {});
}

 Widget _buildRoomEntryScreen() {
  final nameTotals = _calculateNameWiseTotals();
  final grandTotal = _calculateGrandTotal();
  final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay!);
  final confirmedList = confirmedNamesByDate[dateKey] ?? [];

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          DateFormat('dd MMM yyyy').format(_selectedDay!),
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),

      Expanded(
        child: SingleChildScrollView(
          child: Column(
            children: rooms.map((room) {
              final type = room["type"];
              final color = room["color"];

              return Container(
                margin: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: color),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            type,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold),
                          ),
                        ),

                        /// DROPDOWN
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: confirmedList
                                    .contains(selectedNames[type])
                                ? selectedNames[type]
                                : null,
                            items: [
                              ...confirmedList.map(
                                (name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                ),
                              ),
                              const DropdownMenuItem(
                                value: "Manual Entry",
                                child: Text("Manual Entry"),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                selectedNames[type] = value;

                                if (value != "Manual Entry") {
                                  nameControllers[type]!.text =
                                      value ?? '';
                                } else {
                                  nameControllers[type]!.clear();
                                }
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: "Select Name",
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        /// PAX FIELD
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: paxControllers[type],
                            decoration: const InputDecoration(
                              hintText: "0+0+0",
                              hintStyle:
                                  TextStyle(fontWeight: FontWeight.w200),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),

                    /// MANUAL ENTRY TEXTFIELD
                    if (selectedNames[type] == "Manual Entry")
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: TextField(
                          controller: nameControllers[type],
                          decoration: const InputDecoration(
                            hintText: "Enter Name",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),

      /// Bottom Summary
      Container(
        padding: const EdgeInsets.all(12),
        color: Colors.grey.shade200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ...nameTotals.entries.map(
              (e) => Text(
                "${e.key}  →  ${e.value}",
                style:
                    const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Grand Total: $grandTotal",
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _saveData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(45),
              ),
              child: const Text(
                "Save",
              ),
            ),
          ],
        ),
      )
    ],
  );
}
}
