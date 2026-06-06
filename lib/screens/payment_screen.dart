import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Map<String, dynamic> data = {};
  bool _initialized = false;
  bool _saving = false;

  /// 🔥 MODE FLAGS
  bool isReadOnly = false;
  bool hasPayment = false;

  /// Payment Controllers
  final gpayCtrl = TextEditingController(text: '0');
  final cashCtrl = TextEditingController(text: '0');
  final accountCtrl = TextEditingController(text: '0');
  final paymentRecordedByCtrl = TextEditingController();

  int _toInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    data = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    /// 🔥 FLAGS
    isReadOnly = data['isReadOnlyPayment'] == true;
    hasPayment = data['payment'] != null;

    /// LOAD EXISTING PAYMENT
    if (hasPayment) {
      final payment = data['payment'];

      gpayCtrl.text = _toInt(payment['gpay']).toString();
      cashCtrl.text = _toInt(payment['cash']).toString();
      accountCtrl.text = _toInt(payment['account']).toString();
      paymentRecordedByCtrl.text =
      payment['paymentRecordedBy']?.toString() ?? '';

    }
  }

  /// =========================
  /// 🔥 MAIN LOGIC
  /// =========================

  bool get canEdit {
    if (!hasPayment) return true;      // First time
    if (!isReadOnly) return true;      // From history screen
    return false;                      // Bills screen after save
  }

  /// =========================
  /// CALCULATIONS
  /// =========================

  int get total => _toInt(data['subtotal']);
  int get gst => _toInt(data['gst']);
  int get advance => _toInt(data['advance']);
  int get discount => _toInt(data['discount']);
  int get balance => _toInt(data['balance']);

  int get paidAmount =>
      _toInt(gpayCtrl.text) +
      _toInt(cashCtrl.text) +
      _toInt(accountCtrl.text);

  bool get isValid => paidAmount == balance;

  /// =========================
  /// SAVE PAYMENT
  /// =========================
  Future<void> _savePayment() async {
    // if (!isValid) {
     // ScaffoldMessenger.of(context).showSnackBar(
     // const SnackBar(content: Text('Enter correct amount')),
     // );
      // return;
   // }
     if (paymentRecordedByCtrl.text.trim().isEmpty) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Payment Recorded By is required'),
    ),
  );
  return;
}
    setState(() => _saving = true);

    final billId = data['billId'];

    final paymentData = {
      'gpay': _toInt(gpayCtrl.text),
      'cash': _toInt(cashCtrl.text),
      'account': _toInt(accountCtrl.text),
      'paidAmount': paidAmount,
      'paymentRecordedBy': paymentRecordedByCtrl.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('bills').doc(billId).set({
      'payment': paymentData,
    }, SetOptions(merge: true));

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment saved successfully')),
    );

    Navigator.pop(context);
  }

  /// =========================
  /// UI
  /// =========================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),

      /// 🔽 SAVE BUTTON
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_saving || !canEdit) ? null : _savePayment,
            child: Text(_saving ? 'Saving...' : 'Save Payment'),
          ),
        ),
      ),

      /// 🔽 CONTENT
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            /// 🔝 TOTAL
            Text(
              '₹$balance',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            /// SUMMARY
            _row('Total', total),
            _row('GST', gst),
            _row('Advance', advance),
            _row('Discount', discount),
            const Divider(),
            _row('Balance', balance, bold: true),

            const SizedBox(height: 20),

            /// 🔒 LOCK MESSAGE
            if (!canEdit)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Admin has locked this bill. Contact admin to edit.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            /// INPUTS
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

            /// VALIDATION
            // Align(
             // alignment: Alignment.centerRight,
             // child: Text(
              //  'Entered: ₹$paidAmount',
               // style: TextStyle(
                //  color: isValid ? Colors.green : Colors.red,
                //  fontWeight: FontWeight.bold,
               // ),
             // ),
           // ),

            //if (!isValid)
              // const Align(
               // alignment: Alignment.centerRight,
               // child: Text(
                //  '⚠ Enter correct amount',
                 // style: TextStyle(color: Colors.red),
               // ),
             // ),
          ],
        ),
      ),
    );
  }

  /// =========================
  /// HELPERS
  /// =========================

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
              enabled: canEdit, // 🔥 KEY FIX
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
