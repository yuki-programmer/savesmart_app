import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import 'wheel_picker.dart';

class SplitModal extends StatefulWidget {
  final Expense expense;
  final VoidCallback onSplit;

  const SplitModal({
    super.key,
    required this.expense,
    required this.onSplit,
  });

  @override
  State<SplitModal> createState() => _SplitModalState();
}

class _SplitModalState extends State<SplitModal> {
  int _splitAmount = 0;
  int _splitUnit = 100;
  String? _targetCategory;
  late String _targetGrade;
  late List<String> _availableCategories;

  @override
  void initState() {
    super.initState();
    _availableCategories = AppConstants.defaultCategories
        .where((c) => c != widget.expense.category)
        .toList();
    if (_availableCategories.isNotEmpty) {
      _targetCategory = _availableCategories.first;
    }
    // デフォルトは切り出し元のタイプ
    _targetGrade = widget.expense.grade;
  }

  int get _maxSplitAmount => widget.expense.amount - 1;

  int get _remainingAmount => widget.expense.amount - _splitAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          // ハンドル
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textMuted.withOpacity(0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // タイトル
          Text(
            '支出を切り出す',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withOpacity(0.9),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '一部を別のカテゴリに移動します',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),

          // 元の支出情報
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.expense.category,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                Text(
                  '¥${formatNumber(widget.expense.amount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // 切り出す金額
          Text(
            '切り出す金額',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¥${formatNumber(_splitAmount)}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(height: 12),

          // 単位選択
          _buildUnitSelector(),
          const SizedBox(height: 8),

          // ホイールピッカー
          SizedBox(
            height: 150,
            child: WheelPicker(
              key: ValueKey('split_$_splitUnit'),
              unit: _splitUnit,
              maxMultiplier: (_maxSplitAmount / _splitUnit).floor(),
              initialValue: _splitAmount,
              highlightColor: AppColors.accentBlueLight,
              onChanged: (value) {
                if (value <= _maxSplitAmount) {
                  setState(() {
                    _splitAmount = value;
                  });
                }
              },
            ),
          ),
          const SizedBox(height: 16),

          // 移動先カテゴリ
          Text(
            '移動先カテゴリ',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: _targetCategory,
              isExpanded: true,
              underline: const SizedBox(),
              hint: Text(
                'カテゴリを選択',
                style: GoogleFonts.inter(
                  color: AppColors.textMuted,
                ),
              ),
              items: _availableCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      color: AppColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _targetCategory = value;
                });
              },
            ),
          ),
          const SizedBox(height: 16),

          // 支出タイプ選択
          Text(
            '支出タイプ',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _buildGradeSelector(),
          const SizedBox(height: 22),

          // プレビュー
          if (_splitAmount > 0 && _targetCategory != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentBlueLight.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.expense.category,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textPrimary.withOpacity(0.85),
                          height: 1.4,
                        ),
                      ),
                      Text(
                        '¥${formatNumber(_remainingAmount)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            _targetCategory!,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textPrimary.withOpacity(0.85),
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildGradeBadge(_targetGrade),
                        ],
                      ),
                      Text(
                        '¥${formatNumber(_splitAmount)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentBlue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),

          // ボタン
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'キャンセル',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary.withOpacity(0.75),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _splitAmount > 0 && _targetCategory != null
                      ? _performSplit
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _splitAmount > 0 && _targetCategory != null
                          ? AppColors.accentBlue.withOpacity(0.9)
                          : AppColors.textMuted.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '切り出す',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildGradeBadge(String grade) {
    String label;
    Color color;
    IconData icon;

    switch (grade) {
      case 'saving':
        label = '節約';
        color = AppColors.accentGreen;
        icon = Icons.savings_outlined;
        break;
      case 'reward':
        label = 'ご褒美';
        color = AppColors.accentOrange;
        icon = Icons.star_outline;
        break;
      default:
        label = '標準';
        color = AppColors.accentBlue;
        icon = Icons.balance_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSelector() {
    final grades = [
      {'key': 'saving', 'label': '節約', 'icon': Icons.savings_outlined, 'color': AppColors.accentGreen},
      {'key': 'standard', 'label': '標準', 'icon': Icons.balance_outlined, 'color': AppColors.accentBlue},
      {'key': 'reward', 'label': 'ご褒美', 'icon': Icons.star_outline, 'color': AppColors.accentOrange},
    ];

    return Row(
      children: grades.map((grade) {
        final isSelected = _targetGrade == grade['key'];
        final color = grade['color'] as Color;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _targetGrade = grade['key'] as String;
              });
            },
            child: Container(
              margin: EdgeInsets.only(
                right: grade['key'] != 'reward' ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.15) : AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    grade['icon'] as IconData,
                    size: 16,
                    color: isSelected ? color : AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    grade['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? color : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUnitSelector() {
    final units = [10, 100, 1000];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: units.map((unit) {
          final isSelected = _splitUnit == unit;
          return GestureDetector(
            onTap: () {
              setState(() {
                _splitUnit = unit;
                _splitAmount = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$unit円',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _performSplit() async {
    if (_splitAmount <= 0 || _targetCategory == null) return;

    final success = await context.read<AppState>().splitExpense(
      widget.expense.id!,
      _splitAmount,
      _targetCategory!,
      grade: _targetGrade,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      widget.onSplit();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '¥${formatNumber(_splitAmount)} を $_targetCategory に切り出しました'
              : '切り出しに失敗しました',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: success ? AppColors.accentBlue : AppColors.accentRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

void showSplitModal(BuildContext context, Expense expense, VoidCallback onSplit) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SplitModal(
        expense: expense,
        onSplit: onSplit,
      ),
    ),
  );
}
