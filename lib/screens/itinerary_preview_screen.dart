import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'dart:typed_data';

class ItineraryPreviewScreen extends StatelessWidget {
  const ItineraryPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    final String? docId = args['docId'];
    final String mode = args['mode'] ?? 'create';

    /// 🔹 SAFELY CONVERT DATE
    DateTime date;
    if (args['date'] is Timestamp) {
      date = (args['date'] as Timestamp).toDate();
    } else {
      date = args['date'] as DateTime;
    }

    final String start = args['start'];
    final String end = args['end'];

    final groupedItems = _groupByTime(args['items']);

    return Scaffold(
      appBar: AppBar(title: const Text('Itinerary Preview')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  /// HEADER
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset(
                        'assets/images/neyyar_logo.png',
                        height: 70,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${args['package']} ITINERARY'.toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${DateFormat('dd-MMM-yyyy').format(date)} '
                              '(${_to12Hr('$start-$end')})',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  /// ADDRESS
                  const Text('To,'),
                  Text(args['name'] ?? ''),
                  Text('Mob: ${args['mobile'] ?? ''}'),

                  const SizedBox(height: 16),

                  /// INTRO
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(color: Colors.black),
                      children: [
                        TextSpan(text: 'At '),
                        TextSpan(
                          text: 'Neyyar Heritage Inn - Home Stay ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text:
                              'we are committed to providing our guests with exceptional experiences '
                      'that create lasting memories. We encourage you to review the details and feel free '
                      'to reach out if you have any questions or clarification.',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  /// PAX
                  Text(
                    'No. of Pax: '
                    '${args['adult'] ?? 0} + '
                    '${args['children'] ?? 0} + '
                    '${args['child'] ?? 0} = '
                    '${(args['adult'] ?? 0) + (args['children'] ?? 0) + (args['child'] ?? 0)}',
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Guide Details: ${args['guideName'] ?? 'N/A'} '
                    '${args['guidePhone'] ?? 'N/A'}'
                  ),

                  /// TABLE
                  _buildTable(groupedItems),

                  const SizedBox(height: 20),

                  /// TERMS
                  const Text(
                    'Terms & Conditions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '• No transportation available.\n'
                    '• If members are fewer than started in the booking confirmation, please inform us at least 3 days in advance. Otherwise, the full amount will be charged.\n'
                    'This policy must be strictly followed.',
                    style: TextStyle(color: Colors.red),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                      'We look forward to welcoming you to Neyyar Heritage Inn. '
                      'If you have any special requests or require further assistance, '
                      'please contact our reservation team at +91 85900 71406.'),
                  const SizedBox(height: 12),
                  const Text(
                      'Thank you for choosing us! We are eager to make your time with us exceptional and unforgettable.'),
                  const SizedBox(height: 12),
                  const Text('Best regards,'),
                  const Text(
                    'Neyyar Heritage Inn',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),

          /// FOOTER BAR
          Container(
            color: const Color.fromRGBO(52, 191, 59, 1),
            padding: const EdgeInsets.all(8),
            child: const Row(
              children: [
                Expanded(
                  child: Text('9656763391',
                      style: TextStyle(color: Colors.white)),
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
          ),

          /// SAVE & DOWNLOAD
          Padding(
  padding: const EdgeInsets.all(12),
  child: ElevatedButton(
    onPressed: () async {

      final firestoreData = {
        'package': args['package'],
        'name': args['name'],
        'mobile': args['mobile'],
        'date': Timestamp.fromDate(date),
        'start': start,
        'end': end,
        'adult': args['adult'],
        'children': args['children'],
        'child': args['child'],
        'guideName': args['guideName'] ?? '',
        'guidePhone': args['guidePhone'] ?? '',
        'items': args['items'],
        'updatedAt': FieldValue.serverTimestamp(),
      };

      /// 🔥 ONLY CHECK docId
      if (docId != null) {
        await FirebaseFirestore.instance
            .collection('itineraries')
            .doc(docId)
            .update(firestoreData);
      } else {
        await FirebaseFirestore.instance
            .collection('itineraries')
            .add({
          ...firestoreData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await Printing.layoutPdf(
        onLayout: (_) =>
            _buildExactPdf({...args, 'date': date}, groupedItems),
      );

      Navigator.pop(context);
    },
    child: Text(docId != null
        ? 'Update & Download'
        : 'Save & Download'),
  ),
),
        ],
      ),
    );
  }


  /// ================= HELPERS =================

  static Map<String, List<String>> _groupByTime(List items) {
  final Map<String, List<String>> map = {};
  for (final e in items) {
    final time = (e['to'] == null || e['to'].isEmpty)
        ? e['from']
        : '${e['from']}-${e['to']}'; // removed spaces

    map.putIfAbsent(time, () => []);
    map[time]!.add(e['title']);
  }
  return map;
}


static String _to12Hr(String time) {
  if (time.isEmpty) return '';

  final parts = time.split('-').map((e) => e.trim()).toList();

  DateTime parse(String t) {
    return DateFormat('H:mm').parse(t);
  }

  String format(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  if (parts.length == 2) {
    final from = format(parse(parts[0]));
    final to = format(parse(parts[1]));
    return '$from to $to';
  } else {
    return format(parse(parts[0]));
  }
}

  /// ================= TABLE UI =================

 Widget _buildTable(Map<String, List<String>> groupedItems) {
  const double timeColumnWidth = 140; // slightly wider for single-line time
  int serial = 1;

  return Column(
    children: [
      /// ================= HEADER =================
      Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black),
          color: const Color.fromARGB(255, 52, 191, 59),
        ),
        child: const Row(
          children: [
            _Cell(width: 40, text: 'No', bold: true),
            _VLine(),
            _Cell(flex: 1, text: 'Item', bold: true),
            _VLine(),
            _Cell(width: 140, text: 'Time', bold: true),
          ],
        ),
      ),

      /// ================= BODY =================
      ...groupedItems.entries.map((entry) {
        final timeText = _to12Hr(entry.key);
        final items = entry.value;
        return IntrinsicHeight(
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// ===== NO + ITEM COLUMN =====
            Expanded(
              child: Column(
                children: List.generate(items.length, (index) {
                  return Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.black),
                        bottom: BorderSide(color: Colors.black),
                      ),
                    ),
                    child: Row(
                      children: [
                        _Cell(
                          width: 40,
                          text: (serial++).toString(),
                          color: Colors.green,
                        ),
                        const _VLine(),
                        _Cell(
                          flex: 1,
                          text: items[index],
                          color: Colors.green,
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),

            /// ===== MERGED TIME COLUMN =====
            Container(
              width: timeColumnWidth,
              decoration: const BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.black),
                  right: BorderSide(color: Colors.black),
                  bottom: BorderSide(color: Colors.black),
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    timeText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 13, // optimized to fit single line
                    ),
                  ),
                ),
              ),
            ),
          ],
        ));
      }),
    ],
  );
}


  /// ================= PDF =================

Future<Uint8List> _buildExactPdf(
  Map<String, dynamic> args,
  Map<String, List<String>> groupedItems,
) async {
  final pdf = pw.Document();

  final logo = await imageFromAssetBundle(
    'assets/images/neyyar_logo.png',
  );

  const PdfColor kDarkGreen = PdfColor.fromInt(0xFF34BF3B);

  int serial = 1;

  pdf.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),

      build: (context) => [

        /// ================= HEADER =================
        pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [

    /// LEFT SIDE - LOGO
    pw.Image(
      logo,
      height: 80,
    ),

    /// PUSH CONTENT TO RIGHT
    pw.Spacer(),

    /// RIGHT SIDE - PACKAGE + DATE + TIME
    pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          '${args['package']} ITINERARY',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          DateFormat('dd-MMM-yyyy').format(args['date']),
        ),
        pw.Text(
          _to12Hr('${args['start']}-${args['end']}'),
        ),
      ],
    ),
  ],
),

        pw.SizedBox(height: 16),

        /// ================= ADDRESS =================
        pw.Text('To,'),
        pw.Text(args['name']),
        pw.Text('Mob: ${args['mobile']}'),

        pw.SizedBox(height: 12),

        /// ================= INTRO =================
        pw.RichText(
          text: pw.TextSpan(
            children: [
              const pw.TextSpan(text: 'At '),
              pw.TextSpan(
                text: 'Neyyar Heritage Inn - Home Stay ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              const pw.TextSpan(
                text:
                    'we are committed to providing our guests with exceptional experiences '
                      'that create lasting memories. We encourage you to review the details and feel free '
                      'to reach out if you have any questions or clarification.',
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 10),

        /// ================= PAX =================
        pw.Text(
          'No. of Pax: ${args['adult']} + ${args['children']} + ${args['child']} '
          '= ${args['adult'] + args['children'] + args['child']}',
        ),

        pw.SizedBox(height: 16),

        /// ================= GUIDE DETAILS =================
        pw.Text(
          'Guide Details: ${args['guideName'] ?? 'N/A'} - ${args['guidePhone'] ?? 'N/A'}',
        ),

        /// ================= PAGINATING ITINERARY TABLE =================
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.black),
          columnWidths: {
            0: const pw.FixedColumnWidth(40),
            1: const pw.FlexColumnWidth(),
            2: const pw.FixedColumnWidth(120),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: kDarkGreen),
              children: ['No', 'Item', 'Time'].map((label) =>
                pw.Padding(
                  padding: const pw.EdgeInsets.all(8),
                  child: pw.Text(label,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ).toList(),
            ),
            for (final entry in groupedItems.entries)
              for (final item in entry.value)
                pw.TableRow(
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('${serial++}',
                        style: const pw.TextStyle(color: PdfColors.green)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(item,
                        style: const pw.TextStyle(color: PdfColors.green)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(_to12Hr(entry.key),
                        textAlign: pw.TextAlign.center,
                        style: const pw.TextStyle(color: PdfColors.green)),
                    ),
                  ],
                ),
          ],
        ),

pw.SizedBox(height: 20),


        /// ================= TERMS =================
        pw.Text(
          'Terms & Conditions',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green),
        ),
        pw.SizedBox(height: 6),
       pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Container(
      width: 6,
      height: 6,
      margin: const pw.EdgeInsets.only(top: 5, right: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.red,
        shape: pw.BoxShape.circle,
      ),
    ),
    pw.Expanded(
      child: pw.Text(
        'No transportation available.',
        style: const pw.TextStyle(color: PdfColors.red),
      ),
    ),
  ],
),

pw.SizedBox(height: 6),

pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Container(
      width: 6,
      height: 6,
      margin: const pw.EdgeInsets.only(top: 5, right: 6),
      decoration: const pw.BoxDecoration(
        color: PdfColors.red,
        shape: pw.BoxShape.circle,
      ),
    ),
    pw.Expanded(
      child: pw.Text(
        'If members are fewer than started in the booking confirmation, please inform us at least 3 days in advance. Otherwise, the full amount will be charged.\n This policy must be strictly followed.',
        style: const pw.TextStyle(color: PdfColors.red),
      ),
    ),
  ],
),


        pw.SizedBox(height: 20),

        pw.Text('We look forward to welcoming you to Neyyar Heritage Inn. if you have any special requests or require further assistance, please do not hesitate to contact our reservation team at +91 85900 71406.'),
        pw.SizedBox(height: 12),
        pw.Text('Thank you for choosing us! We are eager to make your time with us exceptional and unforgettable.'),
        pw.Text('Best regards,'),
        pw.Text(
          'Neyyar Heritage Inn',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
      ],

      /// ================= FOOTER =================
      footer: (context) => pw.Container(
        color: kDarkGreen,
        padding: const pw.EdgeInsets.all(8),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Text(
                '+91 9656763391',
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
    ),
  );

  return pdf.save();
}

}
/// ================= TABLE WIDGETS =================

class _Cell extends StatelessWidget {
  final double? width;
  final int? flex;
  final String text;
  final bool bold;
  final Color? color;

  const _Cell({
    this.width,
    this.flex,
    required this.text,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
        ),
      ),
    );

    if (width != null) return SizedBox(width: width, child: child);
    return Expanded(flex: flex!, child: child);
  }
}

class _VLine extends StatelessWidget {
  const _VLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, color: Colors.black);
  }
}
