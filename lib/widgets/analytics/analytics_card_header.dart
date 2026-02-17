import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';

/// アナリティクスカード用の共通ヘッダーウィジェット
class AnalyticsCardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isPremium;

  const AnalyticsCardHeader({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // アイコン
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: iconColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 12),
          // タイトル・サブタイトル
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: context.appTheme.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          // トレイリングアイコン
          _buildTrailingIcon(context),
        ],
      ),
    );
  }

  Widget _buildTrailingIcon(BuildContext context) {
    if (isPremium) {
      return Icon(
        Icons.chevron_right,
        size: 20,
        color: context.appTheme.textMuted.withValues(alpha: 0.5),
      );
    } else {
      return const PremiumLockBadge();
    }
  }
}

/// Premium ロックバッジ（Free ユーザー向け）
class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 12,
            color: AppColors.accentBlue.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 4),
          Text(
            'Plus',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.accentBlue.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// アナリティクスカード用の共通コンテナデコレーション
BoxDecoration analyticsCardDecoration(BuildContext context) {
  return BoxDecoration(
    color: context.appTheme.bgCard,
    borderRadius: BorderRadius.circular(12),
    boxShadow: context.cardElevationShadow,
  );
}

/// アナリティクスカード用の区切り線
class AnalyticsCardDivider extends StatelessWidget {
  const AnalyticsCardDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.appTheme.textMuted.withValues(alpha: 0.15),
    );
  }
}
