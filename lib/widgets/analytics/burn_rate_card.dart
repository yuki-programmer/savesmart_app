import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../config/typography.dart';
import '../../services/app_state.dart';
import '../../utils/formatters.dart';
import '../burn_rate_chart.dart';
import '../../screens/burn_rate_detail_screen.dart';
import '../../screens/premium_screen.dart';
import 'analytics_card_header.dart';

/// 支出ペースカード（常時表示版）
/// Premium: 実データ + 矢印（詳細画面へ）
/// Free: ダミーデータ + ループアニメ + ロックアイコン（Premium画面へ）
class BurnRateCard extends StatefulWidget {
  final AppState appState;
  final bool isPremium;

  const BurnRateCard({
    super.key,
    required this.appState,
    required this.isPremium,
  });

  @override
  State<BurnRateCard> createState() => _BurnRateCardState();
}

class _BurnRateCardState extends State<BurnRateCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  // ダミーデータ（Free用）
  static const List<double> _dummyRates = [
    3, 8, 12, 18, 22, 28, 33, 38, 42, 45,
    48, 52, 55, 58, 62, 65, 68, 71, 74, 77,
    80, 83, 86, 88, 90, 92, 94, 96, 98, 100,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Free版の場合のみループアニメーション
    if (!widget.isPremium) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(BurnRateCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremium != oldWidget.isPremium) {
      if (widget.isPremium) {
        _animationController.stop();
        _animationController.reset();
      } else {
        _animationController.repeat();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        decoration: analyticsCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalyticsCardHeader(
              icon: Icons.show_chart,
              iconColor: AppColors.accentBlue,
              title: '支出ペース',
              subtitle: widget.isPremium
                  ? _getSummaryText()
                  : 'お金を使うペースがわかります',
              isPremium: widget.isPremium,
            ),
            const AnalyticsCardDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: widget.isPremium
                  ? _buildPremiumContent()
                  : _buildFreeContent(),
            ),
          ],
        ),
      ),
    );
  }

  String _getSummaryText() {
    final income = widget.appState.thisMonthAvailableAmount;
    final disposable = widget.appState.disposableAmount;
    final variableSpending = widget.appState.thisMonthTotal;

    if (income == null) return '収入を設定してください';
    if (disposable == null || disposable <= 0) return '可処分金額なし';

    final rate = (variableSpending / disposable) * 100;
    return '消化率 ${rate.toStringAsFixed(0)}%';
  }

  /// Premium版: 実データ表示
  Widget _buildPremiumContent() {
    final appState = widget.appState;
    final income = appState.thisMonthAvailableAmount;
    final disposable = appState.disposableAmount;

    // 収入未設定
    if (income == null) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet_outlined,
        message: '収入が未設定です',
        subMessage: '追加画面から設定できます',
      );
    }

    // 可処分金額なし
    if (disposable == null || disposable <= 0) {
      return _buildEmptyState(
        icon: Icons.warning_amber_outlined,
        message: '可処分金額がありません',
        subMessage: '固定費が収入を超えています',
      );
    }

    // 正常表示
    final now = DateTime.now();
    final cycleStart = appState.cycleStartDate;
    final cycleEnd = appState.cycleEndDate;
    final daysInCycle = cycleEnd.difference(cycleStart).inDays + 1;
    final today = DateTime(now.year, now.month, now.day);
    final todayInCycle = today.difference(cycleStart).inDays + 1;
    final startDay = _getStartDayInCycle(appState.thisMonthExpenses, cycleStart);
    final dailyRates = _calculateDailyBurnRates(appState, disposable, daysInCycle, cycleStart);
    final currentRate = todayInCycle > 0 && todayInCycle <= dailyRates.length
        ? dailyRates[todayInCycle - 1]
        : 0.0;
    final variableSpending = appState.thisMonthTotal;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        appState.getPreviousCycleBurnRateData(),
        appState.getCycleComparisonDiff(),
      ]),
      builder: (context, snapshot) {
        List<double>? prevRates;
        int? prevDays;
        int? prevStartDay;
        int? comparisonDiff;

        if (snapshot.hasData) {
          final prevData = snapshot.data![0] as Map<String, dynamic>?;
          comparisonDiff = snapshot.data![1] as int?;

          if (prevData != null) {
            prevRates = (prevData['rates'] as List<dynamic>).cast<double>();
            prevDays = prevData['totalDays'] as int;
            prevStartDay = prevData['startDay'] as int;
          }
        }

        return Column(
          children: [
            // 消化率サマリー
            _buildRateSummary(currentRate, variableSpending, disposable, comparisonDiff),
            const SizedBox(height: 12),
            // グラフ
            BurnRateChart(
              dailyRates: dailyRates,
              todayDay: todayInCycle,
              daysInMonth: daysInCycle,
              startDay: startDay,
              cycleStartDate: cycleStart,
              previousMonthRates: prevRates,
              previousMonthDays: prevDays,
              previousMonthStartDay: prevStartDay,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRateSummary(double rate, int spending, int disposable, int? comparisonDiff) {
    final isOver100 = rate > 100;

    return Row(
      children: [
        // 消化率
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOver100
                ? AppColors.accentRed.withValues(alpha: 0.08)
                : AppColors.accentBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isOver100 ? AppColors.accentRed : AppColors.accentBlue,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '¥${formatNumber(spending)} / ¥${formatNumber(disposable)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // 比較バッジ
        if (comparisonDiff != null) _buildComparisonBadge(comparisonDiff),
      ],
    );
  }

  Widget _buildComparisonBadge(int diff) {
    final isSaving = diff >= 0;
    final color = isSaving ? AppColors.accentGreen : AppColors.accentOrange;
    final icon = isSaving ? Icons.trending_down : Icons.trending_up;
    final diffText = isSaving
        ? '-¥${formatNumber(diff)}'
        : '+¥${formatNumber(diff.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            diffText,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Free版: ダミーデータ + ループアニメーション
  Widget _buildFreeContent() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // アニメーション値に基づいて表示する日数を計算
        final animatedDay = (_animation.value * _dummyRates.length).round().clamp(1, _dummyRates.length);

        return Column(
          children: [
            // ダミーサマリー
            _buildDummySummary(animatedDay),
            const SizedBox(height: 12),
            // ダミーグラフ
            BurnRateChart(
              dailyRates: _dummyRates,
              todayDay: animatedDay,
              daysInMonth: 30,
              startDay: 1,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDummySummary(int day) {
    final rate = day > 0 && day <= _dummyRates.length ? _dummyRates[day - 1] : 0.0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.accentBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Text(
                '${rate.toStringAsFixed(0)}%',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBlue.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '¥--- / ¥---',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textMuted.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required String subMessage,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: context.appTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.label(context, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            width: double.infinity,
            child: Text(
              subMessage,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption(context),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap() {
    if (widget.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BurnRateDetailScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
  }

  // ヘルパーメソッド（analytics_screen.dartから移植）
  int _getStartDayInCycle(List<dynamic> expenses, DateTime cycleStart) {
    if (expenses.isEmpty) return 1;

    DateTime? earliestDate;
    for (final e in expenses) {
      if (earliestDate == null || e.createdAt.isBefore(earliestDate)) {
        earliestDate = e.createdAt;
      }
    }

    if (earliestDate == null) return 1;

    final earliestDay = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);
    final cycleStartDay = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
    return earliestDay.difference(cycleStartDay).inDays + 1;
  }

  List<double> _calculateDailyBurnRates(
      AppState appState, int disposable, int daysInCycle, DateTime cycleStart) {
    final expenses = appState.thisMonthExpenses;
    final rates = List<double>.filled(daysInCycle, 0.0);

    // 日ごとの支出を集計
    final dailyTotals = <int, int>{};
    for (final e in expenses) {
      final dayIndex = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day)
          .difference(DateTime(cycleStart.year, cycleStart.month, cycleStart.day))
          .inDays;
      if (dayIndex >= 0 && dayIndex < daysInCycle) {
        dailyTotals[dayIndex] = (dailyTotals[dayIndex] ?? 0) + e.amount;
      }
    }

    // 累積率を計算
    int cumulative = 0;
    for (var i = 0; i < daysInCycle; i++) {
      cumulative += dailyTotals[i] ?? 0;
      rates[i] = (cumulative / disposable) * 100;
    }

    return rates;
  }
}
