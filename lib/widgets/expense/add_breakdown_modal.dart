import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../utils/formatters.dart';
import '../wheel_picker.dart';

/// 内訳追加モーダルを表示
void showAddBreakdownModal({
  required BuildContext context,
  required List<Category> availableCategories,
  required void Function(Map<String, dynamic> breakdown) onAdd,
}) {
  int breakdownAmount = 0;
  int breakdownUnit = 100;
  Category? selectedCategory;
  String breakdownType = 'standard';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // スクロール可能なコンテンツ
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '内訳を追加',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 金額表示
                      Center(
                        child: Text(
                          '¥${formatNumber(breakdownAmount)}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 単位選択
                      Center(
                        child: _buildUnitSelector(
                          units: [10, 100, 1000, 10000],
                          selectedUnit: breakdownUnit,
                          onChanged: (unit) {
                            setModalState(() {
                              breakdownUnit = unit;
                              breakdownAmount = 0;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ホイールピッカー
                      SizedBox(
                        height: 160,
                        child: WheelPicker(
                          key: ValueKey('breakdown_$breakdownUnit'),
                          unit: breakdownUnit,
                          maxMultiplier: breakdownUnit >= 1000 ? 100 : 99,
                          initialValue: breakdownAmount,
                          highlightColor: AppColors.accentBlueLight,
                          onChanged: (value) {
                            setModalState(() {
                              breakdownAmount = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // カテゴリ選択
                      Text(
                        'カテゴリ',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.bgPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<Category>(
                          value: selectedCategory,
                          hint: Text(
                            'カテゴリを選択',
                            style: GoogleFonts.inter(
                              color: AppColors.textMuted,
                            ),
                          ),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: availableCategories.map((category) {
                            return DropdownMenuItem<Category>(
                              value: category,
                              child: Text(
                                category.name,
                                style: GoogleFonts.inter(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setModalState(() {
                              selectedCategory = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // タイプ選択
                      Text(
                        'タイプ',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _BreakdownTypeSelector(
                        selectedType: breakdownType,
                        onChanged: (type) {
                          setModalState(() {
                            breakdownType = type;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // ボタン（固定）
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.bgPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              'キャンセル',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (breakdownAmount > 0 && selectedCategory != null) {
                            onAdd({
                              'amount': breakdownAmount,
                              'categoryId': selectedCategory!.id,
                              'category': selectedCategory!.name,
                              'type': breakdownType,
                            });
                            Navigator.pop(context);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.accentBlue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              '追加',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildUnitSelector({
  required List<int> units,
  required int selectedUnit,
  required Function(int) onChanged,
}) {
  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: units.map((unit) {
          final isSelected = selectedUnit == unit;
          return GestureDetector(
            onTap: () => onChanged(unit),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$unit円',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ),
  );
}

class _BreakdownTypeSelector extends StatelessWidget {
  final String selectedType;
  final Function(String) onChanged;

  const _BreakdownTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = [
      {
        'key': 'saving',
        'label': '💰 節約',
        'color': AppColors.accentGreenLight,
        'textColor': AppColors.accentGreen
      },
      {
        'key': 'standard',
        'label': '🎯 標準',
        'color': AppColors.accentBlueLight,
        'textColor': AppColors.accentBlue
      },
      {
        'key': 'reward',
        'label': '⭐ ご褒美',
        'color': AppColors.accentPurpleLight,
        'textColor': AppColors.accentPurple
      },
    ];

    return Row(
      children: types.map((type) {
        final isSelected = selectedType == type['key'];
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(type['key'] as String),
            child: Container(
              margin: EdgeInsets.only(
                right: type['key'] != 'reward' ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? type['color'] as Color : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      isSelected ? type['textColor'] as Color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  type['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? type['textColor'] as Color
                        : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
