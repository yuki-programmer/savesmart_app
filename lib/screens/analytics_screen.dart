import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../widgets/income_sheet.dart';
import '../widgets/burn_rate_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  // アコーディオンの開閉状態
  bool _categoryExpanded = false;
  bool _paceExpanded = false;
  bool _burnRateExpanded = false;
  bool _detailExpanded = false;

  // incomeSheet自動起動用フラグ（2重起動防止）
  bool _incomeSheetOpening = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkIncomeSheetRequest();
  }

  void _checkIncomeSheetRequest() {
    if (_incomeSheetOpening) return;

    final appState = context.read<AppState>();
    if (appState.consumeOpenIncomeSheetRequest()) {
      _incomeSheetOpening = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showIncomeSheet(context, DateTime.now()).then((_) {
          _incomeSheetOpening = false;
        });
      });
    }
  }

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

                  // アコーディオン A: カテゴリ別の使い方
                  _buildAccordionCard(
                    title: 'カテゴリ別の使い方',
                    subtitle: 'お金の偏りが見えてきます',
                    isExpanded: _categoryExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _categoryExpanded = expanded);
                      }
                    },
                    content: _buildCategoryContent(isPremium),
                  ),
                  const SizedBox(height: 12),

                  // アコーディオン B: 日割り・ペース
                  _buildAccordionCard(
                    title: '日割り・ペース',
                    subtitle: '月末の着地が見えてきます',
                    isExpanded: _paceExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _paceExpanded = expanded);
                      }
                    },
                    content: _buildPaceContent(),
                  ),
                  const SizedBox(height: 12),

                  // アコーディオン C: 予算消化ペース
                  _buildAccordionCard(
                    title: '予算消化ペース',
                    subtitle: '今月の累積支出率（事実のみ）',
                    isExpanded: _burnRateExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _burnRateExpanded = expanded);
                      }
                    },
                    content: _buildBurnRateContent(appState),
                  ),
                  const SizedBox(height: 12),

                  // アコーディオン D: 詳細
                  _buildAccordionCard(
                    title: '詳細',
                    subtitle: '自分の"賢い使い方"が見えてきます',
                    isExpanded: _detailExpanded,
                    isPremium: isPremium,
                    onExpansionChanged: (expanded) {
                      if (isPremium) {
                        setState(() => _detailExpanded = expanded);
                      }
                    },
                    content: _buildDetailContent(),
                  ),
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
      style: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary.withOpacity(0.9),
        height: 1.3,
      ),
    );
  }

  /// 今月のまとめセクション（Free でも表示）
  Widget _buildMonthlySummary(AppState appState) {
    final fixedCostsTotal = appState.fixedCosts.fold(0, (sum, fc) => sum + fc.amount);
    final total = appState.thisMonthTotal + fixedCostsTotal;
    final savings = appState.thisMonthSavings;
    final isPositive = savings >= 0;
    final availableAmount = appState.thisMonthAvailableAmount;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今月のまとめ',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '支出合計',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textMuted.withOpacity(0.8),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '¥${_formatNumber(total)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.bgPrimary,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'お得額',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted.withOpacity(0.8),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${isPositive ? '+' : ''}¥${_formatNumber(savings)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: isPositive
                              ? AppColors.accentGreen
                              : AppColors.accentRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // 使える金額の行
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bgPrimary.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: GestureDetector(
              onTap: () => showIncomeSheet(context, DateTime.now()),
              child: Row(
                children: [
                  Text(
                    '使える金額：',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      availableAmount != null
                          ? '¥${_formatNumber(availableAmount)}'
                          : '未設定',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: availableAmount != null
                            ? AppColors.textPrimary.withOpacity(0.9)
                            : AppColors.textMuted.withOpacity(0.6),
                      ),
                    ),
                  ),
                  Text(
                    availableAmount != null ? '変更' : '追加',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// アコーディオンカード
  Widget _buildAccordionCard({
    required String title,
    required String subtitle,
    required bool isExpanded,
    required bool isPremium,
    required ValueChanged<bool> onExpansionChanged,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
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
              content: content,
            )
          : _buildLockedAccordion(
              title: title,
              subtitle: subtitle,
            ),
    );
  }

  /// Premium ユーザー用: 開閉可能なアコーディオン
  Widget _buildPremiumAccordion({
    required String title,
    required bool isExpanded,
    required ValueChanged<bool> onExpansionChanged,
    required Widget content,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withOpacity(0.9),
            height: 1.4,
          ),
        ),
        trailing: AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            Icons.expand_more,
            color: AppColors.textMuted.withOpacity(0.6),
            size: 22,
          ),
        ),
        initiallyExpanded: isExpanded,
        onExpansionChanged: onExpansionChanged,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [content],
      ),
    );
  }

  /// Free ユーザー用: ロック表示（完全に非インタラクティブ）
  Widget _buildLockedAccordion({
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted.withOpacity(0.9),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary.withOpacity(0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_open_outlined,
            size: 17,
            color: AppColors.textSecondary.withOpacity(0.4),
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
              color: AppColors.textMuted.withOpacity(0.8),
              height: 1.4,
            ),
          ),
        ),
      );
    }

    final total = items.fold(0, (sum, item) => sum + (item['amount'] as int));

    return Column(
      children: [
        // 円グラフ
        _buildCategoryPieChart(items, total),
        const SizedBox(height: 20),
        // カテゴリリスト
        _buildCategoryList(items, total, isPremium),
      ],
    );
  }

  /// 円グラフウィジェット
  Widget _buildCategoryPieChart(List<Map<String, dynamic>> items, int total) {
    return SizedBox(
      height: 180,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: items.map((item) {
            final amount = item['amount'] as int;
            final percentage = (amount / total) * 100;
            final color = item['color'] as Color;

            return PieChartSectionData(
              value: amount.toDouble(),
              title: '${percentage.round()}%',
              color: color,
              radius: 50,
              titleStyle: GoogleFonts.ibmPlexSans(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              // カラーインジケーター
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
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
                '¥${_formatNumber(amount)}',
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
                  color: color.withOpacity(0.15),
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
            ],
          ),
        );

        // Premium の場合のみタップ可能
        if (isPremium) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showCategoryBreakdownSheet(category),
                child: rowContent,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: rowContent,
        );
      }).toList(),
    );
  }

  /// カテゴリ別グレード内訳BottomSheet
  void _showCategoryBreakdownSheet(String categoryName) {
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
      builder: (context) => _buildBreakdownSheetContent(
        categoryName: categoryName,
        breakdown: breakdown,
        dominantGrade: dominantGrade,
      ),
    );
  }

  Widget _buildBreakdownSheetContent({
    required String categoryName,
    required Map<String, Map<String, int>> breakdown,
    required String? dominantGrade,
  }) {
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
    if (dominantGrade != null && maxCountIsSignificant(breakdown)) {
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
                  color: AppColors.textMuted.withOpacity(0.25),
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
                  color: AppColors.textPrimary.withOpacity(0.9),
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
                        ? color.withOpacity(0.08)
                        : AppColors.bgPrimary.withOpacity(0.5),
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
                              ? color.withOpacity(0.15)
                              : AppColors.textMuted.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          icon,
                          size: 16,
                          color: hasData ? color : AppColors.textMuted.withOpacity(0.5),
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
                                ? AppColors.textPrimary.withOpacity(0.9)
                                : AppColors.textMuted.withOpacity(0.6),
                            height: 1.4,
                          ),
                        ),
                      ),
                      // 金額
                      Text(
                        '¥${_formatNumber(amount)}',
                        style: GoogleFonts.ibmPlexSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: hasData
                              ? AppColors.textPrimary.withOpacity(0.9)
                              : AppColors.textMuted.withOpacity(0.5),
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
                              ? AppColors.textSecondary.withOpacity(0.7)
                              : AppColors.textMuted.withOpacity(0.4),
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
                      color: AppColors.textSecondary.withOpacity(0.8),
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

  /// 最も多いグレードが有意かどうかを判定（データが1件以上ある場合）
  bool maxCountIsSignificant(Map<String, Map<String, int>> breakdown) {
    int totalCount = 0;
    for (final data in breakdown.values) {
      totalCount += data['count'] ?? 0;
    }
    return totalCount > 0;
  }

  /// 百円単位で丸める（例: 52167 -> 52200）
  int _roundToHundred(double value) {
    return ((value / 100).round() * 100);
  }

  /// 日割り・ペース（実データ - 2段表示）
  Widget _buildPaceContent() {
    final appState = context.read<AppState>();
    final categoryStats = appState.categoryStats;
    final totalThisMonth = appState.thisMonthTotal;

    // 当月の日数を取得
    final now = DateTime.now();
    final monthDays = DateTime(now.year, now.month + 1, 0).day;

    // カテゴリ別の日割り・週割りを計算
    final items = <Map<String, dynamic>>[];
    for (final entry in categoryStats.entries) {
      final total = entry.value.totalAmount;
      if (total <= 0) continue; // 0円カテゴリは表示しない

      final dailyPace = total / monthDays;
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

    // 全体の日割り・週割り
    final totalDailyPace = totalThisMonth / monthDays;
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
              color: AppColors.textMuted.withOpacity(0.8),
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
            onTap: () => _showAllCategoriesPaceSheet(items, monthDays),
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
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.expand_more,
                    size: 16,
                    color: AppColors.textSecondary.withOpacity(0.6),
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

  /// 全カテゴリのペースを表示するBottomSheet
  void _showAllCategoriesPaceSheet(List<Map<String, dynamic>> items, int monthDays) {
    final appState = context.read<AppState>();
    final totalThisMonth = appState.thisMonthTotal;
    final totalDailyPace = totalThisMonth / monthDays;
    final totalWeeklyPace = totalDailyPace * 7;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
                    color: AppColors.textMuted.withOpacity(0.25),
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
                        color: AppColors.textPrimary.withOpacity(0.9),
                        height: 1.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${items.length}カテゴリ',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary.withOpacity(0.7),
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
                        dailyPace: _roundToHundred(totalDailyPace),
                        weeklyPace: _roundToHundred(totalWeeklyPace),
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
            ? AppColors.accentBlue.withOpacity(0.06)
            : AppColors.bgPrimary.withOpacity(0.7),
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
                  : AppColors.textPrimary.withOpacity(0.9),
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
                        color: AppColors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '¥${_formatNumber(dailyPace)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isTotal
                            ? AppColors.accentBlue
                            : AppColors.textPrimary.withOpacity(0.9),
                      ),
                    ),
                    Text(
                      '/日',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary.withOpacity(0.8),
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
                      color: AppColors.textMuted.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '¥${_formatNumber(weeklyPace)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isTotal
                          ? AppColors.accentBlue.withOpacity(0.8)
                          : AppColors.textSecondary.withOpacity(0.8),
                    ),
                  ),
                  Text(
                    '/週',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withOpacity(0.6),
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

  /// 予算消化ペース（累積支出率グラフ）
  Widget _buildBurnRateContent(AppState appState) {
    final availableAmount = appState.thisMonthAvailableAmount;
    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final todayDay = now.day;

    // 使える金額が未設定の場合
    if (availableAmount == null || availableAmount <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 36,
              color: AppColors.textMuted.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              '「使える金額」が未設定です',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => showIncomeSheet(context, DateTime.now()),
              child: Text(
                '設定する',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 日ごとの累積支出率を計算
    final dailyRates = _calculateDailyBurnRates(appState, availableAmount, daysInMonth);
    final currentRate = todayDay > 0 && todayDay <= dailyRates.length
        ? dailyRates[todayDay - 1]
        : 0.0;
    final isOver100 = currentRate > 100;

    return Column(
      children: [
        // 現在の消化率（数値）
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isOver100
                ? AppColors.accentRed.withOpacity(0.08)
                : AppColors.bgPrimary.withOpacity(0.7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Text(
                '現在:',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withOpacity(0.8),
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
                '¥${_formatNumber(appState.thisMonthTotal)} / ¥${_formatNumber(availableAmount)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 折れ線グラフ
        BurnRateChart(
          dailyRates: dailyRates,
          todayDay: todayDay,
          daysInMonth: daysInMonth,
        ),
      ],
    );
  }

  /// 日ごとの累積支出率を計算
  List<double> _calculateDailyBurnRates(AppState appState, int availableAmount, int daysInMonth) {
    final expenses = appState.thisMonthExpenses;

    // 日ごとの支出を集計
    final dailyExpenses = List<int>.filled(daysInMonth, 0);
    for (final expense in expenses) {
      final day = expense.createdAt.day;
      if (day >= 1 && day <= daysInMonth) {
        dailyExpenses[day - 1] += expense.amount;
      }
    }

    // 累積支出率を計算
    final dailyRates = <double>[];
    int cumulative = 0;
    for (var i = 0; i < daysInMonth; i++) {
      cumulative += dailyExpenses[i];
      final rate = (cumulative / availableAmount) * 100;
      dailyRates.add(rate);
    }

    return dailyRates;
  }

  /// 詳細（ダミーコンテンツ）
  Widget _buildDetailContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: AppColors.textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'ここに円グラフや統計が入ります',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
