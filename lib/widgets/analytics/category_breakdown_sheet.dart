import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/app_state.dart';
import '../../utils/formatters.dart';

/// カテゴリ別グレード内訳BottomSheetを表示
void showCategoryBreakdownSheet(BuildContext context, String categoryName) {
  final appState = context.read<AppState>();
  final breakdown = appState.getCategoryGradeBreakdown(categoryName);

  // 最も多いグレードを特定
  String? dominantGrade;
  int maxCount = 0;
  for (final entry in breakdown.entries) {
    final count = entry.value['count'] ?? 0;
    if (count > maxCount) {
      maxCount = count;
      dominantGrade = entry.key;
    }
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CategoryBreakdownSheetContent(
      categoryName: categoryName,
      breakdown: breakdown,
      dominantGrade: dominantGrade,
    ),
  );
}

class _CategoryBreakdownSheetContent extends StatelessWidget {
  final String categoryName;
  final Map<String, Map<String, int>> breakdown;
  final String? dominantGrade;

  const _CategoryBreakdownSheetContent({
    required this.categoryName,
    required this.breakdown,
    required this.dominantGrade,
  });

  /// 最も多いグレードが有意かどうかを判定（データが1件以上ある場合）
  bool _maxCountIsSignificant() {
    int totalCount = 0;
    for (final data in breakdown.values) {
      totalCount += data['count'] ?? 0;
    }
    return totalCount > 0;
  }

  @override
  Widget build(BuildContext context) {
    final gradeInfo = [
      {
        'key': 'saving',
        'label': '節約',
        'color': AppColors.accentGreen,
        'icon': Icons.savings_outlined,
      },
      {
        'key': 'standard',
        'label': '標準',
        'color': AppColors.accentBlue,
        'icon': Icons.balance_outlined,
      },
      {
        'key': 'reward',
        'label': 'ご褒美',
        'color': AppColors.accentOrange,
        'icon': Icons.star_outline,
      },
    ];

    // 評価文を生成
    String evaluationText = '';
    if (dominantGrade != null && _maxCountIsSignificant()) {
      final gradeLabel = gradeInfo.firstWhere(
        (g) => g['key'] == dominantGrade,
        orElse: () => {'label': ''},
      )['label'] as String;
      if (gradeLabel.isNotEmpty) {
        evaluationText = 'このカテゴリは「$gradeLabel」が多めです';
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ドラッグハンドル
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // タイトル
              Text(
                '$categoryNameの使い方',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withValues(alpha: 0.9),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),

              // 内訳リスト
              ...gradeInfo.map((grade) {
                final key = grade['key'] as String;
                final label = grade['label'] as String;
                final color = grade['color'] as Color;
                final icon = grade['icon'] as IconData;
                final data = breakdown[key]!;
                final amount = data['amount'] ?? 0;
                final count = data['count'] ?? 0;
                final hasData = count > 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: hasData
                        ? color.withValues(alpha: 0.08)
                        : AppColors.bgPrimary.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // アイコン
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hasData
                              ? color.withValues(alpha: 0.15)
                              : AppColors.textMuted.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: hasData ? color : AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // ラベル
                      Expanded(
                        child: Text(
                          label,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: hasData
                                ? AppColors.textPrimary.withValues(alpha: 0.9)
                                : AppColors.textMuted.withValues(alpha: 0.6),
                            height: 1.4,
                          ),
                        ),
                      ),
                      // 金額
                      Text(
                        '¥${formatNumber(amount)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasData
                              ? AppColors.textPrimary.withValues(alpha: 0.9)
                              : AppColors.textMuted.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // 回数
                      Text(
                        '$count回',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: hasData
                              ? AppColors.textSecondary.withValues(alpha: 0.7)
                              : AppColors.textMuted.withValues(alpha: 0.4),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // 評価文
              if (evaluationText.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgPrimary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    evaluationText,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
