import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/screens/itinerary_history_tab.dart';
import 'package:neyyar_heritage/widgets/list_filter_dialog.dart';

class ItineraryScreen extends StatefulWidget {
  const ItineraryScreen({super.key});

  @override
  State<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends State<ItineraryScreen> {

  ListFilterValues _filters = const ListFilterValues();

  Future<void> _openFilter() async {
    final result = await showListFilterDialog(context, initial: _filters);
    if (result != null && mounted) setState(() => _filters = result);
  }

  /// Firestore query based on filter
  Query getQuery() {
    final baseQuery = FirebaseFirestore.instance
        .collection('itineraries')
        .orderBy('date', descending: true);

    if (_filters.from == null && _filters.to == null) return baseQuery;

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('itineraries');
    if (_filters.from != null) {
      final from = DateTime(
        _filters.from!.year,
        _filters.from!.month,
        _filters.from!.day,
      );
      query = query.where('date', isGreaterThanOrEqualTo: from);
    }
    if (_filters.to != null) {
      final toExclusive = DateTime(
        _filters.to!.year,
        _filters.to!.month,
        _filters.to!.day,
      ).add(const Duration(days: 1));
      query = query.where('date', isLessThan: toExclusive);
    }
    return query.orderBy('date', descending: true);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Itineraries"),
        actions: [
          IconButton(
            tooltip: 'Filter by customer and dates',
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilter,
          ),
        ],
      ),

      body: Column(
        children: [

          /// Active filter summary
          if (_filters.customerName.isNotEmpty ||
              _filters.from != null ||
              _filters.to != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: const Color(0xFFC8E6C9),
              child: Text(
                [
                  if (_filters.customerName.isNotEmpty)
                    'Customer: ${_filters.customerName}',
                  if (_filters.from != null)
                    'From: ${DateFormat('dd MMM yyyy').format(_filters.from!)}',
                  if (_filters.to != null)
                    'To: ${DateFormat('dd MMM yyyy').format(_filters.to!)}',
                ].join('  •  '),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

          /// Itinerary List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
  stream: getQuery().snapshots(),
  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final now = DateTime.now();

    /// 🔴 FILTER LOGIC
    final docs = snapshot.data!.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final date = (data['date'] as Timestamp?)?.toDate();
      final name = (data['name'] ?? '').toString().toLowerCase();

      if (date == null) return false;

      final queryName = _filters.customerName.trim().toLowerCase();
      if (queryName.isNotEmpty && !name.contains(queryName)) return false;

      if (_filters.from == null && _filters.to == null &&
          _filters.customerName.isEmpty) {
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
        return now.isBefore(endOfDay);
      }
      if (_filters.from != null && date.isBefore(DateTime(
        _filters.from!.year, _filters.from!.month, _filters.from!.day,
      ))) return false;
      if (_filters.to != null && date.isAfter(DateTime(
        _filters.to!.year, _filters.to!.month, _filters.to!.day, 23, 59, 59,
      ))) return false;
      return true;
    }).toList();

    if (docs.isEmpty) {
      return const Center(child: Text("No itineraries found"));
    }

    return ItineraryHistoryTab(
      docs: docs,
      viewOnly: true,
    );
  },
),
          ),
        ],
      ),
    );
  }
}
