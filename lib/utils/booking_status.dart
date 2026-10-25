import 'package:flutter/material.dart';

class BookingStatus {
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const postponed = 'postponed';

  static Color? color(String? status) {
    switch (status?.toLowerCase()) {
      case confirmed:
        return Colors.yellow.shade700;
      case completed:
        return Colors.blue.shade200;
      case cancelled:
        return Colors.red.shade200;
      case postponed:
        return Colors.cyan.shade200;
      case 'restaurant_bill':
        return Colors.purple.shade200;
      default:
        return null;
    }
  }
}
