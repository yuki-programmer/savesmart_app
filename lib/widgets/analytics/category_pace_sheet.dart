import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/app_state.dart';
import '../../utils/formatters.dart';

/// 全カテゴリのペースを表示するBottomSheet
void showAllCategoriesPaceSheet(
  BuildContext context, {
  required List<Map<String, dynamic>> items,
  required int monthDays,
}) {
  final appState = context.read<AppState>();
  final totalThisMonth = appState.thisMonthTotal;
  final totalDailyPace = totalThisMonth / monthDays;
  final totalWeeklyPace = totalDailyPace * 7;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _CategoryPaceSheetContent(
      items: items,
      totalDailyPace: _roundToHundred(totalDailyPace),
      totalWeeklyPace: _roundToHundred(totalWeeklyPace),
    ),
  );
}

/// 百円単位で丸める
int _roundToHundred(double value) {
  return ((value / 100).round() * 100);
}

class _CategoryPaceSheetContent extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final int totalDailyPace;
  final int totalWeeklyPace;

  const _CategoryPaceSheetContent({
    required this.items,
    required this.totalDailyPace,
    required this.totalWeeklyPace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ドラッグハンドル
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // タイトル
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
              child: Row(
                children: [
                  Text(
                    'カテゴリ別ペース',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length}カテゴリ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            // カテゴリリスト
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Column(
                  children: [
                    ...items.map((item) {
                      return _buildPaceItem(
                        label: item['label'] as String,
                        dailyPace: item['dailyPace'] as int,
                        weeklyPace: item['weeklyPace'] as int,
                        isTotal: false,
                      );
                    }),
                    // 全体
                    _buildPaceItem(
                      label: '全体',
                      dailyPace: totalDailyPace,
                      weeklyPace: totalWeeklyPace,
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaceItem({
    required String label,
    required int dailyPace,
    required int weeklyPace,
    required bool isTotal,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isTotal
            ? AppColors.accentBlue.withValues(alpha: 0.06)
            : AppColors.bgPrimary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリ名
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.w500,
              color: isTotal
                  ? AppColors.accentBlue
                  : AppColors.textPrimary.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          // 円/日 と 円/週
          Row(
            children: [
              // 円/日
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '約',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '¥${formatNumber(dailyPace)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isTotal
                            ? AppColors.accentBlue
                            : AppColors.textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      '/日',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // 円/週
              Row(
                children: [
                  Text(
                    '約',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '¥${formatNumber(weeklyPace)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isTotal
                          ? AppColors.accentBlue.withValues(alpha: 0.8)
                          : AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '/週',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
