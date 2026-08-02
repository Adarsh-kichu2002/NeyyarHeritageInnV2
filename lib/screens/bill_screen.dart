import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  Map<String, dynamic> billData = {};

  bool isEdit = false;
  bool _initialized = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();

  DateTime? checkIn;
  DateTime? checkOut;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    _initialized = true;

    _loadData();
  }

  Future<void> _loadData() async {
    final args =
        ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>?;

    billData = args ?? {};

    isEdit = billData['isEdit'] == true;

    _nameCtrl.text =
        billData['customerName'] ?? '';

    _phoneCtrl.text =
        billData['phone1'] ?? '';

    /// EDIT MODE → KEEP SAME INVOICE
    if (isEdit) {
      _invoiceCtrl.text =
          billData['invoiceNo']
                  ?.toString() ??
              '';
    }

    /// CREATE MODE → GENERATE NEXT INVOICE
    else {
      final snapshot =
          await _db
              .collection('bills')
              .orderBy(
                'invoiceNoInt',
                descending: true,
              )
              .limit(1)
              .get();

      int nextInvoice = 32;

      if (snapshot.docs.isNotEmpty) {
        final lastInvoice =
            snapshot.docs.first.data()['invoiceNoInt'];

        final lastNo = lastInvoice is num
            ? lastInvoice.toInt()
            : int.tryParse(lastInvoice?.toString() ?? '') ?? 31;

        nextInvoice = lastNo + 1;
      }

      _invoiceCtrl.text =
          nextInvoice.toString();
    }

    checkIn =
        _parseDate(billData['checkInDate']) ??
            DateTime.now();

    checkOut =
        _parseDate(billData['checkOutDate']) ??
            DateTime.now().add(
              const Duration(days: 1),
            );

    if (mounted) {
      setState(() {});
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    try {
      final dynamic date = value.toDate();
      if (date is DateTime) return date;
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit
              ? 'Edit Bill'
              : 'Create Bill',
        ),
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration:
                  const InputDecoration(
                labelText:
                    'Guest Name',
              ),
            ),

            TextField(
              controller: _phoneCtrl,
              keyboardType:
                  TextInputType.phone,
              decoration:
                  const InputDecoration(
                labelText: 'Phone',
              ),
            ),

            TextField(
              controller: _invoiceCtrl,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    'Invoice Number',
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                _dateBtn(
                  'Check In',
                  checkIn,
                  (d) {
                    setState(() {
                      checkIn = d;
                    });
                  },
                ),

                const SizedBox(
                  width: 8,
                ),

                _dateBtn(
                  'Check Out',
                  checkOut,
                  (d) {
                    setState(() {
                      checkOut = d;
                    });
                  },
                ),
              ],
            ),

            const Spacer(),

            SizedBox(
              width:
                  double.infinity,
              child:
                  ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/bill_list',
                    arguments: {
                      ...billData,

                      'isEdit':
                          isEdit,

                      'customerName':
                          _nameCtrl.text
                              .trim(),

                      'phone1':
                          _phoneCtrl.text
                              .trim(),

                      'invoiceNo':
                          _invoiceCtrl
                              .text
                              .trim(),

                      /// IMPORTANT
                      'invoiceNoInt':
                          int.tryParse(
                                _invoiceCtrl
                                    .text,
                              ) ??
                              0,

                      'checkInDate':
                          checkIn,

                      'checkOutDate':
                          checkOut,
                    },
                  );
                },
                child:
                    const Text(
                  'Next',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateBtn(
    String label,
    DateTime? date,
    Function(DateTime) onPick,
  ) {
    return Expanded(
      child:
          OutlinedButton(
        onPressed:
            () async {
          final picked =
              await showDatePicker(
            context:
                context,
            initialDate:
                date ??
                    DateTime.now(),
            firstDate:
                DateTime(
                    2020),
            lastDate:
                DateTime(
                    2100),
          );

          if (picked !=
              null) {
            onPick(
                picked);
          }
        },
        child: Text(
          date == null
              ? label
              : DateFormat(
                  'dd/MM/yyyy',
                ).format(
                  date,
                ),
        ),
      ),
    );
  }
}
