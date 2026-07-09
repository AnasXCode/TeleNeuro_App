import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/birth_date_utils.dart';

/// Tap-to-select birth date with separate day, month, and year wheels.
class BirthDatePickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Color accentColor;
  final String hintText;

  const BirthDatePickerField({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.accentColor,
    this.hintText = 'Select Date of Birth',
  });

  Future<void> _openPicker(BuildContext context) async {
    final now = DateTime.now();
    final initial = selectedDate ?? DateTime(now.year - 25, now.month, now.day);

    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _BirthDatePickerSheet(
        initialDate: initial,
        accentColor: accentColor,
      ),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = selectedDate == null
        ? hintText
        : BirthDateUtils.formatDisplay(selectedDate!);

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
              Icon(Icons.calendar_today_outlined, color: accentColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    color: selectedDate == null ? Colors.grey.shade600 : Colors.black87,
                    fontWeight: selectedDate == null ? FontWeight.normal : FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _BirthDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final Color accentColor;

  const _BirthDatePickerSheet({
    required this.initialDate,
    required this.accentColor,
  });

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();
    _year = widget.initialDate.year.clamp(BirthDateUtils.minYear, BirthDateUtils.maxYear);
    _month = widget.initialDate.month;
    _day = widget.initialDate.day;
    _normalizeSelection();
  }

  void _normalizeSelection() {
    final months = BirthDateUtils.allowedMonths(_year);
    if (!months.contains(_month)) {
      _month = months.last;
    }
    final days = BirthDateUtils.allowedDays(_year, _month);
    if (!days.contains(_day)) {
      _day = days.last;
    }
  }

  DateTime get _selectedDate => DateTime(_year, _month, _day);

  @override
  Widget build(BuildContext context) {
    final years = List.generate(
      BirthDateUtils.maxYear - BirthDateUtils.minYear + 1,
      (i) => BirthDateUtils.maxYear - i,
    );
    final months = BirthDateUtils.allowedMonths(_year);
    final days = BirthDateUtils.allowedDays(_year, _month);

    return Container(
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
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Select Date of Birth',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.accentColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final date = _selectedDate;
                      final error = BirthDateUtils.validateForSignup(date);
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, date);
                    },
                    child: const Text('Done', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: const [
                  Expanded(child: Center(child: Text('Day', style: TextStyle(fontWeight: FontWeight.w600)))),
                  Expanded(child: Center(child: Text('Month', style: TextStyle(fontWeight: FontWeight.w600)))),
                  Expanded(child: Center(child: Text('Year', style: TextStyle(fontWeight: FontWeight.w600)))),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(
                    child: CupertinoPicker(
                      key: ValueKey('day-$_year-$_month-${days.length}'),
                      scrollController: FixedExtentScrollController(
                        initialItem: days.indexOf(_day).clamp(0, days.length - 1),
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() => _day = days[index]);
                      },
                      children: days
                          .map((d) => Center(child: Text(d.toString().padLeft(2, '0'))))
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      key: ValueKey('month-$_year-${months.length}'),
                      scrollController: FixedExtentScrollController(
                        initialItem: months.indexOf(_month).clamp(0, months.length - 1),
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _month = months[index];
                          _normalizeSelection();
                        });
                      },
                      children: months
                          .map((m) => Center(child: Text(_monthName(m))))
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(
                        initialItem: years.indexOf(_year).clamp(0, years.length - 1),
                      ),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) {
                        setState(() {
                          _year = years[index];
                          _normalizeSelection();
                        });
                      },
                      children: years.map((y) => Center(child: Text('$y'))).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static String _monthName(int month) {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return names[month - 1];
  }
}
