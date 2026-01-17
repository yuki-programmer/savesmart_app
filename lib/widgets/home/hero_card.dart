import 'package:flutter/material.dart';
import '../../config/home_constants.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';
import '../night_reflection_dialog.dart';

/// HeroCardの時間帯モード
enum HeroCardTimeMode {
  day,      // 4:00-5:59 & 10:00-18:59
  morning,  // 6:00-9:59（暖色グラデーション）
  night,    // 19:00-3:59（夜テーマ）
}

/// HeroCardの状態
class _HeroCardState {
  final HeroCardTimeMode timeMode;
  final bool canOpenReflection;  // 夜 && 未開封

  _HeroCardState({
    required this.timeMode,
    required this.canOpenReflection,
  });

  factory _HeroCardState.fromDateTime(DateTime now, bool hasTodayExpense, bool hasOpenedReflection) {
    final hour = now.hour;
    final HeroCardTimeMode timeMode;

    if (hour >= 6 && hour < 10) {
      timeMode = HeroCardTimeMode.morning;
    } else if (hour >= 19 || hour < 4) {
      timeMode = HeroCardTimeMode.night;
    } else {
      timeMode = HeroCardTimeMode.day;
    }

    // 振り返り起動可否（夜テーマ && 既存ロジック && 未開封）
    final canOpenReflection = timeMode == HeroCardTimeMode.night &&
        NightReflectionDialog.shouldShowNightCard(hasTodayExpense: hasTodayExpense) &&
        !hasOpenedReflection;

    return _HeroCardState(
      timeMode: timeMode,
      canOpenReflection: canOpenReflection,
    );
  }
}

/// ホーム画面のヒーローカード（今日使えるお金）
class HeroCard extends StatelessWidget {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final bool hasOpenedReflection;
  final VoidCallback? onTapReflection;

  const HeroCard({
    super.key,
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.hasOpenedReflection,
    this.onTapReflection,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final state = _HeroCardState.fromDateTime(now, todayTotal > 0, hasOpenedReflection);

    return GestureDetector(
      onTap: state.canOpenReflection ? onTapReflection : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HomeConstants.heroCardPadding),
        decoration: _buildDecoration(state.timeMode),
        child: _buildContent(context, state),
      ),
    );
  }

  BoxDecoration _buildDecoration(HeroCardTimeMode mode) {
    switch (mode) {
      case HeroCardTimeMode.night:
        return BoxDecoration(
          color: HomeConstants.nightCardBackground,
          borderRadius: BorderRadius.circular(HomeConstants.heroCardRadius),
          boxShadow: HomeConstants.nightCardShadow,
        );

      case HeroCardTimeMode.morning:
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: HomeConstants.morningGradient,
          ),
          borderRadius: BorderRadius.circular(HomeConstants.heroCardRadius),
          boxShadow: HomeConstants.cardShadow,
        );

      case HeroCardTimeMode.day:
        return BoxDecoration(
          color: HomeConstants.cardBackground,
          borderRadius: BorderRadius.circular(HomeConstants.heroCardRadius),
          boxShadow: HomeConstants.cardShadow,
        );
    }
  }

  Widget _buildContent(BuildContext context, _HeroCardState state) {
    switch (state.timeMode) {
      case HeroCardTimeMode.night:
        return _NightContent(
          fixedTodayAllowance: fixedTodayAllowance,
          dynamicTomorrowForecast: dynamicTomorrowForecast,
          todayTotal: todayTotal,
          canOpenReflection: state.canOpenReflection,
        );

      case HeroCardTimeMode.morning:
      case HeroCardTimeMode.day:
        return _DayContent(
          fixedTodayAllowance: fixedTodayAllowance,
          dynamicTomorrowForecast: dynamicTomorrowForecast,
          isMorningGlow: state.timeMode == HeroCardTimeMode.morning,
        );
    }
  }
}

/// 日中Content（Day/Morning共通）
class _DayContent extends StatelessWidget {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final bool isMorningGlow;

  const _DayContent({
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.isMorningGlow,
  });

  @override
  Widget build(BuildContext context) {
    final isIncreasing = (dynamicTomorrowForecast ?? 0) > (fixedTodayAllowance ?? 0);

    return Column(
      children: [
        // ラベル
        Text(
          '今日使えるお金',
          style: TextStyle(
            fontSize: HomeConstants.heroLabelSize,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),

        // 金額（主役）
        Text(
          '¥${formatNumber(fixedTodayAllowance ?? 0)}',
          style: const TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: HomeConstants.heroAmountSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: HomeConstants.primaryText,
          ),
        ),
        const SizedBox(height: 16),

        // 明日の予測
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'このままなら明日は ',
              style: TextStyle(
                fontSize: HomeConstants.heroSubtextSize,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '¥${formatNumber(dynamicTomorrowForecast ?? 0)}',
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isIncreasing ? AppColors.accentGreen : AppColors.accentRed,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: isIncreasing ? AppColors.accentGreen : AppColors.accentRed,
            ),
          ],
        ),
      ],
    );
  }
}

/// 夜Content（修正版：答えを残す）
class _NightContent extends StatelessWidget {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final bool canOpenReflection;

  const _NightContent({
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.canOpenReflection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🌙 コンテキスト表示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              '今日のふりかえり',
              style: TextStyle(
                fontSize: 14,
                color: HomeConstants.nightPrimaryText.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 主役：今日使えるお金（夜でも表示）
        Column(
          children: [
            Text(
              '今日使えるお金',
              style: TextStyle(
                fontSize: 12,
                color: HomeConstants.nightPrimaryText.withValues(alpha: 0.7),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '¥${formatNumber(fixedTodayAllowance ?? 0)}',
              style: const TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: HomeConstants.heroAmountSizeNight,
                fontWeight: FontWeight.w600,
                color: HomeConstants.nightPrimaryText,
                height: 1.1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 区切り線
        Container(
          width: 120,
          height: 1,
          color: HomeConstants.nightPrimaryText.withValues(alpha: 0.2),
        ),

        const SizedBox(height: 16),

        // 補足：今日/明日（振り返り導線）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMetric('今日', todayTotal, HomeConstants.nightPrimaryText.withValues(alpha: 0.75)),
            const SizedBox(width: 32),
            _buildMetric('明日', dynamicTomorrowForecast ?? 0, HomeConstants.nightPrimaryText),
          ],
        ),

        // CTA（振り返り可能時のみ）
        if (canOpenReflection) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: HomeConstants.nightPrimaryText.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'タップして振り返る',
                style: TextStyle(
                  fontSize: 12,
                  color: HomeConstants.nightPrimaryText.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetric(String label, int amount, Color textColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textColor.withValues(alpha: textColor.a * 0.7),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '¥${formatNumber(amount)}',
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
