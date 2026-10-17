import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_report_row.dart';
import '../models/stock_activity_model.dart';
import '../providers/restaurant_stock_provider.dart';
import '../utils/restaurant_stock_utils.dart';
import 'add_stock_screen.dart';

class StockHistoryScreen extends StatelessWidget {
  const StockHistoryScreen({
    super.key,
    required this.row,
  });

  final StockReportRow row;

  static const Color _forest = Color(0xFF1B5E3B);
  static const Color _subtitle = Color(0xFF6B7C72);

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantStockProvider>();
    final entries = provider.stockHistoryForItem(row.item.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(row.item.name),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAddStockScreen(
          context,
          initialItem: row.item,
        ),
        backgroundColor: const Color(0xFF2E7D4F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
      ),
      body: Column(
        children: [
          Expanded(
            child: entries.isEmpty
                ? const Center(
                    child: Text('No stock entries for this item yet.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final entry = entries[i];
                      final isSale = entry.type == StockActivityType.sold;
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        title: Text(
                          '${isSale ? '−' : '+'}${entry.quantity} ${entry.unit}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSale ? Colors.red.shade700 : null,
                          ),
                        ),
                        subtitle: Text(
                          entry.note.isNotEmpty
                              ? entry.note
                              : (isSale ? 'Sold' : 'Stock added'),
                        ),
                        trailing: Text(
                          formatReportDateTime(entry.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _subtitle,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFFD7EEDC),
            padding: const EdgeInsets.all(16),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _totalLine('Total Added', row.totalAdded, row.unit),
                  const SizedBox(height: 4),
                  _totalLine('Sold', row.totalSold, row.unit),
                  const SizedBox(height: 4),
                  _totalLine('Balance', row.balance, row.unit, bold: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalLine(String label, int value, String unit, {bool bold = false}) {
    return Text(
      '$label: $value $unit',
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        color: bold ? _forest : Colors.black87,
        fontSize: bold ? 15 : 13,
      ),
    );
  }
}
