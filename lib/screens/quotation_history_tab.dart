import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:neyyar_heritage/history/bill_history_store.dart';
import 'package:neyyar_heritage/history/confirm_store.dart';
import 'package:neyyar_heritage/utils/advance_payment_utils.dart';
import 'package:neyyar_heritage/widgets/advance_payments_dialog.dart';
import 'package:provider/provider.dart';
import '../history/quotation_history_store.dart';

class QuotationHistoryTab extends StatefulWidget {
  const QuotationHistoryTab({
    super.key,
    this.customerName = '',
    this.from,
    this.to,
    this.bottomInset = 0,
  });

  final String customerName;
  final DateTime? from;
  final DateTime? to;

  /// Scroll-only clearance for a parent floating nav (not structural padding).
  final double bottomInset;

  @override
  State<QuotationHistoryTab> createState() =>
      _QuotationHistoryTabState();
}

class _QuotationHistoryTabState
    extends State<QuotationHistoryTab> {
  @override
  Widget build(BuildContext context) {
    final store =
        context.watch<QuotationHistoryStore>();
    final confirmStore =
        context.watch<ConfirmStore>();
    final billStore = context.watch<BillHistoryStore>();

    if (store.isLoading) {
      return const Center(
          child: CircularProgressIndicator());
    }

    final nameQuery = widget.customerName.trim().toLowerCase();
    final hasDateFilter = widget.from != null || widget.to != null;
    final hasNameFilter = nameQuery.isNotEmpty;

    final filtered = store.quotations.where((q) {
      final DateTime? checkIn = _asDate(q['checkInDate']);
      if (checkIn == null) return false;

      if (widget.from != null &&
          checkIn.isBefore(_startOfDay(widget.from!))) {
        return false;
      }
      if (widget.to != null &&
          checkIn.isAfter(_endOfDay(widget.to!))) {
        return false;
      }
      if (hasNameFilter) {
        final name = (q['customerName'] ?? '').toString().toLowerCase();
        if (!name.contains(nameQuery)) return false;
      }

      // Date / name search bypasses the 30-day UI hide rule.
      if (hasDateFilter || hasNameFilter) return true;

      final quotationId = q['id']?.toString() ?? '';
      final isConfirmed = confirmStore.isConfirmed(quotationId);
      return _isWithinUiRetention(q, isConfirmed: isConfirmed);
    }).toList();

    return Column(
      children: [
        /// TABLE
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                      'No quotations found'))
              : SingleChildScrollView(
                  scrollDirection:
                      Axis.vertical,
                  padding: EdgeInsets.only(
                    bottom: widget.bottomInset,
                  ),
                  child:
                      SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(
                            label: SizedBox()),
                        DataColumn(
                            label: Text('SI')),    
                        DataColumn(
                            label: Text('Guest')),
                        DataColumn(
                            label: Text('Phone')),
                        DataColumn(
                            label: Text('Package')),
                        DataColumn(
                            label:
                                Text('Check In')),
                        DataColumn(
                            label:
                                Text('Check Out')),
                        DataColumn(
                            label:
                                Text('Actions')),
                      ],
                      rows: List.generate(filtered.length, (i) {
  final q = filtered[i];
  final String quotationId = q['id'];

  final bool isConfirmed =
      confirmStore.isConfirmed(quotationId);

  final bool isCompleted = _isCompleted(q, isConfirmed: isConfirmed);
  final confirmed = confirmStore.confirmedByQuotationId(quotationId);
  final bool billGenerated = _isBillGenerated(
    quotation: q,
    confirmed: confirmed,
    bills: billStore.bills,
  );

  final DateTime? checkIn = _asDate(q['checkInDate']);
  final DateTime? checkOut = _asDate(q['checkOutDate']);

  void onConfirmedRowTap() {
    if (!isConfirmed) return;
    if (billGenerated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill already generated')),
      );
      return;
    }
    _showConfirmedBookingActions(
      context,
      quotation: q,
      quotationId: quotationId,
      confirmStore: confirmStore,
    );
  }

  return DataRow(
    color: WidgetStateProperty.resolveWith<Color?>(
      (states) {
        if (isConfirmed) {
          return Colors.yellow.shade700;
        }
        if (isCompleted) {
          return Colors.blue.shade200;
        }
        return null;
      },
    ),
    cells: [
      /// CHECKBOX
      DataCell(
        GestureDetector(
          onTap: isCompleted
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Already completed.')),
                  );
                }
              : null,
          child: Checkbox(
            value: isConfirmed || isCompleted,
            activeColor: Colors.green,
            onChanged: isConfirmed || isCompleted
                ? null
                : (value) async {
                    if (value != true) return;

                    final payments = await AdvancePaymentsDialog.show(
                      context,
                      title: 'Record advance payment',
                      quotation: q,
                    );
                    if (payments == null || !context.mounted) return;

                    try {
                      await _saveAdvancePayments(
                        context,
                        quotationId: quotationId,
                        quotation: q,
                        payments: payments,
                        confirmStore: confirmStore,
                        isNewConfirmation: true,
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not confirm: $e')),
                      );
                    }
                  },
          ),
        ),
      ),

      DataCell(Text('${i + 1}'), onTap: isConfirmed ? onConfirmedRowTap : null),
      DataCell(Text(q['customerName'] ?? ''), onTap: isConfirmed ? onConfirmedRowTap : null),
      DataCell(Text(q['phone1'] ?? ''), onTap: isConfirmed ? onConfirmedRowTap : null),
      DataCell(Text(q['package'] ?? ''), onTap: isConfirmed ? onConfirmedRowTap : null),
      DataCell(Text(checkIn != null
          ? DateFormat('dd/MM/yyyy').format(checkIn)
          : ''), onTap: isConfirmed ? onConfirmedRowTap : null),
      DataCell(Text(checkOut != null
          ? DateFormat('dd/MM/yyyy').format(checkOut)
          : ''), onTap: isConfirmed ? onConfirmedRowTap : null),

      /// ACTIONS
      DataCell(
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.visibility,
                  color: Colors.green),
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/quotation_preview_screen',
                  arguments: {
                    ...q,
                    'isViewOnly': true,
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit,
                  color: Colors.blue),
              onPressed: () {
                if (billGenerated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill already generated')),
                  );
                  return;
                }
                Navigator.pushNamed(
                  context,
                  '/create_quotation',
                  arguments: {
                    ...q,
                    'quotationId': quotationId,
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete,
                  color: Colors.red),
              onPressed: () {
                if (billGenerated) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Bill already generated')),
                  );
                  return;
                }
                _confirmDelete(context, quotationId);
              },
            ),
          ],
        ),
      ),
    ],
  );
}),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _saveAdvancePayments(
    BuildContext context, {
    required String quotationId,
    required Map<String, dynamic> quotation,
    required List<Map<String, dynamic>> payments,
    required ConfirmStore confirmStore,
    required bool isNewConfirmation,
  }) async {
    final memoryFields = AdvancePaymentUtils.parentFieldsInMemory(payments);
    final firestoreFields = AdvancePaymentUtils.parentFieldsFromPayments(payments);
    final lastDate =
        AdvancePaymentUtils.parseDate(memoryFields['advancePaymentDate']) ??
            DateTime.now();

    await context.read<QuotationHistoryStore>().updateQuotation(
      quotationId,
      firestoreFields,
    );

    if (!context.mounted) return;

    if (isNewConfirmation) {
      await confirmStore.confirmQuotation(
        {
          ...quotation,
          ...memoryFields,
        },
        advancePaymentMode:
            memoryFields['advancePaymentMode']?.toString() ?? 'Cash',
        advanceRecordedBy:
            memoryFields['advanceRecordedBy']?.toString() ?? 'Admin',
        advancePaymentDate: lastDate,
        advancePayments: payments,
      );
      return;
    }

    await confirmStore.syncAfterQuotationUpdate({
      'id': quotationId,
      ...quotation,
      ...memoryFields,
    });
  }

  Future<void> _showConfirmedBookingActions(
    BuildContext context, {
    required Map<String, dynamic> quotation,
    required String quotationId,
    required ConfirmStore confirmStore,
  }) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Do you want to?'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, 'edit'),
            child: const Text('Edit'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            child: const Text('Cancel Booking'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (!context.mounted || action == null) return;

    if (action == 'edit') {
      final confirmed = confirmStore.confirmedByQuotationId(quotationId);
      final payments = await AdvancePaymentsDialog.show(
        context,
        title: 'Edit advance payments',
        confirmLabel: 'Save',
        quotation: quotation,
        confirmedRecord: confirmed,
      );
      if (payments == null || !context.mounted) return;

      try {
        await _saveAdvancePayments(
          context,
          quotationId: quotationId,
          quotation: quotation,
          payments: payments,
          confirmStore: confirmStore,
          isNewConfirmation: false,
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking updated')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update booking: $e')),
        );
      }
      return;
    }

    if (action == 'cancel') {
      await confirmStore.removeByOriginalId(quotationId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking cancelled')),
      );
    }
  }

  bool _isCompleted(
    Map<String, dynamic> q, {
    required bool isConfirmed,
  }) {
    if (isConfirmed) return false;

    final checkOut = _asDate(q['checkOutDate']);
    final advance = _toNum(q['advance']);
    final wasConfirmed = q['advancePaymentMode'] != null || advance >= 1;
    if (!wasConfirmed || checkOut == null) return false;

    final today = _dateOnly(DateTime.now());
    final checkoutDay = _dateOnly(checkOut);
    return today.isAfter(checkoutDay);
  }

  bool _isBillGenerated({
    required Map<String, dynamic> quotation,
    required Map<String, dynamic>? confirmed,
    required List<Map<String, dynamic>> bills,
  }) {
    final source = confirmed ?? quotation;
    if (source['billGenerated'] == true) return true;
    final existingBillId = source['billId']?.toString();
    if (existingBillId != null && existingBillId.isNotEmpty) return true;

    final quotationId = quotation['id']?.toString();
    final confirmId = confirmed?['confirmId']?.toString();

    for (final bill in bills) {
      final billId = bill['billId']?.toString();
      if (billId == null || billId.isEmpty) continue;

      if (confirmId != null &&
          confirmId.isNotEmpty &&
          bill['confirmId']?.toString() == confirmId) {
        return true;
      }
      if (quotationId != null &&
          quotationId.isNotEmpty &&
          bill['originalQuotationId']?.toString() == quotationId) {
        return true;
      }

      final sameCustomer =
          _sameText(bill['customerName'], quotation['customerName']) &&
              _sameText(bill['phone1'], quotation['phone1']);
      final sameStay =
          _sameDate(bill['checkInDate'], quotation['checkInDate']) &&
              _sameDate(bill['checkOutDate'], quotation['checkOutDate']);
      if (sameCustomer && sameStay) return true;
    }

    return false;
  }

  bool _sameText(dynamic a, dynamic b) {
    final left = a?.toString().trim().toLowerCase();
    final right = b?.toString().trim().toLowerCase();
    return left != null && left.isNotEmpty && left == right;
  }

  bool _sameDate(dynamic a, dynamic b) {
    final left = _asDate(a);
    final right = _asDate(b);
    if (left == null || right == null) return false;
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  Future<void> _confirmDelete(
      BuildContext context,
      String quotationId) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
        title: const Text(
            'Delete Quotation'),
        content: const Text(
            'Are you sure you want to delete this quotation?'),
        actions: [
          TextButton(
            child:
                const Text('No'),
            onPressed: () =>
                Navigator.pop(
                    context,
                    false),
          ),
          ElevatedButton(
            child:
                const Text('Yes'),
            onPressed: () =>
                Navigator.pop(
                    context,
                    true),
          ),
        ],
      ),
    );

   if (confirmed == true && context.mounted) {

  await context
      .read<QuotationHistoryStore>()
      .deleteQuotation(quotationId);

  await context
      .read<ConfirmStore>()
      .removeByOriginalId(quotationId);
}
  }

  /// Hide from UI after 30 days (DB unchanged).
  /// Confirmed: no 30-day rule until after checkout, then 30 days from checkout.
  /// Unconfirmed: 30 days from createdAt (fallback check-in).
  bool _isWithinUiRetention(
    Map<String, dynamic> q, {
    required bool isConfirmed,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final checkOut = _asDate(q['checkOutDate']);
    final advance = _toNum(q['advance']);
    final wasConfirmed = isConfirmed ||
        q['advancePaymentMode'] != null ||
        advance >= 1;

    if (isConfirmed) {
      return true;
    }

    if (wasConfirmed && checkOut != null) {
      final checkoutDay =
          DateTime(checkOut.year, checkOut.month, checkOut.day);
      if (!today.isAfter(checkoutDay)) return true;
      final hideAfter = checkoutDay.add(const Duration(days: 30));
      return !today.isAfter(hideAfter);
    }

    final created =
        _asDate(q['createdAt']) ?? _asDate(q['checkInDate']);
    if (created == null) return true;

    final createdDay =
        DateTime(created.year, created.month, created.day);
    final hideAfter = createdDay.add(const Duration(days: 30));
    return !today.isAfter(hideAfter);
  }

  DateTime? _asDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      // Firestore Timestamp / anything with toDate()
      final dynamic date = value.toDate();
      if (date is DateTime) return date;
    } catch (_) {}
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  num _toNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime _startOfDay(
          DateTime d) =>
      DateTime(
          d.year,
          d.month,
          d.day);

  DateTime _endOfDay(
          DateTime d) =>
      DateTime(
          d.year,
          d.month,
          d.day,
          23,
          59,
          59);

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
