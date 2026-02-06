import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/category_budget.dart';
import '../../utils/formatters.dart';

class CategoryBudgetSection extends StatelessWidget {
  final List<Map<String, dynamic>> budgetStatusList;
  final String currencyFormat;
  final VoidCallback onEditTap;
  final VoidCallback onSetupTap;

  const CategoryBudgetSection({
    super.key,
    required this.budgetStatusList,
    required this.currencyFormat,
    required this.onEditTap,
    required this.onSetupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // セクションヘッダー
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'カテゴリ予算',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.appTheme.textPrimary.withValues(alpha: 0.85),
              ),
            ),
            GestureDetector(
              onTap: onEditTap,
              child: Row(
                children: [
                  Text(
                    '編集',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentBlue.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.accentBlue.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // カード
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.appTheme.bgCard,
            borderRadius: BorderRadius.circular(12),
            boxShadow: context.cardShadow(baseAlpha: 0.02, baseBlur: 6, baseOffset: const Offset(0, 1)),
            border: context.isWhiteBackground
                ? Border.fromBorderSide(context.cardOutlineSide)
                : null,
          ),
          child: budgetStatusList.isEmpty
              ? _buildEmptyState()
              : _buildBudgetList(context),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GestureDetector(
      onTap: onSetupTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: AppColors.accentBlue.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'カテゴリ予算を設定',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.accentBlue.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetList(BuildContext context) {
    return Column(
      children: budgetStatusList.asMap().entries.map((entry) {
        final index = entry.key;
        final status = entry.value;
        final isLast = index == budgetStatusList.length - 1;
        return _buildBudgetItem(context, status, isLast: isLast);
      }).toList(),
    );
  }

  Widget _buildBudgetItem(BuildContext context, Map<String, dynamic> status, {bool isLast = false}) {
    final budget = status['budget'] as CategoryBudget;
    final spent = status['spent'] as int;
    final rate = status['rate'] as double;
    final isOverBudget = status['isOverBudget'] as bool;

    // 消費率の表示（%）
    final ratePercent = (rate * 100).round();
    final rateText = isOverBudget ? '超過' : '$ratePercent%';

    // バーの色（50%超: オレンジ、85%超: 赤）
    final Color barColor;
    if (isOverBudget || rate > 0.85) {
      barColor = AppColors.accentRed;
    } else if (rate > 0.5) {
      barColor = AppColors.accentOrange;
    } else {
      barColor = AppColors.accentBlue;
    }

    // バーの塗りつぶし率（超過時は1.0、通常時は消費率）
    final fillRate = isOverBudget ? 1.0 : rate.clamp(0.0, 1.0);

    // バーの幅倍率（超過時は1.2倍）
    final barWidthMultiplier = isOverBudget ? 1.2 : 1.0;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリ名と金額
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.categoryName,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textPrimary,
                ),
              ),
              Text(
                '${formatCurrency(spent, currencyFormat)} / ${formatCurrency(budget.budgetAmount, currencyFormat)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: barColor == AppColors.accentBlue
                      ? context.appTheme.textSecondary
                      : barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // バー + パーセント
          Row(
            children: [
              // バー
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxWidth = constraints.maxWidth;
                    final barWidth = maxWidth * barWidthMultiplier;

                    return SizedBox(
                      width: maxWidth,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // 背景バー（100%幅）
                          Container(
                            height: 8,
                            width: maxWidth,
                            decoration: BoxDecoration(
                              color: context.appTheme.borderSubtle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          // 塗りつぶしバー
                          Container(
                            height: 8,
                            width: barWidth * fillRate,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),

              // パーセントまたは「超過」
              SizedBox(
                width: 40,
                child: Text(
                  rateText,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: barColor == AppColors.accentBlue
                        ? context.appTheme.textSecondary
                        : barColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
