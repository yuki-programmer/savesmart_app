import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../models/expense.dart';
import '../services/app_state.dart';
import '../services/performance_service.dart';
import '../utils/formatters.dart';
import '../widgets/burn_rate_chart.dart';
import '../widgets/analytics/category_pace_sheet.dart';
import '../widgets/analytics/monthly_expense_trend_chart.dart';
import 'category_detail_screen.dart';
import 'fixed_cost_history_screen.dart';
import 'premium_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with ScreenTraceMixin {
  @override
  String get screenTraceName => 'Analytics';

  // アコーディオンの開閉状態
  bool _categoryExpanded = false;
  bool _paceExpanded = false;
  bool _burnRateExpanded = false;
  bool _fixedCostsExpanded = false;

  // カテゴリ別グラフで固定費を含めるかどうか（デフォルト: false = 固定費抜き）
  bool _includeFixedCosts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
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

                  // アコーディオン A: カテゴリ別の支出割合
                  _buildAccordionCard(
                    title: 'カテゴリ別の支出割合',
                    subtitle: 'お金の偏りが見えてきます',
                    isExpanded: _categoryExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _categoryExpanded = expanded);
                      }
                    },
                    contentBuilder: (_) => _buildCategoryContent(isPremium),
                    icon: Icons.pie_chart_outline,
                    summary: _getCategorySummary(appState),
                    maskedSummary: _getCategoryMaskedSummary(appState),
                  ),
                  const SizedBox(height: 12),

                  // アコーディオン B: 1日あたりの支出
                  _buildAccordionCard(
                    title: '1日あたりの支出',
                    subtitle: '今の使い方を数字で見る',
                    isExpanded: _paceExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _paceExpanded = expanded);
                      }
                    },
                    contentBuilder: (_) => _buildPaceContent(appState),
                    icon: Icons.speed,
                    summary: _getPaceSummary(appState),
                    maskedSummary: '1日 約¥--- / 週 約¥---',
                  ),
                  const SizedBox(height: 12),

                  // アコーディオン C: 支出ペース
                  _buildAccordionCard(
                    title: '支出ペース',
                    subtitle: '変動費の累積推移',
                    isExpanded: _burnRateExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _burnRateExpanded = expanded);
                      }
                    },
                    contentBuilder: (_) => _buildBurnRateContent(appState),
                    icon: Icons.show_chart,
                    summary: _getBurnRateSummary(appState),
                    maskedSummary: '消化率 --%',
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

  // ============================================
  // サマリー計算メソッド
  // ============================================

  /// カテゴリ別サマリー: 最大カテゴリ名と割合
  String _getCategorySummary(AppState appState) {
    final categoryStats = appState.categoryStats;
    if (categoryStats.isEmpty) return '-';

    // 最大カテゴリを取得
    String? topCategory;
    int topAmount = 0;
    int total = 0;

    for (final entry in categoryStats.entries) {
      final amount = entry.value.totalAmount;
      total += amount;
      if (amount > topAmount) {
        topAmount = amount;
        topCategory = entry.key;
      }
    }

    if (topCategory == null || total == 0) return '-';

    final percentage = ((topAmount / total) * 100).round();
    return '$topCategoryが最多（$percentage%）';
  }

  /// カテゴリ別マスクサマリー（Free用）
  String _getCategoryMaskedSummary(AppState appState) {
    final categoryStats = appState.categoryStats;
    if (categoryStats.isEmpty) return '-';
    return '●●が最多';
  }

  /// 日割り・ペースサマリー（経過日数ベース）
  String _getPaceSummary(AppState appState) {
    final totalThisMonth = appState.thisMonthTotal;
    if (totalThisMonth == 0) return '-';

    final elapsedDays = _getElapsedDays(appState);
    if (elapsedDays <= 0) return '-';

    final dailyPace = totalThisMonth / elapsedDays;
    final weeklyPace = dailyPace * 7;

    return '1日 約¥${formatNumber(_roundToHundred(dailyPace))} / 週 約¥${formatNumber(_roundToHundred(weeklyPace))}';
  }

  /// 経過日数を計算（サイクル開始日〜今日、今日を含む）
  int _getElapsedDays(AppState appState) {
    final cycleStart = appState.cycleStartDate;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final cycleStartDate = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
    return todayDate.difference(cycleStartDate).inDays + 1;
  }

  /// 支出ペースサマリー: 消化率を表示
  String _getBurnRateSummary(AppState appState) {
    final income = appState.thisMonthAvailableAmount;
    final disposable = appState.disposableAmount;
    final variableSpending = appState.thisMonthTotal;

    if (income == null) return '収入を設定してください';
    if (disposable == null || disposable <= 0) return '可処分金額なし';

    final rate = (variableSpending / disposable) * 100;
    return '消化率 ${rate.toStringAsFixed(0)}%';
  }

  Widget _buildHeader() {
    return Text(
      '分析',
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary.withValues(alpha: 0.9),
        height: 1.3,
      ),
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
    final totalExpense = appState.thisMonthTotal + fixedCostsTotal;
    final availableAmount = appState.thisMonthAvailableAmount;
    final remainingDays = appState.remainingDaysInMonth;
    final cyclePeriod = _getCyclePeriodLabel(appState);
    final remaining = (availableAmount ?? 0) - totalExpense;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー：タイトル + サイクル期間 + 残り日数
          Row(
            children: [
              Text(
                '今サイクルのまとめ',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  height: 1.4,
                ),
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
                  color: AppColors.bgPrimary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'あと$remainingDays日',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
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
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '¥${formatNumber(remaining)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      color: remaining < 0 ? AppColors.accentRed : AppColors.textPrimary.withValues(alpha: 0.9),
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
              color: AppColors.bgPrimary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
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
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
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
                            : AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 支出行
                Row(
                  children: [
                    Text(
                      '支出',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${formatNumber(totalExpense)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.85),
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

  /// アコーディオンカード（アイコン+サマリー付き）
  /// contentBuilder: 遅延ビルド用。展開時のみビルドされる
  Widget _buildAccordionCard({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required bool isPremium,
    required ValueChanged<bool> onExpansionChanged,
    required WidgetBuilder contentBuilder,
    required IconData icon,
    required String summary,
    required String maskedSummary,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: isPremium
          ? _buildPremiumAccordion(
              title: title,
              isExpanded: isExpanded,
              onExpansionChanged: onExpansionChanged,
              contentBuilder: contentBuilder,
              icon: icon,
              summary: summary,
            )
          : _buildLockedAccordion(
              title: title,
              subtitle: subtitle,
              icon: icon,
              maskedSummary: maskedSummary,
            ),
    );
  }

  /// Premium ユーザー用: 開閉可能なアコーディオン（アイコン+サマリー付き）
  /// contentBuilder: 遅延ビルド用。展開時のみビルドされる
  Widget _buildPremiumAccordion({
    required String title,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required WidgetBuilder contentBuilder,
    required IconData icon,
    required String summary,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(
          icon,
          size: 20,
          color: AppColors.accentBlue.withValues(alpha: 0.8),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withValues(alpha: 0.9),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              summary,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                height: 1.3,
              ),
            ),
          ],
        ),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.expand_more,
            color: AppColors.textMuted.withValues(alpha: 0.6),
            size: 22,
          ),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        // 遅延ビルド: 展開時のみcontentBuilderが呼ばれる
        children: [if (isExpanded) contentBuilder(context)],
      ),
    );
  }

  /// Free ユーザー用: ロック表示（アイコン+マスクサマリー付き、タップでPremium画面へ）
  Widget _buildLockedAccordion({
    required String title,
    required String subtitle,
    required IconData icon,
    required String maskedSummary,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PremiumScreen()),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: AppColors.textMuted.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    maskedSummary,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            // Plus バッジ
            _buildPlusBadge(),
          ],
        ),
      ),
    );
  }

  /// Plus バッジ（ロックセクション用）
  Widget _buildPlusBadge() {
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
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 4),
          Text(
            'Plus',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // カテゴリ用のカラーパレット
  static const List<Color> _categoryColors = [
    AppColors.accentOrange,
    AppColors.accentGreen,
    AppColors.accentBlue,
    AppColors.accentPurple,
    Color(0xFF00BCD4), // cyan
    Color(0xFFFF5722), // deep orange
    Color(0xFF9C27B0), // purple
    Color(0xFF607D8B), // blue grey
  ];

  /// カテゴリ別の使い方（実データ）
  Widget _buildCategoryContent(bool isPremium) {
    final appState = context.read<AppState>();
    final categoryStats = appState.categoryStats;
    final fixedCosts = appState.fixedCosts;

    // categoryStatsからitemsリストを生成
    final items = <Map<String, dynamic>>[];
    var colorIndex = 0;

    for (final entry in categoryStats.entries) {
      items.add({
        'category': entry.key,
        'amount': entry.value.totalAmount,
        'color': _categoryColors[colorIndex % _categoryColors.length],
      });
      colorIndex++;
    }

    // 固定費込みの場合、固定費を追加
    if (_includeFixedCosts && fixedCosts.isNotEmpty) {
      // 固定費をカテゴリごとに集計
      final fixedCostsByCategory = <String, int>{};
      for (final fc in fixedCosts) {
        final categoryName = fc.categoryNameSnapshot ?? '固定費';
        fixedCostsByCategory[categoryName] =
            (fixedCostsByCategory[categoryName] ?? 0) + fc.amount;
      }

      // 既存のカテゴリに固定費を追加、または新規カテゴリとして追加
      for (final entry in fixedCostsByCategory.entries) {
        final existingIndex = items.indexWhere((item) => item['category'] == entry.key);
        if (existingIndex >= 0) {
          // 既存カテゴリに金額を加算
          items[existingIndex]['amount'] =
              (items[existingIndex]['amount'] as int) + entry.value;
        } else {
          // 新規カテゴリとして追加
          items.add({
            'category': entry.key,
            'amount': entry.value,
            'color': _categoryColors[colorIndex % _categoryColors.length],
          });
          colorIndex++;
        }
      }
    }

    // データがない場合
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            '記録するとここに表示されます',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ),
      );
    }

    // 金額順でソート（大きい順）
    items.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

    final total = items.fold(0, (sum, item) => sum + (item['amount'] as int));

    return Column(
      children: [
        // 固定費込み/抜き切り替えボタン
        _buildFixedCostsToggle(),
        const SizedBox(height: 16),
        // 円グラフ
        _buildCategoryPieChart(items, total, isPremium),
        const SizedBox(height: 20),
        // カテゴリリスト
        _buildCategoryList(items, total, isPremium),
      ],
    );
  }

  /// 固定費込み/抜き切り替えボタン
  Widget _buildFixedCostsToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_includeFixedCosts) {
                  setState(() => _includeFixedCosts = false);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_includeFixedCosts ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: !_includeFixedCosts
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '固定費抜き',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: !_includeFixedCosts ? FontWeight.w600 : FontWeight.w400,
                      color: !_includeFixedCosts
                          ? AppColors.textPrimary
                          : AppColors.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_includeFixedCosts) {
                  setState(() => _includeFixedCosts = true);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _includeFixedCosts ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _includeFixedCosts
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    '固定費込み',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: _includeFixedCosts ? FontWeight.w600 : FontWeight.w400,
                      color: _includeFixedCosts
                          ? AppColors.textPrimary
                          : AppColors.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 円グラフウィジェット（独立したStatefulWidgetを使用）
  Widget _buildCategoryPieChart(List<Map<String, dynamic>> items, int total, bool isPremium) {
    return _CategoryPieChart(
      items: items,
      total: total,
      isPremium: isPremium,
    );
  }

  /// カテゴリリストウィジェット
  Widget _buildCategoryList(List<Map<String, dynamic>> items, int total, bool isPremium) {
    return Column(
      children: items.map((item) {
        final amount = item['amount'] as int;
        final percentage = ((amount / total) * 100).round();
        final color = item['color'] as Color;
        final category = item['category'] as String;

        Widget rowContent = Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // カラーインジケーター（Heroアニメーション対応）
              Hero(
                tag: 'category_$category',
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '¥${formatNumber(amount)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$percentage%',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              // Premiumの場合のみ矢印アイコンを表示
              if (isPremium) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textMuted.withValues(alpha: 0.4),
                ),
              ],
            ],
          ),
        );

        // Premium の場合のみタップ可能
        if (isPremium) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  final appState = context.read<AppState>();
                  final categoryObj = appState.categories.firstWhere(
                    (c) => c.name == category,
                    orElse: () => appState.categories.first,
                  );
                  if (categoryObj.id != null) {
                    showCategoryDetailScreen(context, categoryObj.id!, category, color);
                  }
                },
                child: rowContent,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: rowContent,
        );
      }).toList(),
    );
  }

  /// 百円単位で丸める（例: 52167 -> 52200）
  int _roundToHundred(double value) {
    return ((value / 100).round() * 100);
  }

  /// 日割り・ペース（実データ - 2段表示、経過日数ベース）
  Widget _buildPaceContent(AppState appState) {
    final categoryStats = appState.categoryStats;
    final totalThisMonth = appState.thisMonthTotal;

    // 経過日数を取得（サイクル開始日〜今日、今日を含む）
    final elapsedDays = _getElapsedDays(appState);

    // カテゴリ別の日割り・週割りを計算（経過日数ベース）
    final items = <Map<String, dynamic>>[];
    for (final entry in categoryStats.entries) {
      final total = entry.value.totalAmount;
      if (total <= 0) continue; // 0円カテゴリは表示しない

      final dailyPace = elapsedDays > 0 ? total / elapsedDays : 0.0;
      final weeklyPace = dailyPace * 7;
      items.add({
        'label': entry.key,
        'total': total,
        'dailyPace': _roundToHundred(dailyPace),
        'weeklyPace': _roundToHundred(weeklyPace),
      });
    }

    // 合計降順でソート
    items.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

    // 全体の日割り・週割り（経過日数ベース）
    final totalDailyPace = elapsedDays > 0 ? totalThisMonth / elapsedDays : 0.0;
    final totalWeeklyPace = totalDailyPace * 7;

    // データがない場合
    if (items.isEmpty && totalThisMonth == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Text(
            '記録するとここに表示されます',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // カテゴリ別ペース（上位3件まで）
        ...items.take(3).map((item) {
          return _buildPaceItem(
            label: item['label'] as String,
            dailyPace: item['dailyPace'] as int,
            weeklyPace: item['weeklyPace'] as int,
            isTotal: false,
          );
        }),
        // 4件以上ある場合は「すべて見る」ボタン
        if (items.length > 3)
          GestureDetector(
            onTap: () => showAllCategoriesPaceSheet(context, items: items, monthDays: elapsedDays),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '他${items.length - 3}件を見る',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        // 全体ペース
        if (totalThisMonth > 0)
          _buildPaceItem(
            label: '全体',
            dailyPace: _roundToHundred(totalDailyPace),
            weeklyPace: _roundToHundred(totalWeeklyPace),
            isTotal: true,
          ),
      ],
    );
  }

  /// ペースアイテム（2段表示）
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

  /// 支出ペース（累積支出率グラフ）
  /// disposable = income - fixedCostsTotal
  /// variableSpending = thisMonthTotal (expenses only, not fixed costs)
  Widget _buildBurnRateContent(AppState appState) {
    final income = appState.thisMonthAvailableAmount;
    final fixedCostsTotal = appState.fixedCostsTotal;
    final disposable = appState.disposableAmount;
    final variableSpending = appState.thisMonthTotal; // 変動費のみ
    final now = DateTime.now();

    // サイクルベースの日数計算
    final cycleStart = appState.cycleStartDate;
    final cycleEnd = appState.cycleEndDate;
    final daysInCycle = cycleEnd.difference(cycleStart).inDays + 1;

    // 今日がサイクル内の何日目か（1-indexed）
    final today = DateTime(now.year, now.month, now.day);
    final todayInCycle = today.difference(cycleStart).inDays + 1;

    // 収入が未設定の場合
    if (income == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: AppColors.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '収入が未設定です',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '追加画面から設定できます',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    // 可処分金額が0以下の場合（グラフなし、事実のみ表示）
    if (disposable == null || disposable <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            // 収入 - 固定費 = 可処分 の表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '収入 ¥${formatNumber(income)} − 固定費 ¥${formatNumber(fixedCostsTotal)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '= ¥${formatNumber(disposable ?? 0)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '可処分金額が0以下のため、グラフを表示できません',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textMuted.withValues(alpha: 0.7),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // サイクル内の記録開始日を取得（サイクル開始日からの日数）
    final startDay = _getStartDayInCycle(appState.thisMonthExpenses, cycleStart);

    // 日ごとの累積支出率を計算（変動費 / 可処分金額）
    final dailyRates = _calculateDailyBurnRates(appState, disposable, daysInCycle, cycleStart);
    final currentRate = todayInCycle > 0 && todayInCycle <= dailyRates.length
        ? dailyRates[todayInCycle - 1]
        : 0.0;
    final isOver100 = currentRate > 100;

    // 前サイクルデータと比較差額をFutureBuilderで取得
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        appState.getPreviousCycleBurnRateData(),
        appState.getCycleComparisonDiff(),
      ]),
      builder: (context, snapshot) {
        // 前サイクルデータ
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
            // 収入 - 固定費 = 可処分 の表示
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '収入 ¥${formatNumber(income)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      ' − ',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '固定費 ¥${formatNumber(fixedCostsTotal)}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      ' = ',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      '¥${formatNumber(disposable)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 現在の消化率（数値）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isOver100
                    ? AppColors.accentRed.withValues(alpha: 0.08)
                    : AppColors.bgPrimary.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    '変動費:',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currentRate.toStringAsFixed(0)}%',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: isOver100 ? AppColors.accentRed : AppColors.accentBlue,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '¥${formatNumber(variableSpending)} / ¥${formatNumber(disposable)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 前サイクル比較バッジ（データがある場合のみ表示）
            if (comparisonDiff != null) _buildComparisonBadge(comparisonDiff),
            if (comparisonDiff != null) const SizedBox(height: 12),

            // 折れ線グラフ（サイクルベース）
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

  /// 前サイクル比較バッジを構築
  Widget _buildComparisonBadge(int diff) {
    final isSaving = diff >= 0;
    final color = isSaving ? AppColors.accentGreen : AppColors.accentOrange;
    final icon = isSaving ? Icons.trending_down : Icons.trending_up;
    final label = isSaving ? '節約中' : '使いすぎ';
    final diffText = isSaving
        ? '-¥${formatNumber(diff)}'
        : '+¥${formatNumber(diff.abs())}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '前サイクル比 $diffText',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// サイクル内で最初の記録日（サイクル開始日からの日数、1-indexed）を取得
  int _getStartDayInCycle(List<Expense> expenses, DateTime cycleStart) {
    if (expenses.isEmpty) return 1;

    int minDayInCycle = 999;
    for (final expense in expenses) {
      final expenseDate = DateTime(
        expense.createdAt.year,
        expense.createdAt.month,
        expense.createdAt.day,
      );
      final dayInCycle = expenseDate.difference(cycleStart).inDays + 1;
      if (dayInCycle > 0 && dayInCycle < minDayInCycle) {
        minDayInCycle = dayInCycle;
      }
    }
    return minDayInCycle == 999 ? 1 : minDayInCycle;
  }

  /// 日ごとの累積支出率を計算（サイクルベース）
  List<double> _calculateDailyBurnRates(
    AppState appState,
    int availableAmount,
    int daysInCycle,
    DateTime cycleStart,
  ) {
    final expenses = appState.thisMonthExpenses;

    // サイクル内の日ごとの支出を集計
    final dailyExpenses = List<int>.filled(daysInCycle, 0);
    for (final expense in expenses) {
      final expenseDate = DateTime(
        expense.createdAt.year,
        expense.createdAt.month,
        expense.createdAt.day,
      );
      final dayInCycle = expenseDate.difference(cycleStart).inDays + 1;
      if (dayInCycle >= 1 && dayInCycle <= daysInCycle) {
        dailyExpenses[dayInCycle - 1] += expense.amount;
      }
    }

    // 累積支出率を計算
    final dailyRates = <double>[];
    int cumulative = 0;
    for (var i = 0; i < daysInCycle; i++) {
      cumulative += dailyExpenses[i];
      final rate = (cumulative / availableAmount) * 100;
      dailyRates.add(rate);
    }

    return dailyRates;
  }

  /// 固定費セクション（アコーディオン形式）
  Widget _buildFixedCostsSection(AppState appState) {
    final fixedCosts = appState.fixedCosts;
    final totalFixedCosts = appState.fixedCostsTotal;
    final currencyFormat = appState.currencyFormat;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
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
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '固定費',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '合計 ¥${formatNumber(totalFixedCosts)}',
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
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
                              color: AppColors.accentBlue.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.accentBlue.withValues(alpha: 0.6),
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
                      color: AppColors.textMuted.withValues(alpha: 0.6),
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
                                        color: AppColors.textSecondary.withValues(alpha: 0.9),
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
                                      color: AppColors.textPrimary.withValues(alpha: 0.85),
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
                              color: AppColors.textMuted.withValues(alpha: 0.7),
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

/// 円グラフウィジェット（独立したStateを持つ）
/// タッチ処理をAnalyticsScreen全体から分離し、パフォーマンスを改善
class _CategoryPieChart extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int total;
  final bool isPremium;

  const _CategoryPieChart({
    required this.items,
    required this.total,
    required this.isPremium,
  });

  @override
  State<_CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<_CategoryPieChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          pieTouchData: widget.isPremium
              ? PieTouchData(
                  touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    });

                    // タップ終了時（指を離したとき）に詳細画面へ遷移
                    if (event is FlTapUpEvent &&
                        pieTouchResponse != null &&
                        pieTouchResponse.touchedSection != null) {
                      final index = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      if (index >= 0 && index < widget.items.length) {
                        final item = widget.items[index];
                        final categoryName = item['category'] as String;
                        final color = item['color'] as Color;
                        // カテゴリIDを取得
                        final appState = context.read<AppState>();
                        final categoryObj = appState.categories.firstWhere(
                          (c) => c.name == categoryName,
                          orElse: () => appState.categories.first,
                        );
                        if (categoryObj.id != null) {
                          showCategoryDetailScreen(context, categoryObj.id!, categoryName, color);
                        }
                      }
                    }
                  },
                )
              : null,
          sections: widget.items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final amount = item['amount'] as int;
            final percentage = (amount / widget.total) * 100;
            final color = item['color'] as Color;
            final isTouched = widget.isPremium && index == _touchedIndex;

            return PieChartSectionData(
              value: amount.toDouble(),
              title: '${percentage.round()}%',
              color: color,
              radius: isTouched ? 58 : 50,
              titleStyle: GoogleFonts.ibmPlexSans(
                fontSize: isTouched ? 14 : 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
