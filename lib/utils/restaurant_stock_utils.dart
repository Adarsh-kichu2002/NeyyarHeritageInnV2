import 'package:intl/intl.dart';

/// Normalises item names for fallback matching when masterItemId is absent.
String normalizeItemName(String name) {
  return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

bool isWithinDateRange(
  DateTime date, {
  DateTime? from,
  DateTime? to,
}) {
  if (from != null) {
    final start = DateTime(from.year, from.month, from.day);
    if (date.isBefore(start)) return false;
  }
  if (to != null) {
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59, 999);
    if (date.isAfter(end)) return false;
  }
  return true;
}

bool matchesItemSearch(String itemName, String query) {
  final q = normalizeItemName(query);
  if (q.isEmpty) return true;
  final name = normalizeItemName(itemName);
  return name.contains(q);
}

List<T> searchItems<T>(
  List<T> items,
  String query,
  String Function(T) nameSelector,
) {
  final q = query.trim();
  if (q.isEmpty) return items;
  return items
      .where((item) => matchesItemSearch(nameSelector(item), q))
      .toList();
}

String formatReportDate(DateTime date) {
  return DateFormat('dd MMM yyyy').format(date);
}

String formatReportDateTime(DateTime date) {
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}

String formatReportDay(DateTime date) {
  return DateFormat('EEEE, dd MMM yyyy').format(date);
}

String formatReportLongDate(DateTime date) {
  return DateFormat('EEEE d MMM yyyy').format(date);
}

String formatInputDate(DateTime date) {
  return DateFormat('dd/MM/yyyy').format(date);
}
