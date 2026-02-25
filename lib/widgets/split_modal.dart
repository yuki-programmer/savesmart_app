import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../config/constants.dart';
import '../models/expense.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import 'amount_text_field.dart';

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
  int? _targetCategoryId;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初期カテゴリIDを設定
    if (_targetCategory != null && _targetCategoryId == null) {
      final appState = context.read<AppState>();
      final categoryObj = appState.categories.firstWhere(
        (c) => c.name == _targetCategory,
        orElse: () => appState.categories.first,
      );
      _targetCategoryId = categoryObj.id;
    }
  }

  int get _maxSplitAmount => widget.expense.amount - 1;

  int get _remainingAmount => widget.expense.amount - _splitAmount;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
              color: context.appTheme.textMuted.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // タイトル
          Text(
            '支出を切り出す',
            style: AppTextStyles.screenTitle(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '一部を別のカテゴリに移動します',
            style: AppTextStyles.sub(context),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),

          // 元の支出情報
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appTheme.bgPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.expense.category,
                  style: AppTextStyles.body(context, weight: FontWeight.w500),
                ),
                Text(
                  '¥${formatNumber(widget.expense.amount)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary.withValues(alpha: 0.9),
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
              color: context.appTheme.textSecondary.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),

          // 金額入力
          Center(
            child: AmountTextField(
              initialValue: _splitAmount,
              fontSize: 28,
              accentColor: AppColors.accentBlue,
              onChanged: (value) {
                setState(() {
                  _splitAmount = value;
                });
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _splitAmount > _maxSplitAmount
                ? '最大金額(¥${formatNumber(_maxSplitAmount)})を超えています'
                : '最大: ¥${formatNumber(_maxSplitAmount)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _splitAmount > _maxSplitAmount
                  ? AppColors.accentRed
                  : context.appTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // 移動先カテゴリ
          Text(
            '移動先カテゴリ',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appTheme.textSecondary.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: context.appTheme.bgPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButton<String>(
              value: _targetCategory,
              isExpanded: true,
              underline: const SizedBox(),
              hint: Text(
                'カテゴリを選択',
                style: GoogleFonts.inter(
                  color: context.appTheme.textMuted,
                ),
              ),
              items: _availableCategories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      color: context.appTheme.textPrimary,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                final appState = context.read<AppState>();
                final categoryObj = appState.categories.firstWhere(
                  (c) => c.name == value,
                  orElse: () => appState.categories.first,
                );
                setState(() {
                  _targetCategoryId = categoryObj.id;
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
              color: context.appTheme.textSecondary.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _buildGradeSelector(),
          const SizedBox(height: 22),

          // プレビュー
          if (_splitAmount > 0 && _splitAmount <= _maxSplitAmount && _targetCategory != null)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentBlueLight.withValues(alpha: 0.6),
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
                          color: context.appTheme.textPrimary.withValues(alpha: 0.85),
                          height: 1.4,
                        ),
                      ),
                      Text(
                        '¥${formatNumber(_remainingAmount)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: context.appTheme.textPrimary.withValues(alpha: 0.9),
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
                              color: context.appTheme.textPrimary.withValues(alpha: 0.85),
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
                      color: context.appTheme.bgPrimary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'キャンセル',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.appTheme.textSecondary.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _splitAmount > 0 && _splitAmount <= _maxSplitAmount && _targetCategory != null
                      ? _performSplit
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _splitAmount > 0 && _splitAmount <= _maxSplitAmount && _targetCategory != null
                          ? AppColors.accentBlue.withValues(alpha: 0.9)
                          : context.appTheme.textMuted.withValues(alpha: 0.25),
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
        color = AppColors.expenseSaving;
        icon = Icons.savings_outlined;
        break;
      case 'reward':
        label = 'ご褒美';
        color = AppColors.expenseReward;
        icon = Icons.star_outline;
        break;
      default:
        label = '標準';
        color = AppColors.expenseStandard;
        icon = Icons.balance_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
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
      {'key': 'saving', 'label': '節約', 'icon': Icons.savings_outlined, 'color': AppColors.expenseSaving},
      {'key': 'standard', 'label': '標準', 'icon': Icons.balance_outlined, 'color': AppColors.expenseStandard},
      {'key': 'reward', 'label': 'ご褒美', 'icon': Icons.star_outline, 'color': AppColors.expenseReward},
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
                color: isSelected ? color.withValues(alpha: 0.15) : context.appTheme.bgPrimary,
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
                    color: isSelected ? color : context.appTheme.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    grade['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? color : context.appTheme.textMuted,
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

  Future<void> _performSplit() async {
    if (_splitAmount <= 0 || _targetCategoryId == null || _targetCategory == null) return;

    final success = await context.read<AppState>().splitExpense(
      widget.expense.id!,
      _splitAmount,
      _targetCategoryId!,
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
