import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../models/category_budget.dart';
import '../utils/formatters.dart';

/// サイクル切替時のカテゴリ予算レポートダイアログ
class CategoryBudgetReportDialog extends StatelessWidget {
  final List<Map<String, dynamic>> budgetResults;
  final List<CategoryBudget> continuingBudgets; // 毎月（固定）
  final List<CategoryBudget> endingBudgets; // 今月のみ
  final String currencyFormat;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const CategoryBudgetReportDialog({
    super.key,
    required this.budgetResults,
    required this.continuingBudgets,
    required this.endingBudgets,
    required this.currencyFormat,
    required this.onClose,
    required this.onEdit,
  });

  /// ダイアログを表示
  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> budgetResults,
    required List<CategoryBudget> continuingBudgets,
    required List<CategoryBudget> endingBudgets,
    required String currencyFormat,
    required VoidCallback onClose,
    required VoidCallback onEdit,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CategoryBudgetReportDialog(
          budgetResults: budgetResults,
          continuingBudgets: continuingBudgets,
          endingBudgets: endingBudgets,
          currencyFormat: currencyFormat,
          onClose: onClose,
          onEdit: onEdit,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.02),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            )),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: context.appTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ヘッダー
                _buildHeader(context),
                // コンテンツ
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 達成状況
                        _buildResultsSection(context),
                        if (continuingBudgets.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildContinuingSection(context),
                        ],
                        if (endingBudgets.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildEndingSection(context),
                        ],
                        const SizedBox(height: 24),
                        // アクションボタン
                        _buildActions(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: context.appTheme.borderSubtle),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentBlueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.pie_chart_outline,
              color: AppColors.accentBlue,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '先月のカテゴリ予算',
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '達成状況のまとめ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: context.appTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose();
            },
            icon: Icon(
              Icons.close,
              color: context.appTheme.textMuted,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ...budgetResults.map((result) => _buildResultItem(context, result)),
      ],
    );
  }

  Widget _buildResultItem(BuildContext context, Map<String, dynamic> result) {
    final budget = result['budget'] as CategoryBudget;
    final spent = result['spent'] as int;
    final rate = result['rate'] as double;
    final isOverBudget = result['isOverBudget'] as bool;

    final ratePercent = (rate * 100).round();
    final rateText = isOverBudget ? '超過' : '$ratePercent%';

    final barColor = isOverBudget ? AppColors.accentRed : AppColors.accentBlue;
    final fillRate = isOverBudget ? 1.0 : rate.clamp(0.0, 1.0);
    final barWidthMultiplier = isOverBudget ? 1.2 : 1.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.categoryName,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textPrimary,
                ),
              ),
              Text(
                '${formatCurrency(spent, currencyFormat)} / ${formatCurrency(budget.budgetAmount, currencyFormat)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOverBudget
                      ? AppColors.accentRed
                      : context.appTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
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
                          Container(
                            height: 6,
                            width: maxWidth,
                            decoration: BoxDecoration(
                              color: context.appTheme.borderSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Container(
                            height: 6,
                            width: barWidth * fillRate,
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 36,
                child: Text(
                  rateText,
                  textAlign: TextAlign.right,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isOverBudget
                        ? AppColors.accentRed
                        : context.appTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContinuingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.refresh,
              size: 16,
              color: AppColors.accentGreen,
            ),
            const SizedBox(width: 6),
            Text(
              '今月も継続',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.accentGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...continuingBudgets.map((budget) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${budget.categoryName}（${formatCurrency(budget.budgetAmount, currencyFormat)}）',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appTheme.textSecondary,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildEndingSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 16,
              color: context.appTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              '先月で終了',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTheme.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...endingBudgets.map((budget) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${budget.categoryName}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appTheme.textMuted,
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // 編集ボタン
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEdit();
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accentBlue),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '予算を編集する',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accentBlue,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // 閉じるボタン
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onClose();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              '閉じる',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
