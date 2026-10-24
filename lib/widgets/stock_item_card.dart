import 'package:flutter/material.dart';

import '../models/stock_report_row.dart';

class StockItemCard extends StatelessWidget {
  const StockItemCard({
    super.key,
    required this.row,
    required this.onTap,
  });

  final StockReportRow row;
  final VoidCallback onTap;

  static const Color _forest = Color(0xFF1B5E3B);
  static const Color _subtitle = Color(0xFF6B7C72);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: row.isLowStock
                ? Border.all(color: Colors.orange.shade300, width: 1)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.item.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: _forest,
                        ),
                      ),
                    ),
                    if (row.isLowStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'LOW STOCK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _statRow('Added', row.totalAdded, row.unit),
                const SizedBox(height: 4),
                _statRow('Sold', row.totalSold, row.unit),
                const SizedBox(height: 4),
                _statRow(
                  'Balance',
                  row.balance,
                  row.unit,
                  bold: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, String unit, {bool bold = false}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: _subtitle,
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          '$value $unit',
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: bold ? _forest : Colors.black87,
          ),
        ),
      ],
    );
  }
}
