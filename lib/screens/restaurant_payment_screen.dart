import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Restaurant payment screen — isolated from Homestay PaymentScreen.
/// Staff can record a payment once; admins can edit it afterward.
class RestaurantPaymentScreen extends StatefulWidget {
  const RestaurantPaymentScreen({super.key});

  @override
  State<RestaurantPaymentScreen> createState() =>
      _RestaurantPaymentScreenState();
}

class _RestaurantPaymentScreenState extends State<RestaurantPaymentScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> data = {};
  bool _initialized = false;
  bool _saving = false;
  bool hasPayment = false;
  String role = 'staff';

  final gpayCtrl = TextEditingController(text: '0');
  final cashCtrl = TextEditingController(text: '0');
  final accountCtrl = TextEditingController(text: '0');
  final paymentRecordedByCtrl = TextEditingController();

  DateTime paymentDate = DateTime.now();

  int _toInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.round();
    return int.tryParse(v.toString()) ?? fallback;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    try {
      final dynamic date = value.toDate();
      return date is DateTime ? date : null;
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    data = Map<String, dynamic>.from(
      ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>,
    );
    role = (data['role'] ?? 'staff').toString().trim().toLowerCase();

    final payment = data['payment'];
    if (payment is Map) {
      hasPayment = true;
      gpayCtrl.text = _toInt(payment['gpay']).toString();
      cashCtrl.text = _toInt(payment['cash']).toString();
      accountCtrl.text = _toInt(payment['account']).toString();
      paymentRecordedByCtrl.text =
          payment['paymentRecordedBy']?.toString() ?? '';
      paymentDate = _parseDate(payment['paymentDate']) ??
          _parseDate(payment['updatedAt']) ??
          DateTime.now();
    } else {
      paymentDate = DateTime.now();
    }
  }

  bool get canEdit => role == 'admin' || !hasPayment;

  int get itemsTotal => _toInt(data['itemsTotal'] ?? data['grandTotal']);
  int get discount => _toInt(data['discount']);
  int get grandTotal => _toInt(data['grandTotal']);
  int get balance => grandTotal;

  int get paidAmount =>
      _toInt(gpayCtrl.text) +
      _toInt(cashCtrl.text) +
      _toInt(accountCtrl.text);

  Future<void> _savePayment() async {
    if (!canEdit) return;

    if (paymentRecordedByCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Recorded By is required')),
      );
      return;
    }

    setState(() => _saving = true);

    final billId = data['billId'];
    final selectedDate = DateTime(
      paymentDate.year,
      paymentDate.month,
      paymentDate.day,
    );

    final paymentData = {
      'gpay': _toInt(gpayCtrl.text),
      'cash': _toInt(cashCtrl.text),
      'account': _toInt(accountCtrl.text),
      'paidAmount': paidAmount,
      'paymentRecordedBy': paymentRecordedByCtrl.text.trim(),
      'paymentDate': Timestamp.fromDate(selectedDate),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final billRef = _db.collection('restaurant_bills').doc('$billId');
      await _db.runTransaction((transaction) async {
        final billSnapshot = await transaction.get(billRef);
        if (!billSnapshot.exists) {
          throw StateError('This restaurant bill no longer exists.');
        }

        final existingPayment = billSnapshot.data()?['payment'];
        if (role != 'admin' && existingPayment != null) {
          throw StateError(
            'This payment has already been saved. Only an admin can edit it.',
          );
        }

        transaction.update(billRef, {'payment': paymentData});
      });

      if (!mounted) return;
      setState(() {
        _saving = false;
        hasPayment = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment saved successfully')),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StateError
                ? error.message.toString()
                : 'Could not save payment. Please try again.',
          ),
        ),
      );
    }
  }

  Future<void> _pickPaymentDate() async {
    if (!canEdit) return;
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: paymentDate,
    );
    if (selected != null) setState(() => paymentDate = selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restaurant Payment')),
      bottomNavigationBar: canEdit
          ? Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _savePayment,
                  child: Text(_saving ? 'Saving...' : 'Save Payment'),
                ),
              ),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '₹$balance',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _row('Items Total', itemsTotal),
            if (discount > 0) _row('Discount', discount),
            const Divider(),
            _row('Grand Total', grandTotal, bold: true),
            const SizedBox(height: 20),
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Payment is locked after saving. Only an admin can edit it.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            _paymentField('Google Pay', gpayCtrl),
            _paymentField('Cash', cashCtrl),
            _paymentField('Account', accountCtrl),
            const SizedBox(height: 16),
            TextField(
              controller: paymentRecordedByCtrl,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Payment Recorded By *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Payment Date',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('dd/MM/yyyy').format(paymentDate),
                      style: TextStyle(
                        color: canEdit ? null : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: canEdit ? 'Change date' : 'Date locked',
                    icon: Icon(
                      Icons.calendar_today_outlined,
                      color: canEdit ? null : Colors.grey,
                    ),
                    onPressed: canEdit ? _pickPaymentDate : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Paid Amount',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text('₹$paidAmount',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, int value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text('₹$value',
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _paymentField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 3,
            child: TextField(
              controller: ctrl,
              enabled: canEdit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: '0',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    gpayCtrl.dispose();
    cashCtrl.dispose();
    accountCtrl.dispose();
    paymentRecordedByCtrl.dispose();
    super.dispose();
  }
}
