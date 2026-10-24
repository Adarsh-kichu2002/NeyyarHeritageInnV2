import 'package:flutter/material.dart';

import '../models/stock_report_row.dart';

class StockSummary extends StatelessWidget {
  const StockSummary({super.key, required this.summary});

  final StockSummaryData summary;

  static const Color _forest = Color(0xFF1B5E3B);
  static const Color _mint = Color(0xFFD7EEDC);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: SafeArea(
        top: false,
        child: summary.hasMixedUnits
            ? _mixedUnitsSummary()
            : _singleUnitSummary(),
      ),
    );
  }

  Widget _mixedUnitsSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _forest,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Total Items: ${summary.itemCount}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'Items use different units — quantity totals are not combined.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _singleUnitSummary() {
    final unit = summary.commonUnit ?? '';
    return Column(
      children: [
        const Text(
          'Summary',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _forest,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _cell('Total Items', '${summary.itemCount}'),
            _cell('Added', '${summary.totalAdded ?? 0}'),
            _cell('Sold', '${summary.totalSold ?? 0}'),
            _cell('Balance', '${summary.totalBalance ?? 0}'),
          ],
        ),
        if (unit.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Unit: $unit',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ],
    );
  }

  Expanded _cell(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _forest,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
