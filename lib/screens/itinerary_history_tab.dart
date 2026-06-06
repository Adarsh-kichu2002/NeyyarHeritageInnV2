import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ItineraryHistoryTab extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool viewOnly;

  const ItineraryHistoryTab({
    super.key,
    required this.docs,
    this.viewOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            /// HEADER
            Container(
              color: const Color.fromARGB(255, 56, 220, 62),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: const Row(
                children: [
                  _HeaderCell('Sl No', 60),
                  _HeaderCell('Name', 150),
                  _HeaderCell('Phone', 130),
                  _HeaderCell('Date', 110),
                  _HeaderCell('No. of Pax', 100),
                  _HeaderCell('Actions', 160),
                ],
              ),
            ),

            /// DATA
            ...docs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;

              final adult = (data['adult'] ?? 0) as int;
              final children = (data['children'] ?? 0) as int;
              final child = (data['child'] ?? 0) as int;

              final totalPax = adult + children + child;

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey),
                  ),
                ),
                child: Row(
                  children: [

                    _DataCell('${index + 1}', 60),

                    _DataCell(data['name'] ?? '-', 150),

                    _DataCell(data['mobile'] ?? '-', 130),

                    _DataCell(_fmtDate(data['date']), 110),

                    _DataCell('$totalPax', 100),

                    /// ACTIONS
                    SizedBox(
                      width: 160,
                      child: Row(
                        children: [

                          /// VIEW
                          IconButton(
                            icon: const Icon(
                              Icons.visibility,
                              size: 20,
                              color: Colors.green,
                            ),
                            onPressed: () {
                              final convertedData = {
                                ...data,
                                'date': (data['date'] as Timestamp?)?.toDate(),
                              };

                              Navigator.pushNamed(
                                context,
                                '/itinerary_preview',
                                arguments: {
                                  ...convertedData,
                                  'docId': doc.id,
                                  'mode': 'view',
                                },
                              );
                            },
                          ),

                          /// EDIT + DELETE only if not viewOnly
                          if (!viewOnly)
                            IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 20,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                final convertedData = {
                                  ...data,
                                  'date':
                                      (data['date'] as Timestamp?)?.toDate(),
                                };

                                Navigator.pushNamed(
                                  context,
                                  '/create_itinerary',
                                  arguments: {
                                    ...convertedData,
                                    'docId': doc.id,
                                    'mode': 'edit',
                                  },
                                );
                              },
                            ),

                          if (!viewOnly)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Delete Itinerary'),
                                    content:
                                        const Text('Are you sure?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await FirebaseFirestore.instance
                                      .collection('itineraries')
                                      .doc(doc.id)
                                      .delete();
                                }
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// FORMAT DATE
  static String _fmtDate(dynamic d) {
    if (d == null) return '-';

    if (d is Timestamp) {
      final date = d.toDate();

      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    }

    return d.toString();
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final double width;

  const _HeaderCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final double width;

  const _DataCell(this.text, this.width);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      child: Text(text),
    );
  }
}
