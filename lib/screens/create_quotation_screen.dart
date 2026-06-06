import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CreateQuotationScreen extends StatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  State<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends State<CreateQuotationScreen> {
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic>? editData;
  String? quotationId;
  bool isEdit = false;

  String mode = 'create';
  late Map<String, dynamic> data;

  List<dynamic> rooms = [];
  List<dynamic> facilities = [];

  DateTime? _tsToDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;

    // Firestore Timestamp
    if (value.runtimeType.toString() == 'Timestamp') {
      return value.toDate();
    }

    return null;
  }

  TimeOfDay? _stringToTime(dynamic value) {
    if (value == null) return null;

    if (value is TimeOfDay) return value;

    if (value is String && value.contains(':')) {
      final parts = value.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    return null;
  }

  String _selectedPackage = 'Day Out Package';
  final List<String> _packages = [
    'Day Out Package',
    'Stay Package',
    'Stay',
    'Add New Package',
  ];

  final TextEditingController _customPackageController =
      TextEditingController();

  DateTime? _checkInDate;
  DateTime? _checkOutDate;

  TimeOfDay? _checkInTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay? _checkOutTime = const TimeOfDay(hour: 10, minute: 30);

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phone1Controller = TextEditingController();
  final TextEditingController _phone2Controller = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _adultController = TextEditingController();
  final TextEditingController _childrenController = TextEditingController();
  final TextEditingController _childController = TextEditingController();

  int get totalPax {
    final adult = int.tryParse(_adultController.text) ?? 0;
    final children = int.tryParse(_childrenController.text) ?? 0;
    final child = int.tryParse(_childController.text) ?? 0;

    return adult + children + child;
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = picked;
          if (_selectedPackage == 'Day Out Package') {
            _checkOutDate = picked;
          }
        } else {
          _checkOutDate = picked;
        }
      });
    }
  }

  Future<void> _pickTime({required bool isCheckIn}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        isCheckIn ? _checkInTime = picked : _checkOutTime = picked;
      });
    }
  }

  String _formatDate(DateTime? date) =>
      date == null ? '' : DateFormat('dd MMM yyyy').format(date);

  String _formatTime(TimeOfDay? time) =>
      time == null ? '' : time.format(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (editData != null) return; // prevent duplicate execution

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args != null && args is Map<String, dynamic>) {
      mode = 'edit';
      editData = args;
      quotationId = args['id']; // MUST be original quotation id
      _fillFormForEdit();
    } else {
      mode = 'create';
    }
  }

  void _fillFormForEdit() {
    if (editData == null) return;

    _nameController.text = editData!['customerName'] ?? '';
    _phone1Controller.text = editData!['phone1'] ?? '';
    _phone2Controller.text = editData!['phone2'] ?? '';
    _addressController.text = editData!['address'] ?? '';

    final savedPackage = editData!['package'] ?? '';
    if (_packages.contains(savedPackage)) {
      _selectedPackage = savedPackage;
    } else {
      _selectedPackage = 'Add New Package';
      _customPackageController.text = savedPackage;
    }

    rooms = List.from(editData!['rooms'] ?? []);
    facilities = List.from(editData!['facilities'] ?? []);

    _checkInDate = _tsToDate(editData!['checkInDate']);
    _checkOutDate = _tsToDate(editData!['checkOutDate']);

    _checkInTime = _stringToTime(editData!['checkInTime']);
    _checkOutTime = _stringToTime(editData!['checkOutTime']);

    _adultController.text = editData?['adult']?.toString() ?? '';
    _childrenController.text = editData?['children']?.toString() ?? '';
    _childController.text = editData?['child']?.toString() ?? '';

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(mode == 'edit' ? 'Edit Quotation' : 'Create Quotation'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// PACKAGE DROPDOWN
                DropdownButtonFormField<String>(
                  value: _packages.contains(_selectedPackage)
                      ? _selectedPackage
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Package',
                    border: OutlineInputBorder(),
                  ),
                  items: _packages
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPackage = value!;
                      if (_selectedPackage == 'Day Out Package' &&
                          _checkInDate != null) {
                        _checkOutDate = _checkInDate;
                      }
                    });
                  },
                ),

                if (_selectedPackage == 'Add New Package')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextFormField(
                      controller: _customPackageController,
                      decoration: const InputDecoration(
                        labelText: 'Enter Package Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                /// CHECK IN / OUT
                Row(
                  children: [
                    Expanded(
                      child: _dateTimeBox(
                        label: 'Check In Date',
                        value: _formatDate(_checkInDate),
                        onTap: () => _pickDate(isCheckIn: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateTimeBox(
                        label: 'Check In Time',
                        value: _formatTime(_checkInTime),
                        onTap: () => _pickTime(isCheckIn: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _dateTimeBox(
                        label: 'Check Out Date',
                        value: _formatDate(_checkOutDate),
                        onTap: _selectedPackage == 'Day Out Package'
                            ? null
                            : () => _pickDate(isCheckIn: false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _dateTimeBox(
                        label: 'Check Out Time',
                        value: _formatTime(_checkOutTime),
                        onTap: () => _pickTime(isCheckIn: false),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                /// CUSTOMER DETAILS
                _requiredField(_nameController, 'Customer Name'),
                const SizedBox(height: 12),
                _requiredField(_phone1Controller, 'Phone Number 1'),
                const SizedBox(height: 12),
                _optionalField(_phone2Controller, 'Phone Number 2'),
                const SizedBox(height: 12),
                _optionalField(_addressController, 'Address', maxLines: 3),

                const SizedBox(height: 20),

                /// PAX
                Row(
                  children: [
                    _paxBox(_adultController, 'Adult'),
                    const SizedBox(width: 8),
                    _paxBox(_childrenController, 'Children'),
                    const SizedBox(width: 8),
                    _paxBox(_childController, 'Child'),
                  ],
                ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total Pax: ${_adultController.text}+${_childrenController.text}+${_childController.text} = $totalPax',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                const SizedBox(height: 30),

                /// NEXT BUTTON
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.pushNamed(
                        context,
                        '/room_select_screen',
                        arguments: {
                          'mode': mode,
                          'quotationId': mode == 'edit' ? quotationId : null,
                          'package': _selectedPackage == 'Add New Package'
                              ? _customPackageController.text
                              : _selectedPackage,
                          'checkInDate': _checkInDate,
                          'checkOutDate': _checkOutDate,
                          'checkInTime': _checkInTime,
                          'checkOutTime': _checkOutTime,
                          'customerName': _nameController.text,
                          'phone1': _phone1Controller.text,
                          'phone2': _phone2Controller.text,
                          'address': _addressController.text,
                          'advance': mode == 'edit'
                              ? (editData?['advance'] ?? 0)
                              : 0,
                          'adult': _adultController.text,
                          'children': _childrenController.text,
                          'child': _childController.text,
                          'totalPax': totalPax,
                          'rooms': rooms,
                          'facilities': facilities,
                        },
                      );
                    }
                  },
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateTimeBox({
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(value.isEmpty ? 'Select' : value),
      ),
    );
  }

  Widget _requiredField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      validator: (v) => v!.isEmpty ? 'Required' : null,
      decoration: InputDecoration(
        labelText: '$label *',
        iconColor: Colors.red,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _optionalField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _paxBox(TextEditingController controller, String label) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label, // Adult / Children / Child
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 8,
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
