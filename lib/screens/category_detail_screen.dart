import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../config/category_icons.dart';
import '../services/app_state.dart';
import '../services/performance_service.dart';
import '../utils/formatters.dart';

/// カテゴリ詳細分析画面（PLUSプラン専用）
/// MBTI風の3セグメントバーと詳細カードを表示
class CategoryDetailScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;
  final Color categoryColor;

  const CategoryDetailScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
  });

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen>
    with SingleTickerProviderStateMixin, ScreenTraceMixin {
  @override
  String get screenTraceName => 'CategoryDetail';

  // 表示モード: 0 = 回数, 1 = 金額
  int _displayMode = 1;

  // アニメーションコントローラー
  late AnimationController _animationController;
  late Animation<double> _barAnimation;

  // 月別グラフ用スクロールコントローラー
  final ScrollController _chartScrollController = ScrollController();

  // グレードカラー定義
  static const _savingColor = Color(0xFF6B8E6B); // セージグリーン
  static const _standardColor = Color(0xFF6B7B8C); // ブルーグレー
  static const _rewardColor = Color(0xFFD4A853); // ゴールド

  // 分析データのキャッシュ（遅延ロード）
  Map<String, dynamic>? _analysisData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _barAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutQuart,
    );
    // 画面表示時にアニメーション開始＆データ読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
      _loadAnalysisData();
    });
  }

  /// 分析データを読み込む（遷移アニメーション後に実行）
  void _loadAnalysisData() {
    final appState = context.read<AppState>();
    final analysis = appState.getCategoryDetailAnalysis(widget.categoryName);
    if (mounted) {
      setState(() {
        _analysisData = analysis;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _chartScrollController.dispose();
    super.dispose();
  }

  void _toggleDisplayMode(int mode) {
    if (_displayMode != mode) {
      setState(() => _displayMode = mode);
      // モード切替時にアニメーションをリセット
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ヘッダー
            _buildHeader(context),
            // コンテンツ
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentBlue,
                      ),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// メインコンテンツ（データ読み込み後に表示）
  Widget _buildContent() {
    final analysis = _analysisData!;
    final thisMonth = analysis['thisMonth'] as Map<String, Map<String, int>>;
    final last6MonthsAvg = analysis['last6MonthsAvg'] as Map<String, Map<String, int>>;
    final totalAmount = analysis['totalAmount'] as int;
    final totalCount = analysis['totalCount'] as int;
    final appState = context.read<AppState>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリ名カード
          _buildCategoryNameCard(),
          const SizedBox(height: 24),
          // 回数/金額トグル
          _buildDisplayModeToggle(),
          const SizedBox(height: 24),
          // MBTI風3セグメントバー
          _buildMbtiBar(thisMonth, totalAmount, totalCount),
          const SizedBox(height: 32),
          // 詳細リスト
          _buildDetailList(thisMonth, last6MonthsAvg),
          const SizedBox(height: 32),
          // 時系列グラフ
          _buildMonthlyTrendSection(appState),
        ],
      ),
    );
  }

  /// ヘッダー（閉じるボタン）
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: context.appTheme.textSecondary.withValues(alpha: 0.8),
              size: 24,
            ),
            splashRadius: 24,
          ),
        ],
      ),
    );
  }

  /// カテゴリ名カード（Heroアニメーション対応）
  Widget _buildCategoryNameCard() {
    return Hero(
      tag: 'category_${widget.categoryName}',
      // アニメーション中はシンプルなコンテナを表示してオーバーフローを防ぐ
      flightShuttleBuilder: (
        BuildContext flightContext,
        Animation<double> animation,
        HeroFlightDirection flightDirection,
        BuildContext fromHeroContext,
        BuildContext toHeroContext,
      ) {
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: widget.categoryColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.appTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            boxShadow: context.cardElevationShadow,
          ),
          child: Builder(
            builder: (context) {
              // カテゴリのアイコンを取得
              final appState = context.read<AppState>();
              final category = appState.categories.firstWhere(
                (c) => c.name == widget.categoryName,
                orElse: () => appState.categories.first,
              );
              final iconData = CategoryIcons.getIcon(category.icon);

              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconData,
                      size: 22,
                      color: widget.categoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.categoryName,
                    style: AppTextStyles.pageTitle(context),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 回数/金額トグル（CupertinoSlidingSegmentedControl風）
  Widget _buildDisplayModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgPrimary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.05),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildToggleButton(0, '回数'),
          _buildToggleButton(1, '金額'),
        ],
      ),
    );
  }

  Widget _buildToggleButton(int mode, String label) {
    final isSelected = _displayMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _toggleDisplayMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? context.appTheme.textPrimary
                    : context.appTheme.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// MBTI風3セグメントバー
  Widget _buildMbtiBar(
    Map<String, Map<String, int>> thisMonth,
    int totalAmount,
    int totalCount,
  ) {
    // 表示モードに応じた値を取得
    final savingValue = _displayMode == 0
        ? thisMonth['saving']!['count']!
        : thisMonth['saving']!['amount']!;
    final standardValue = _displayMode == 0
        ? thisMonth['standard']!['count']!
        : thisMonth['standard']!['amount']!;
    final rewardValue = _displayMode == 0
        ? thisMonth['reward']!['count']!
        : thisMonth['reward']!['amount']!;

    final total = savingValue + standardValue + rewardValue;

    // パーセンテージ計算（0除算対策）
    final savingPct = total > 0 ? savingValue / total : 0.0;
    final standardPct = total > 0 ? standardValue / total : 0.0;
    final rewardPct = total > 0 ? rewardValue / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // ラベル行
          _buildBarLabels(savingPct, standardPct, rewardPct, savingValue, standardValue, rewardValue),
          const SizedBox(height: 12),
          // 3色バー
          AnimatedBuilder(
            animation: _barAnimation,
            builder: (context, child) {
              return _buildColorBar(
                savingPct * _barAnimation.value,
                standardPct * _barAnimation.value,
                rewardPct * _barAnimation.value,
              );
            },
          ),
          const SizedBox(height: 12),
          // 凡例
          _buildBarLegend(),
        ],
      ),
    );
  }

  /// バーの上のラベル（パーセンテージと実数）
  /// 8%未満のセグメントはラベルを非表示にして可読性を確保
  Widget _buildBarLabels(
    double savingPct,
    double standardPct,
    double rewardPct,
    int savingValue,
    int standardValue,
    int rewardValue,
  ) {
    // ラベル表示の閾値（8%未満は非表示）
    const labelThreshold = 0.08;

    return Row(
      children: [
        if (savingPct > 0)
          Expanded(
            flex: (savingPct * 100).round().clamp(1, 100),
            child: savingPct >= labelThreshold
                ? _buildLabelColumn(
                    '節約',
                    savingPct,
                    savingValue,
                    _savingColor,
                  )
                : const SizedBox.shrink(),
          ),
        if (standardPct > 0)
          Expanded(
            flex: (standardPct * 100).round().clamp(1, 100),
            child: standardPct >= labelThreshold
                ? _buildLabelColumn(
                    '標準',
                    standardPct,
                    standardValue,
                    _standardColor,
                  )
                : const SizedBox.shrink(),
          ),
        if (rewardPct > 0)
          Expanded(
            flex: (rewardPct * 100).round().clamp(1, 100),
            child: rewardPct >= labelThreshold
                ? _buildLabelColumn(
                    'ご褒美',
                    rewardPct,
                    rewardValue,
                    _rewardColor,
                  )
                : const SizedBox.shrink(),
          ),
        // 全て0の場合は「データなし」表示
        if (savingPct == 0 && standardPct == 0 && rewardPct == 0)
          Expanded(
            child: Center(
              child: Text(
                'データなし',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appTheme.textMuted,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLabelColumn(String label, double pct, int value, Color color) {
    return AnimatedBuilder(
      animation: _barAnimation,
      builder: (context, child) {
        return Column(
          children: [
            TweenAnimationBuilder<int>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
              tween: IntTween(begin: 0, end: (pct * 100).round()),
              builder: (context, val, child) {
                return Text(
                  '$val%',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                );
              },
            ),
            const SizedBox(height: 2),
            TweenAnimationBuilder<int>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutQuart,
              tween: IntTween(begin: 0, end: value),
              builder: (context, val, child) {
                return Text(
                  _displayMode == 0 ? '$val回' : '¥${formatNumber(val)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  /// 3色バー本体
  Widget _buildColorBar(double savingPct, double standardPct, double rewardPct) {
    // 全て0の場合はグレーのバーを表示
    if (savingPct == 0 && standardPct == 0 && rewardPct == 0) {
      return Container(
        height: 16,
        decoration: BoxDecoration(
          color: context.appTheme.bgPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 16,
        child: Row(
          children: [
            if (savingPct > 0)
              Expanded(
                flex: (savingPct * 1000).round().clamp(1, 1000),
                child: Container(color: _savingColor),
              ),
            if (standardPct > 0)
              Expanded(
                flex: (standardPct * 1000).round().clamp(1, 1000),
                child: Container(color: _standardColor),
              ),
            if (rewardPct > 0)
              Expanded(
                flex: (rewardPct * 1000).round().clamp(1, 1000),
                child: Container(color: _rewardColor),
              ),
          ],
        ),
      ),
    );
  }

  /// 凡例
  Widget _buildBarLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('節約', _savingColor),
        const SizedBox(width: 20),
        _buildLegendItem('標準', _standardColor),
        const SizedBox(width: 20),
        _buildLegendItem('ご褒美', _rewardColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: context.appTheme.textMuted.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// 詳細リスト（グレード別カード）
  Widget _buildDetailList(
    Map<String, Map<String, int>> thisMonth,
    Map<String, Map<String, int>> last6MonthsAvg,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'グレード別詳細',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        _buildGradeCard('節約', 'saving', _savingColor, thisMonth, last6MonthsAvg, 0),
        const SizedBox(height: 12),
        _buildGradeCard('標準', 'standard', _standardColor, thisMonth, last6MonthsAvg, 1),
        const SizedBox(height: 12),
        _buildGradeCard('ご褒美', 'reward', _rewardColor, thisMonth, last6MonthsAvg, 2),
      ],
    );
  }

  Widget _buildGradeCard(
    String label,
    String gradeKey,
    Color color,
    Map<String, Map<String, int>> thisMonth,
    Map<String, Map<String, int>> last6MonthsAvg,
    int index,
  ) {
    final data = thisMonth[gradeKey]!;
    final amount = data['amount']!;
    final count = data['count']!;
    final avg = data['avg']!;

    final last6Avg = last6MonthsAvg[gradeKey]!;
    final historicalAvg = last6Avg['avg']!;
    final historicalCount = last6Avg['count']!;

    // 過去平均との差分
    int? avgDiff;
    if (count > 0 && historicalCount > 0 && historicalAvg > 0) {
      avgDiff = avg - historicalAvg;
    }

    // スタガードアニメーション
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutQuart,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: context.cardElevationShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー行
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const Spacer(),
                if (count > 0)
                  Text(
                    '$count回',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.appTheme.textSecondary,
                    ),
                  ),
              ],
            ),
            if (count > 0) ...[
              const SizedBox(height: 12),
              // 金額と平均
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '合計',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TweenAnimationBuilder<int>(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutQuart,
                          tween: IntTween(begin: 0, end: amount),
                          builder: (context, val, child) {
                            return Text(
                              '¥${formatNumber(val)}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: context.appTheme.textPrimary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '平均単価',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        TweenAnimationBuilder<int>(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutQuart,
                          tween: IntTween(begin: 0, end: avg),
                          builder: (context, val, child) {
                            return Text(
                              '¥${formatNumber(val)}',
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: context.appTheme.textPrimary,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // 過去6ヶ月平均との比較（PLUS機能）
              if (avgDiff != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: avgDiff < 0
                        ? AppColors.accentGreenLight.withValues(alpha: 0.5)
                        : avgDiff > 0
                            ? AppColors.accentOrangeLight.withValues(alpha: 0.5)
                            : context.appTheme.bgPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '過去6サイクル平均より',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: context.appTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        avgDiff < 0
                            ? '¥${formatNumber(avgDiff.abs())} 安い'
                            : avgDiff > 0
                                ? '¥${formatNumber(avgDiff)} 高い'
                                : '同じ',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: avgDiff < 0
                              ? AppColors.accentGreen
                              : avgDiff > 0
                                  ? AppColors.accentOrange
                                  : context.appTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              Text(
                '今月のデータはありません',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.appTheme.textMuted.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 時系列グラフセクション
  Widget _buildMonthlyTrendSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月別推移',
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
          ),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: appState.getCategoryMonthlyTrend(widget.categoryId, months: 12),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: context.appTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Container(
                height: 200,
                decoration: BoxDecoration(
                  color: context.appTheme.bgCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    'データがありません',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: context.appTheme.textMuted,
                    ),
                  ),
                ),
              );
            }

            return _buildStackedBarChart(snapshot.data!);
          },
        ),
      ],
    );
  }

  /// 垂直積み上げ棒グラフ（横スクロール対応）
  Widget _buildStackedBarChart(List<Map<String, dynamic>> data) {
    // 最大値を計算（Y軸スケール用）
    final maxTotal = data.map((d) => d['total'] as int).reduce((a, b) => a > b ? a : b);
    final yAxisMax = maxTotal > 0 ? (maxTotal * 1.2).ceilToDouble() : 10000.0;

    // 棒の幅と間隔
    const barWidth = 28.0;
    const barSpacing = 16.0;
    final chartWidth = data.length * (barWidth + barSpacing) + 80; // 右側に余裕を持たせる

    // ビルド完了後に右端（最新月）にスクロール
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chartScrollController.hasClients) {
        _chartScrollController.jumpTo(_chartScrollController.position.maxScrollExtent);
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // 凡例
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildChartLegendItem('節約', _savingColor),
                const SizedBox(width: 16),
                _buildChartLegendItem('標準', _standardColor),
                const SizedBox(width: 16),
                _buildChartLegendItem('ご褒美', _rewardColor),
              ],
            ),
          ),
          // グラフ本体（横スクロール + 左固定Y軸）
          SizedBox(
            height: 220,
            child: Row(
              children: [
                // 固定Y軸ラベル
                _buildYAxisLabels(yAxisMax),
                // スクロール可能なグラフ部分
                Expanded(
                  child: SingleChildScrollView(
                    controller: _chartScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: SizedBox(
                      width: chartWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 24, bottom: 8),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: yAxisMax,
                            minY: 0,
                            barTouchData: BarTouchData(
                              enabled: true,
                              touchTooltipData: BarTouchTooltipData(
                                getTooltipColor: (_) => Colors.black87,
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                tooltipMargin: 8,
                                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                  final monthData = data[group.x.toInt()];
                                  return BarTooltipItem(
                                    '${monthData['monthLabel']}\n'
                                    '合計: ¥${formatNumber(monthData['total'] as int)}',
                                    GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  );
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              show: true,
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 28,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= data.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        data[index]['monthLabel'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: context.appTheme.textMuted,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: yAxisMax / 4,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: context.appTheme.bgPrimary,
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _buildBarGroups(data, yAxisMax, barWidth),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Y軸ラベル（固定）
  Widget _buildYAxisLabels(double maxY) {
    final intervals = [0.0, maxY * 0.25, maxY * 0.5, maxY * 0.75, maxY];
    return SizedBox(
      width: 50,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 36, top: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: intervals.reversed.map((value) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                _formatYAxisLabel(value.toInt()),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  color: context.appTheme.textMuted,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Y軸ラベルのフォーマット（1000→1k, 10000→1万）
  String _formatYAxisLabel(int value) {
    if (value >= 10000) {
      return '${(value / 10000).toStringAsFixed(value % 10000 == 0 ? 0 : 1)}万';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    }
    return value.toString();
  }

  /// 棒グラフのグループを生成
  List<BarChartGroupData> _buildBarGroups(
    List<Map<String, dynamic>> data,
    double maxY,
    double barWidth,
  ) {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final monthData = entry.value;

      final saving = (monthData['saving'] as int).toDouble();
      final standard = (monthData['standard'] as int).toDouble();
      final reward = (monthData['reward'] as int).toDouble();

      // 積み上げ順序: 下から 節約 → 標準 → ご褒美
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: saving + standard + reward,
            width: barWidth,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            rodStackItems: [
              // 節約（最下部）
              BarChartRodStackItem(0, saving, _savingColor),
              // 標準（中央）
              BarChartRodStackItem(saving, saving + standard, _standardColor),
              // ご褒美（最上部）
              BarChartRodStackItem(saving + standard, saving + standard + reward, _rewardColor),
            ],
          ),
        ],
      );
    }).toList();
  }

  /// グラフ凡例アイテム
  Widget _buildChartLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: context.appTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

/// カテゴリ詳細画面を表示（Fullscreen Dialog）
Future<void> showCategoryDetailScreen(
  BuildContext context,
  int categoryId,
  String categoryName,
  Color categoryColor,
) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return CategoryDetailScreen(
          categoryId: categoryId,
          categoryName: categoryName,
          categoryColor: categoryColor,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuart,
          reverseCurve: Curves.easeInQuart,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: child,
        );
      },
    ),
  );
}
