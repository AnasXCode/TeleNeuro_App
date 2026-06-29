import 'package:flutter/material.dart';

/// Searchable single-select dropdown for sign-up forms.
class SearchableDropdownField extends StatelessWidget {
  final String? value;
  final List<String> options;
  final String hintText;
  final IconData icon;
  final Color accentColor;
  final ValueChanged<String> onSelected;

  const SearchableDropdownField({
    super.key,
    required this.value,
    required this.options,
    required this.hintText,
    required this.icon,
    required this.accentColor,
    required this.onSelected,
  });

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SearchablePickerSheet(
        options: options,
        initialValue: value,
        hintText: hintText,
        accentColor: accentColor,
      ),
    );

    if (selected != null) {
      onSelected(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value ?? hintText,
                  style: TextStyle(
                    fontSize: 15,
                    color: value == null ? Colors.grey.shade600 : Colors.black87,
                    fontWeight: value == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.search, color: accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchablePickerSheet extends StatefulWidget {
  final List<String> options;
  final String? initialValue;
  final String hintText;
  final Color accentColor;

  const _SearchablePickerSheet({
    required this.options,
    required this.initialValue,
    required this.hintText,
    required this.accentColor,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_query.trim().isEmpty) return widget.options;
    final q = _query.toLowerCase();
    return widget.options.where((o) => o.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(
                widget.hintText,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: Icon(Icons.search, color: widget.accentColor),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matches found', style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final option = _filtered[index];
                        final selected = option == widget.initialValue;
                        return ListTile(
                          title: Text(
                            option,
                            style: TextStyle(
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? widget.accentColor : Colors.black87,
                            ),
                          ),
                          trailing: selected
                              ? Icon(Icons.check_circle, color: widget.accentColor)
                              : null,
                          onTap: () => Navigator.pop(context, option),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
