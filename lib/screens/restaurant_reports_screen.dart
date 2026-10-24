import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/stock_activity_model.dart';
import '../models/stock_entry_model.dart';
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

  Future<void> _openHistory(BuildContext context, StockActivity entry) async {
    final provider = context.read<RestaurantStockProvider>();
    final row = provider.reportRowForItem(entry.itemId);
    if (row == null || !context.mounted) return;
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
    final entries = provider.visibleStockActivities;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: const Text('Restaurant Reports'),
        actions: [
          IconButton(
            tooltip: 'Filter by item, date and time',
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
                      'Total Items: ${entries.map((entry) => entry.itemId).where((id) => id.isNotEmpty).toSet().length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B5E3B),
                      ),
                    ),
                    const Spacer(),
                    Text('${entries.length} activities'),
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
                          hintText: 'Search stock activity...',
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
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Stock activity by date',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1B5E3B),
                              ),
                            ),
                          ),
                          Text('${entries.length} activities'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: entries.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No stock or sales activity matches the current search or filters.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF1B5E3B),
                                  ),
                                ),
                              ),
                            )
                          : _StockActivityTimeline(
                              entries: entries,
                              onOpenItem: _openHistory,
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _StockActivityTimeline extends StatelessWidget {
  const _StockActivityTimeline({required this.entries, required this.onOpenItem});

  final List<StockActivity> entries;
  final Future<void> Function(BuildContext, StockActivity) onOpenItem;

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<StockActivity>>{};
    for (final entry in entries) {
      final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
      (groups[key] ??= []).add(entry);
    }
    final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    final timeline = <Object>[];
    for (final day in days) {
      timeline
        ..add(day)
        ..addAll(groups[day]!);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: timeline.length,
      itemBuilder: (context, index) {
        final item = timeline[index];
        if (item is DateTime) {
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text(
              formatReportDay(item),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B5E3B),
              ),
            ),
          );
        }
        final entry = item as StockActivity;
        return _StockActivityCard(
          entry: entry,
          onTap: () => onOpenItem(context, entry),
        );
      },
    );
  }
}

class _StockActivityCard extends StatelessWidget {
  const _StockActivityCard({required this.entry, required this.onTap});

  final StockActivity entry;
  final VoidCallback onTap;

  Future<void> _edit(BuildContext context) async {
    final stockEntry = entry.stockEntry;
    if (stockEntry == null) return;
    final result = await showDialog<_EditedStockEntry>(
      context: context,
      builder: (_) => _EditStockEntryDialog(entry: stockEntry),
    );
    if (result == null || !context.mounted) return;
    try {
      await context.read<RestaurantStockProvider>().updateStockEntry(
            entry: stockEntry,
            quantity: result.quantity,
            date: result.date,
            note: result.note,
          );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF2E7D4F)),
          title: const Text('Update successful'),
          content: const Text('The stock entry was updated successfully.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update stock entry: $e')),
      );
    }
  }

  Future<void> _delete(BuildContext context) async {
    final stockEntry = entry.stockEntry;
    if (stockEntry == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete stock entry?'),
        content: Text(
          'Delete the ${entry.quantity} ${entry.unit} entry for ${entry.itemName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context
          .read<RestaurantStockProvider>()
          .deleteStockEntry(stockEntry.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete stock entry: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: entry.isSale ? const Color(0xFFFFF0EE) : const Color(0xFFFFF9D9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2, right: 12),
                child: Icon(
                  entry.isSale
                      ? Icons.point_of_sale_outlined
                      : Icons.sticky_note_2_outlined,
                  color: entry.isSale
                      ? const Color(0xFFB4493F)
                      : const Color(0xFF9A7B19),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.itemName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.isSale ? '−' : '+'}${entry.quantity} ${entry.unit}',
                      style: TextStyle(
                        color: entry.isSale ? const Color(0xFFB4493F) : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (entry.note.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(entry.note),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      formatReportDateTime(entry.date),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7C72),
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.stockEntry != null)
                Column(
                  children: [
                    IconButton(
                      tooltip: 'Update stock entry',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _edit(context),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete stock entry',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _delete(context),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red.shade700,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditedStockEntry {
  const _EditedStockEntry(this.quantity, this.date, this.note);
  final int quantity;
  final DateTime date;
  final String note;
}

class _EditStockEntryDialog extends StatefulWidget {
  const _EditStockEntryDialog({required this.entry});
  final StockEntryModel entry;

  @override
  State<_EditStockEntryDialog> createState() => _EditStockEntryDialogState();
}

class _EditStockEntryDialogState extends State<_EditStockEntryDialog> {
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _noteCtrl;
  late DateTime _date;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: '${widget.entry.quantity}');
    _noteCtrl = TextEditingController(text: widget.entry.note);
    _date = widget.entry.date;
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time == null) return;
    setState(() => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ));
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _EditedStockEntry(
        int.parse(_quantityCtrl.text.trim()),
        _date,
        _noteCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Update ${widget.entry.itemName} stock'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
                validator: (value) {
                  final quantity = int.tryParse(value?.trim() ?? '');
                  return quantity == null || quantity <= 0
                      ? 'Enter a quantity greater than 0'
                      : null;
                },
              ),
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.schedule),
                label: Text(formatReportDateTime(_date)),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Update')),
      ],
    );
  }
}
