import 'package:flutter/material.dart';
import 'package:neyyar_heritage/screens/bill_history_tab.dart';
import 'package:neyyar_heritage/widgets/list_filter_dialog.dart';
import 'quotation_history_tab.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    this.bottomPadding = 0,
  });

  /// Space reserved for the parent floating nav (Home shell).
  final double bottomPadding;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Color _pageBg = Color(0xFFF4F7F5);

  ListFilterValues _quotationFilter = const ListFilterValues();
  ListFilterValues _billFilter = const ListFilterValues();

  Future<void> _openFilter(int tabIndex) async {
    final current = tabIndex == 0 ? _quotationFilter : _billFilter;
    final result = await showListFilterDialog(context, initial: current);
    if (result == null || !mounted) return;
    setState(() {
      if (tabIndex == 0) {
        _quotationFilter = result;
      } else {
        _billFilter = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          // No nested Scaffold — avoids the white box under the floating nav.
          return ColoredBox(
            color: _pageBg,
            child: Column(
              children: [
                Material(
                  color: _pageBg,
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: kToolbarHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(left: 12),
                                  child: Text(
                                    'History',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Filter',
                                icon: const Icon(
                                  Icons.filter_list,
                                  color: Colors.black,
                                ),
                                onPressed: () {
                                  final index =
                                      DefaultTabController.of(context).index;
                                  _openFilter(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const TabBar(
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: Colors.black,
                        labelStyle: TextStyle(fontWeight: FontWeight.bold),
                        tabs: [
                          Tab(text: 'Quotations'),
                          Tab(text: 'Bills'),
                        ],
                      ),
                    ],
                  ),
                ),
                // Match Home: full-height body; nav clearance is scroll inset only.
                Expanded(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      canvasColor: _pageBg,
                      scaffoldBackgroundColor: _pageBg,
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                        surface: _pageBg,
                      ),
                    ),
                    child: TabBarView(
                      children: [
                        QuotationHistoryTab(
                          customerName: _quotationFilter.customerName,
                          from: _quotationFilter.from,
                          to: _quotationFilter.to,
                          bottomInset: widget.bottomPadding,
                        ),
                        BillHistoryTab(
                          customerName: _billFilter.customerName,
                          from: _billFilter.from,
                          to: _billFilter.to,
                          bottomInset: widget.bottomPadding,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
