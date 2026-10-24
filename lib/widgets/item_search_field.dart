import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/restaurant_report_item_model.dart';
import '../providers/restaurant_stock_provider.dart';

/// Autocomplete search field for selecting a restaurant stock item.
class ItemSearchField extends StatefulWidget {
  const ItemSearchField({
    super.key,
    required this.selectedItem,
    required this.onItemSelected,
    required this.onCreateNew,
    this.initialQuery = '',
  });

  final RestaurantItemModel? selectedItem;
  final ValueChanged<RestaurantItemModel?> onItemSelected;
  final ValueChanged<String> onCreateNew;
  final String initialQuery;

  @override
  State<ItemSearchField> createState() => _ItemSearchFieldState();
}

class _ItemSearchFieldState extends State<ItemSearchField> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.selectedItem?.name ?? widget.initialQuery,
    );
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant ItemSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedItem?.id != oldWidget.selectedItem?.id) {
      _controller.text = widget.selectedItem?.name ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    setState(() => _showSuggestions = true);
    if (widget.selectedItem != null &&
        query.trim() != widget.selectedItem!.name) {
      widget.onItemSelected(null);
    }
  }

  void _clearSelection() {
    _controller.clear();
    _focusNode.requestFocus();
    setState(() => _showSuggestions = false);
    widget.onItemSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RestaurantStockProvider>();
    final query = _controller.text;
    final suggestions = provider.searchItemsForAutocomplete(query);
    final hasQuery = query.trim().isNotEmpty;
    final selected = widget.selectedItem;
    final isSelected = selected != null && selected.id.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Item',
            hintText: 'Search item...',
            border: const OutlineInputBorder(),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear item selection',
                    onPressed: _clearSelection,
                    icon: Icon(
                      isSelected ? Icons.close : Icons.clear,
                      color: isSelected
                          ? const Color(0xFF1B5E3B)
                          : Colors.black54,
                    ),
                  ),
          ),
          onChanged: _onQueryChanged,
          onTap: () => setState(() => _showSuggestions = true),
        ),
        if (_showSuggestions && hasQuery && !isSelected) ...[
          const SizedBox(height: 4),
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: suggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'No matching item found',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () {
                              setState(() => _showSuggestions = false);
                              widget.onCreateNew(query.trim());
                            },
                            icon: const Icon(Icons.add),
                            label: Text('Create "${query.trim()}"'),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = suggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text(item.name),
                          subtitle: item.category.isNotEmpty
                              ? Text(item.category)
                              : null,
                          onTap: () {
                            _controller.text = item.name;
                            setState(() => _showSuggestions = false);
                            _focusNode.unfocus();
                            widget.onItemSelected(item);
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ],
    );
  }
}
