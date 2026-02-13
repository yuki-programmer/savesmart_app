import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';

/// 週間バジェットカード（Premium機能）
/// 今週（または給料日まで）に使える金額を表示
class WeeklyBudgetCard extends StatelessWidget {
  final int? amount;
  final int daysRemaining;
  final DateTime endDate;
  final bool isWeekMode;
  final bool isOverBudget;
  final bool isPremium;
  final String currencyFormat;
  final VoidCallback? onTapLocked;

  const WeeklyBudgetCard({
    super.key,
    required this.amount,
    required this.daysRemaining,
    required this.endDate,
    required this.isWeekMode,
    required this.isOverBudget,
    required this.isPremium,
    required this.currencyFormat,
    this.onTapLocked,
  });

  @override
  Widget build(BuildContext context) {
    // Free ユーザー: ロック表示
    if (!isPremium) {
      return _buildLockedCard(context);
    }

    // 予算オーバー時
    if (isOverBudget) {
      return _buildOverBudgetCard(context);
    }

    // 通常表示
    return _buildNormalCard(context);
  }

  /// 通常カード
  Widget _buildNormalCard(BuildContext context) {
    final title = isWeekMode ? '今週あと使える' : '給料日まであと使える';
    final subText = isWeekMode
        ? 'あと$daysRemaining日（〜日曜）'
        : 'あと$daysRemaining日（〜${endDate.month}/${endDate.day}）';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: context.cardElevationShadow,
      ),
      child: Row(
        children: [
          // 左側アイコン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.date_range_outlined,
              size: 20,
              color: AppColors.accentBlue,
            ),
          ),
          const SizedBox(width: 14),

          // 中央テキスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subText,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.appTheme.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),

          // 右側金額
          Text(
            amount != null
                ? formatCurrency(amount!, currencyFormat)
                : '-',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.appTheme.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  /// 予算オーバー時のカード
  Widget _buildOverBudgetCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.accentOrange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // 左側アイコン
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accentOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              size: 22,
              color: AppColors.accentOrange,
            ),
          ),
          const SizedBox(width: 14),

          // テキスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '予算オーバー中',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentOrange,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '支出を見直そう',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ロック表示（Free ユーザー用）
  Widget _buildLockedCard(BuildContext context) {
    return GestureDetector(
      onTap: onTapLocked,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: context.cardElevationShadow,
      ),
        child: Row(
          children: [
            // 左側アイコン（グレー）
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appTheme.textMuted.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.date_range_outlined,
                size: 20,
                color: context.appTheme.textMuted.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 14),

            // 中央テキスト（グレー）
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '今週あと使える',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: context.appTheme.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '¥---',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.textMuted.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),

            // Plus バッジ
            _buildPlusBadge(context),
          ],
        ),
      ),
    );
  }

  /// Plus バッジ
  Widget _buildPlusBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 12,
            color: context.appTheme.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            'Plus',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.appTheme.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
