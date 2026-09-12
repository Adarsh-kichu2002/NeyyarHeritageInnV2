import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BillScreen extends StatefulWidget {
  const BillScreen({super.key});

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> billData = {};

  bool isEdit = false;
  bool _initialized = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _gstCtrl.dispose();
    _invoiceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

    billData = Map<String, dynamic>.from(args ?? {});

    isEdit = billData['isEdit'] == true;

    _nameCtrl.text = billData['customerName'] ?? '';
    _phoneCtrl.text = billData['phone1'] ?? '';

    /// Address from quotation / existing bill
    _addressCtrl.text = (billData['address'] ?? '').toString();

    /// Customer GST (editable; may be empty)
    _gstCtrl.text = (billData['customerGst'] ?? billData['gstNo'] ?? '')
        .toString();

    /// EDIT MODE → KEEP SAME INVOICE + BILL ID
    if (isEdit) {
      _invoiceCtrl.text = billData['invoiceNo']?.toString() ?? '';
    }

    /// CREATE MODE → GENERATE NEXT INVOICE + STABLE BILL ID
    else {
      // One billId for this create session so Back → Preview → Save
      // updates the same document instead of creating duplicates.
      final existingBillId = billData['billId']?.toString() ?? '';
      if (existingBillId.isEmpty) {
        billData['billId'] =
            DateTime.now().millisecondsSinceEpoch.toString();
      }

      final snapshot = await _db
          .collection('bills')
          .orderBy(
            'invoiceNoInt',
            descending: true,
          )
          .limit(1)
          .get();

      int nextInvoice = 1;

      if (snapshot.docs.isNotEmpty) {
        final lastInvoice = snapshot.docs.first.data()['invoiceNoInt'];

        final lastNo = lastInvoice is num
            ? lastInvoice.toInt()
            : int.tryParse(lastInvoice?.toString() ?? '') ?? 0;

        nextInvoice = lastNo + 1;
      }

      _invoiceCtrl.text = nextInvoice.toString();
    }

    checkIn = _parseDate(billData['checkInDate']) ?? DateTime.now();

    checkOut = _parseDate(billData['checkOutDate']) ??
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
          isEdit ? 'Edit Bill' : 'Create Bill',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Guest Name',
                      ),
                    ),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone',
                      ),
                    ),
                    TextField(
                      controller: _addressCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        alignLabelWithHint: true,
                      ),
                    ),
                    TextField(
                      controller: _gstCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'GST',
                        hintText: 'Enter GST number (optional)',
                      ),
                    ),
                    TextField(
                      controller: _invoiceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Invoice Number',
                      ),
                    ),
                    const SizedBox(height: 12),
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
                        const SizedBox(width: 8),
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
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/bill_list',
                    arguments: {
                      ...billData,
                      'isEdit': isEdit,
                      'customerName': _nameCtrl.text.trim(),
                      'phone1': _phoneCtrl.text.trim(),
                      'address': _addressCtrl.text.trim(),
                      'customerGst': _gstCtrl.text.trim(),
                      'invoiceNo': _invoiceCtrl.text.trim(),
                      'invoiceNoInt':
                          int.tryParse(_invoiceCtrl.text) ?? 0,
                      'checkInDate': checkIn,
                      'checkOutDate': checkOut,
                      // Keep the same Firestore doc for this create session.
                      'billId': billData['billId'],
                    },
                  );
                },
                child: const Text('Next'),
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
      child: OutlinedButton(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );

          if (picked != null) {
            onPick(picked);
          }
        },
        child: Text(
          date == null
              ? label
              : DateFormat('dd/MM/yyyy').format(date),
        ),
      ),
    );
  }
}
