import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';
import '../utils/formatters.dart';

/// 夜の振り返りダイアログ
/// 19:00以降に表示され、今日の支出と明日の予算を表示する
class NightReflectionDialog extends StatelessWidget {
  final int todayTotal;
  final int? tomorrowBudget;
  final VoidCallback onClose;

  const NightReflectionDialog({
    super.key,
    required this.todayTotal,
    required this.tomorrowBudget,
    required this.onClose,
  });

  /// 夜カードを表示すべきかどうかを判定
  ///
  /// - 19:00〜23:59 → 常に夜カード（支出があっても表示し続ける）
  /// - 00:00〜03:59 → 今日の支出がなければ夜カード、あれば日中カード
  /// - 04:00〜18:59 → 常に日中カード
  static bool shouldShowNightCard({required bool hasTodayExpense}) {
    final now = DateTime.now();
    final hour = now.hour;

    // 19:00〜23:59 は常に夜カード
    if (hour >= 19) {
      return true;
    }

    // 00:00〜03:59 は今日の支出がなければ夜カード
    if (hour < 4) {
      return !hasTodayExpense;
    }

    // 04:00〜18:59 は日中カード
    return false;
  }

  /// ダイアログを表示
  static Future<void> show(BuildContext context, {
    required int todayTotal,
    required int? tomorrowBudget,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xFF1A1F3C).withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return NightReflectionDialog(
          todayTotal: todayTotal,
          tomorrowBudget: tomorrowBudget,
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSpending = todayTotal > 0;
    final message = hasSpending
        ? '今日もお疲れさま。\n明日はこの金額を目安にいこう。'
        : '今日はお金を使わない日でした。\n素晴らしい！';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 月アイコン
              const Text(
                '🌙',
                style: TextStyle(fontSize: 48),
              ),
              const SizedBox(height: 24),
              // タイトル
              Text(
                '今日のふりかえり',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              // 今日の支出
              _buildStatItem(
                label: '今日の支出',
                value: '¥${formatNumber(todayTotal)}',
                valueColor: hasSpending
                    ? Colors.white.withValues(alpha: 0.95)
                    : AppColors.accentGreen.withValues(alpha: 0.9),
              ),
              const SizedBox(height: 32),
              // 明日の予算
              if (tomorrowBudget != null)
                _buildStatItem(
                  label: '明日の予算(日割り)',
                  value: tomorrowBudget! >= 0
                      ? '¥${formatNumber(tomorrowBudget!)}'
                      : '-¥${formatNumber(tomorrowBudget!.abs())}',
                  valueColor: tomorrowBudget! >= 0
                      ? Colors.white.withValues(alpha: 0.95)
                      : AppColors.accentOrange.withValues(alpha: 0.9),
                  isLarge: true,
                ),
              const SizedBox(height: 48),
              // メッセージ
              Text(
                message,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 3),
              // 閉じるボタン
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '閉じる',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color valueColor,
    bool isLarge = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.ibmPlexSans(
            fontSize: isLarge ? 42 : 32,
            fontWeight: FontWeight.w600,
            color: valueColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}
