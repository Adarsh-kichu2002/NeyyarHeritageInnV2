import 'package:cloud_firestore/cloud_firestore.dart';

/// Shared helpers for multiple advance payments (backward compatible).
class AdvancePaymentUtils {
  static const paymentModes = ['GPay', 'Account', 'Cash'];

  static double toAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Read advances from quotation/confirmed map (list or legacy single fields).
  static List<Map<String, dynamic>> paymentsFromRecord(
    Map<String, dynamic> record,
  ) {
    final values = record['advancePayments'];
    if (values is List && values.isNotEmpty) {
      return values.whereType<Map>().map((entry) {
        final paidAt = parseDate(entry['paidAt']) ??
            parseDate(record['advancePaymentDate']) ??
            DateTime.now();
        return {
          'amount': toAmount(entry['amount']),
          'mode': (entry['mode'] ?? record['advancePaymentMode'] ?? 'Cash')
              .toString(),
          'recordedBy':
              (entry['recordedBy'] ?? record['advanceRecordedBy'] ?? '')
                  .toString(),
          'paidAt': dateOnly(paidAt),
        };
      }).where((p) => toAmount(p['amount']) >= 1).toList();
    }

    final amount = toAmount(record['advance']);
    if (amount >= 1) {
      final paidAt = parseDate(record['advancePaymentDate']) ?? DateTime.now();
      return [
        {
          'amount': amount,
          'mode': (record['advancePaymentMode'] ?? 'Cash').toString(),
          'recordedBy': (record['advanceRecordedBy'] ?? '').toString(),
          'paidAt': dateOnly(paidAt),
        },
      ];
    }

    return [
      {
        'amount': 0,
        'mode': paymentModes.first,
        'recordedBy': '',
        'paidAt': dateOnly(DateTime.now()),
      },
    ];
  }

  static double totalAmount(List<Map<String, dynamic>> payments) {
    return payments.fold<double>(
      0,
      (sum, entry) => sum + toAmount(entry['amount']),
    );
  }

  /// Firestore-ready list (Timestamps for dates).
  static List<Map<String, dynamic>> toFirestoreList(
    List<Map<String, dynamic>> payments,
  ) {
    return payments
        .where((entry) => toAmount(entry['amount']) >= 1)
        .map((entry) {
      final paidAt = parseDate(entry['paidAt']) ?? DateTime.now();
      return {
        'amount': toAmount(entry['amount']),
        'mode': entry['mode']?.toString() ?? 'Cash',
        'recordedBy': entry['recordedBy']?.toString() ?? 'Admin',
        'paidAt': Timestamp.fromDate(dateOnly(paidAt)),
      };
    }).toList();
  }

  /// Fields to mirror on quotation / confirmed parent document.
  static Map<String, dynamic> parentFieldsFromPayments(
    List<Map<String, dynamic>> payments,
  ) {
    final cleaned = payments
        .where((entry) => toAmount(entry['amount']) >= 1)
        .toList();
    if (cleaned.isEmpty) {
      return {
        'advance': 0,
        'advancePayments': [],
      };
    }

    final total = totalAmount(cleaned);
    final last = cleaned.last;
    final lastDate = parseDate(last['paidAt']) ?? DateTime.now();

    return {
      'advance': total.round(),
      'advancePayments': toFirestoreList(cleaned),
      'advancePaymentMode': last['mode']?.toString(),
      'advanceRecordedBy': last['recordedBy']?.toString(),
      'advancePaymentDate': Timestamp.fromDate(dateOnly(lastDate)),
    };
  }

  /// In-memory parent fields (DateTime for dates) for store sync.
  static Map<String, dynamic> parentFieldsInMemory(
    List<Map<String, dynamic>> payments,
  ) {
    final cleaned = payments
        .where((entry) => toAmount(entry['amount']) >= 1)
        .toList();
    if (cleaned.isEmpty) return {'advance': 0, 'advancePayments': []};

    final total = totalAmount(cleaned);
    final last = cleaned.last;
    final lastDate = parseDate(last['paidAt']) ?? DateTime.now();

    return {
      'advance': total.round(),
      'advancePayments': cleaned
          .map(
            (entry) => {
              'amount': toAmount(entry['amount']),
              'mode': entry['mode']?.toString(),
              'recordedBy': entry['recordedBy']?.toString(),
              'paidAt': dateOnly(parseDate(entry['paidAt']) ?? DateTime.now()),
            },
          )
          .toList(),
      'advancePaymentMode': last['mode']?.toString(),
      'advanceRecordedBy': last['recordedBy']?.toString(),
      'advancePaymentDate': dateOnly(lastDate),
    };
  }
}
