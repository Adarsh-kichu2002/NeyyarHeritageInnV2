import 'package:flutter/material.dart';
import 'package:neyyar_heritage/screens/bill_history_tab.dart';
import 'package:neyyar_heritage/widgets/list_filter_dialog.dart';
import 'quotation_history_tab.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
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
          return Scaffold(
            appBar: AppBar(
              title: const Text('History'),
              actions: [
                IconButton(
                  tooltip: 'Filter',
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {
                    final index = DefaultTabController.of(context).index;
                    _openFilter(index);
                  },
                ),
              ],
              bottom: const TabBar(
                labelColor: Colors.black,
                unselectedLabelColor: Colors.black54,
                indicatorColor: Colors.black,
                labelStyle: TextStyle(fontWeight: FontWeight.bold),
                tabs: [
                  Tab(text: 'Quotations'),
                  Tab(text: 'Bills'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                QuotationHistoryTab(
                  customerName: _quotationFilter.customerName,
                  from: _quotationFilter.from,
                  to: _quotationFilter.to,
                ),
                BillHistoryTab(
                  customerName: _billFilter.customerName,
                  from: _billFilter.from,
                  to: _billFilter.to,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
