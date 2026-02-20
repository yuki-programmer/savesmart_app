import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../services/app_state.dart';
import '../services/performance_service.dart';
import '../utils/formatters.dart';
import '../widgets/analytics/burn_rate_card.dart';
import '../widgets/analytics/category_breakdown_card.dart';
import '../widgets/analytics/daily_pace_card.dart';
import '../widgets/analytics/monthly_expense_trend_chart.dart';
import 'fixed_cost_history_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with ScreenTraceMixin {
  @override
  String get screenTraceName => 'Analytics';

  // 固定費アコーディオンの開閉状態
  bool _fixedCostsExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      body: SafeArea(
        child: Consumer<AppState>(
          builder: (context, appState, child) {
            final isPremium = appState.isPremium;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ヘッダー
                  _buildHeader(),
                  const SizedBox(height: 24),

                  // 今月のまとめ（Free でも表示）
                  _buildMonthlySummary(appState),
                  const SizedBox(height: 20),

                  // 月間の支出推移（Free でも表示）
                  MonthlyExpenseTrendChart(appState: appState),
                  const SizedBox(height: 20),

                  // カテゴリ別の支出割合カード（常時表示）
                  CategoryBreakdownCard(
                    appState: appState,
                  ),
                  const SizedBox(height: 12),

                  // 1日あたりの支出カード（常時表示）
                  DailyPaceCard(
                    appState: appState,
                    isPremium: isPremium,
                  ),
                  const SizedBox(height: 12),

                  // 支出ペースカード（常時表示）
                  BurnRateCard(
                    appState: appState,
                    isPremium: isPremium,
                  ),
                  const SizedBox(height: 20),

                  // 固定費セクション（Free でも表示）
                  _buildFixedCostsSection(appState),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      '分析',
      style: AppTextStyles.pageTitle(context),
    );
  }

  /// サイクル期間ラベルを生成（例: 1/25 〜 2/24）
  String _getCyclePeriodLabel(AppState appState) {
    final startDate = appState.cycleStartDate;
    final endDate = appState.cycleEndDate;
    return '${startDate.month}/${startDate.day} 〜 ${endDate.month}/${endDate.day}';
  }

  /// 今サイクルのまとめセクション（Free でも表示）
  Widget _buildMonthlySummary(AppState appState) {
    final fixedCostsTotal = appState.fixedCostsTotal;
    final variableSpending = appState.thisMonthTotal;
    final totalExpense = variableSpending + fixedCostsTotal;
    final availableAmount = appState.thisMonthAvailableAmount;
    final remainingDays = appState.remainingDaysInMonth;
    final cyclePeriod = _getCyclePeriodLabel(appState);
    final remaining = (availableAmount ?? 0) - totalExpense;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー：タイトル + サイクル期間 + 残り日数
          Row(
            children: [
              Text(
                '今サイクルのまとめ',
                style: AppTextStyles.label(context, weight: FontWeight.w500),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cyclePeriod,
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accentBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.appTheme.bgCard,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: context.appTheme.borderSubtle,
                    width: 1,
                  ),
                ),
                child: Text(
                  'あと$remainingDays日',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // メイン：残り金額
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  '残り',
                  style: AppTextStyles.sub(context),
                ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${formatNumber(remaining)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: remaining < 0 ? AppColors.accentRed : context.appTheme.textPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 収入・支出の内訳
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.appTheme.borderSubtle,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // 収入行（表示のみ、編集はAdd画面から）
                Row(
                  children: [
                    Text(
                      '収入',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      availableAmount != null
                          ? '¥${formatNumber(availableAmount)}'
                          : '未設定',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: availableAmount != null
                            ? AppColors.accentBlue
                            : context.appTheme.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 変動費
                Row(
                  children: [
                    Text(
                      '変動費',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${formatNumber(variableSpending)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 固定費
                Row(
                  children: [
                    Text(
                      '固定費',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${formatNumber(fixedCostsTotal)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appTheme.textPrimary.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: context.appTheme.borderSubtle.withValues(alpha: 0.8),
                ),
                const SizedBox(height: 10),
                // 支出合計
                Row(
                  children: [
                    Text(
                      '支出合計',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textMuted.withValues(alpha: 0.9),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${formatNumber(totalExpense)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 固定費セクション（アコーディオン形式）
  Widget _buildFixedCostsSection(AppState appState) {
    final fixedCosts = appState.fixedCosts;
    final totalFixedCosts = appState.fixedCostsTotal;
    final currencyFormat = appState.currencyFormat;

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // ヘッダー（タップで開閉）
          GestureDetector(
            onTap: () {
              setState(() {
                _fixedCostsExpanded = !_fixedCostsExpanded;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '固定費',
                          style: AppTextStyles.sectionTitleSm(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '合計 ¥${formatNumber(totalFixedCosts)}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.appTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 編集ボタン
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FixedCostHistoryScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                        Text(
                          '編集',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.appTheme.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: context.appTheme.textMuted.withValues(alpha: 0.8),
                        ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _fixedCostsExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: context.appTheme.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 展開時の内訳
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (fixedCosts.isNotEmpty)
                        ...fixedCosts.map((fc) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      fc.name,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w400,
                                        color: context.appTheme.textSecondary.withValues(alpha: 0.9),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    currencyFormat == 'prefix'
                                        ? '¥${formatNumber(fc.amount)}'
                                        : '${formatNumber(fc.amount)}円',
                                    style: GoogleFonts.ibmPlexSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: context.appTheme.textPrimary.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      if (fixedCosts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            '固定費が登録されていません',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: context.appTheme.textMuted.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            crossFadeState: _fixedCostsExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}
