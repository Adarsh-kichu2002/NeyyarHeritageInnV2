import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/restaurant_bill_service.dart';

/// Screen 1 — Restaurant customer details (isolated from Homestay bill).
class RestaurantCustomerScreen extends StatefulWidget {
  const RestaurantCustomerScreen({super.key});

  @override
  State<RestaurantCustomerScreen> createState() =>
      _RestaurantCustomerScreenState();
}

class _RestaurantCustomerScreenState extends State<RestaurantCustomerScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _invoiceCtrl = TextEditingController();

  String role = 'staff';
  bool _initialized = false;
  bool _loadingInvoice = true;
  bool isEdit = false;
  Map<String, dynamic> _args = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _args = Map<String, dynamic>.from(args ?? {});
    role = (_args['role'] ?? 'staff').toString();
    isEdit = _args['isEdit'] == true;

    _nameCtrl.text = (_args['customerName'] ?? '').toString();
    _phoneCtrl.text = (_args['phoneNumber'] ?? '').toString();
    _addressCtrl.text = (_args['address'] ?? '').toString();
    _gstCtrl.text = (_args['gstNumber'] ?? '').toString();
    final existing =
        (_args['billNumber'] ?? _args['invoiceNumber'] ?? '').toString();
    if (existing.isNotEmpty) {
      _invoiceCtrl.text = existing;
      _loadingInvoice = false;
      return;
    }

    _loadNextInvoice();
  }

  Future<void> _loadNextInvoice() async {
    try {
      final next = await context.read<RestaurantBillStore>().nextBillNumber();
      if (!mounted) return;
      setState(() {
        _invoiceCtrl.text = '$next';
        _loadingInvoice = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _invoiceCtrl.text = '1';
        _loadingInvoice = false;
      });
    }
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

  void _continue() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final gst = _gstCtrl.text.trim();
    final invoiceText = _invoiceCtrl.text.trim();
    final billNumber = int.tryParse(invoiceText);

    if (name.isEmpty || phone.isEmpty || address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, phone and address are required'),
        ),
      );
      return;
    }

    if (billNumber == null || billNumber <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid invoice number')),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      '/restaurant_bill_items',
      arguments: {
        ..._args,
        'role': role,
        'isEdit': isEdit,
        'customerName': name,
        'phoneNumber': phone,
        'address': address,
        'gstNumber': gst,
        'billNumber': billNumber,
        'billId': isEdit && (_args['billId']?.toString().isNotEmpty == true)
            ? _args['billId']
            : DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Restaurant Bill' : 'Restaurant Bill'),
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
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(labelText: 'Phone Number'),
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
                        labelText: 'GST Number',
                        hintText: 'Optional',
                      ),
                    ),
                    TextField(
                      controller: _invoiceCtrl,
                      keyboardType: TextInputType.number,
                      enabled: !_loadingInvoice,
                      decoration: InputDecoration(
                        labelText: 'Invoice Number',
                        hintText: _loadingInvoice ? 'Loading...' : null,
                        suffixIcon: _loadingInvoice
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loadingInvoice ? null : _continue,
                child: const Text('Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
