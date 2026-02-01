import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../amount_text_field.dart';

/// 内訳追加モーダルを表示
void showAddBreakdownModal({
  required BuildContext context,
  required List<Category> availableCategories,
  required void Function(Map<String, dynamic> breakdown) onAdd,
}) {
  int breakdownAmount = 0;
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
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
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

                        // 金額入力
                        Center(
                          child: AmountTextField(
                            initialValue: breakdownAmount,
                            fontSize: 36,
                            accentColor: AppColors.accentBlue,
                            onChanged: (value) {
                              setModalState(() {
                                breakdownAmount = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'タップして金額を入力',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

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
