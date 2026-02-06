import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

/// 詳細画面用のサイクル期間ヘッダー（共通ウィジェット）
/// 日付範囲とオプションのバッジを表示
class CyclePeriodHeader extends StatelessWidget {
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final String? badgeText;
  final Color? badgeColor;

  const CyclePeriodHeader({
    super.key,
    required this.cycleStart,
    required this.cycleEnd,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(10),
        boxShadow: context.cardShadow(baseAlpha: 0.02, baseBlur: 6),
        border: context.isWhiteBackground
            ? Border.fromBorderSide(context.cardOutlineSide)
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: context.appTheme.textSecondary.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Text(
            '${cycleStart.year}/${cycleStart.month}/${cycleStart.day} 〜 ${cycleEnd.year}/${cycleEnd.month}/${cycleEnd.day}',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.appTheme.textSecondary,
            ),
          ),
          if (badgeText != null) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.accentBlue).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badgeText!,
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badgeColor ?? AppColors.accentBlue,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
