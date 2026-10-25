import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_report_row.dart';
import '../providers/restaurant_stock_provider.dart';
import '../utils/restaurant_stock_utils.dart';
import '../widgets/stock_filter_dialog.dart';
import 'add_stock_screen.dart';
import 'stock_history_screen.dart';

/// Admin-only restaurant stock management and date-wise reporting.
class RestaurantReportsScreen extends StatefulWidget {
  const RestaurantReportsScreen({super.key});

  @override
  State<RestaurantReportsScreen> createState() =>
      _RestaurantReportsScreenState();
}

class _RestaurantReportsScreenState extends State<RestaurantReportsScreen> {
  String role = 'staff';
  bool _initialized = false;
  bool _accessDenied = false;
  final _searchCtrl = TextEditingController();
  RestaurantStockProvider? _stockProvider;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final stockProvider = context.read<RestaurantStockProvider>();
    _stockProvider = stockProvider;
    stockProvider
      ..resetReportView()
      ..startListening();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    role = (args?['role'] ?? 'staff').toString();
    if (role != 'admin') {
      _accessDenied = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Restaurant Reports is available to admin only.'),
          ),
        );
        Navigator.pop(context);
      });
    }
  }

  void _onSearchChanged() {
    context.read<RestaurantStockProvider>().setSearchQuery(_searchCtrl.text);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    context.read<RestaurantStockProvider>().setSearchQuery('');
  }

  @override
  void dispose() {
    final stockProvider = _stockProvider;
    if (stockProvider != null) {
      stockProvider.stopListening();
      stockProvider.resetReportView();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openFilter() async {
    final provider = context.read<RestaurantStockProvider>();
    final result = await showStockFilterDialog(
      context,
      initial: StockFilterValues(
        itemQuery: provider.filterItemQuery,
        from: provider.fromDate,
        to: provider.toDate,
      ),
      itemNames: provider.activeItems.map((item) => item.name).toList(),
    );
    if (result == null || !mounted) return;
    provider.applyFilters(
      itemQuery: result.itemQuery,
      from: result.from,
      to: result.to,
    );
  }

  Future<void> _openAddStock() async {
    await openAddStockScreen(context);
  }

  String _dateFilterLabel(RestaurantStockProvider provider) {
    final from = provider.fromDate;
    final to = provider.toDate;
    if (from == null && to == null) return 'All';
    if (from != null && to != null) {
      final today = DateTime.now();
      final isTodayRange = from.year == today.year &&
          from.month == today.month &&
          from.day == today.day &&
          to.year == today.year &&
          to.month == today.month &&
          to.day == today.day;
      if (isTodayRange) return 'Today';
      return 'From ${formatReportLongDate(from)} to ${formatReportLongDate(to)}';
    }
    if (from != null) return 'From ${formatReportLongDate(from)}';
    return 'To ${formatReportLongDate(to!)}';
  }

  Future<void> _openHistory(BuildContext context, StockReportRow row) async {
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => StockHistoryScreen(row: row)),
    );
    if (mounted) _clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final provider = context.watch<RestaurantStockProvider>();
    final rows = provider.visibleReportRows;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: const Text('Restaurant Reports'),
        actions: [
          IconButton(
            tooltip: 'Filter by item and date',
            icon: Badge(
              isLabelVisible: provider.hasActiveFilters,
              smallSize: 8,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilter,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddStock,
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: provider.isLoading || provider.errorMessage != null
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Color(0xFFD7EEDC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        color: Color(0xFF1B5E3B)),
                    const SizedBox(width: 8),
                    Text(
                      'Total Items: ${rows.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B5E3B),
                      ),
                    ),
                    const Spacer(),
                    const Text('Tap an item for details'),
                  ],
                ),
              ),
            ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear search',
                                  onPressed: _clearSearch,
                                  icon: const Icon(Icons.clear),
                                ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _dateFilterLabel(provider),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7C72),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: rows.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No items have stock or sales activity in this date range.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF1B5E3B),
                                  ),
                                ),
                              ),
                            )
                          : _StockReportList(
                              rows: rows,
                              onOpenItem: _openHistory,
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _StockReportList extends StatelessWidget {
  const _StockReportList({required this.rows, required this.onOpenItem});

  final List<StockReportRow> rows;
  final Future<void> Function(BuildContext, StockReportRow) onOpenItem;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return _StockReportCard(
          row: row,
          onTap: () => onOpenItem(context, row),
        );
      },
    );
  }
}

class _StockReportCard extends StatelessWidget {
  const _StockReportCard({required this.row, required this.onTap});

  final StockReportRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  color: Color(0xFF2E7D4F)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.item.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Added: ${row.totalAdded} ${row.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sold: ${row.totalSold} ${row.unit}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Balance: ${row.balance} ${row.unit}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: row.balance < 0
                            ? Colors.red.shade700
                            : const Color(0xFF1B5E3B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF6B7C72)),
            ],
          ),
        ),
      ),
    );
  }
}
