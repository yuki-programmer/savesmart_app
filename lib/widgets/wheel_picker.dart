import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class WheelPicker extends StatefulWidget {
  final int unit;
  final int maxMultiplier;
  final Function(int value) onChanged;
  final int initialValue;
  final Color highlightColor;

  const WheelPicker({
    super.key,
    required this.unit,
    this.maxMultiplier = 100,
    required this.onChanged,
    this.initialValue = 0,
    this.highlightColor = AppColors.accentGreenLight,
  });

  @override
  State<WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<WheelPicker> {
  late FixedExtentScrollController _scrollController;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialValue ~/ widget.unit;
    _scrollController = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatValue(int index) {
    final value = index * widget.unit;
    return '¥$value';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // 中央ハイライト背景
          Center(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: widget.highlightColor,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // ホイールピッカー
          ListWheelScrollView.useDelegate(
            controller: _scrollController,
            itemExtent: 48,
            perspective: 0.005,
            diameterRatio: 1.5,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) {
              setState(() {
                _selectedIndex = index;
              });
              widget.onChanged(index * widget.unit);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.maxMultiplier + 1,
              builder: (context, index) {
                final isSelected = index == _selectedIndex;
                return Center(
                  child: Text(
                    _formatValue(index),
                    style: isSelected
                        ? GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          )
                        : GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.normal,
                            color: AppColors.textMuted,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
