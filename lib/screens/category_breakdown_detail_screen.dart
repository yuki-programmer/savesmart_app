import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/theme.dart';
import '../config/category_icons.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/analytics/cycle_indicator.dart';
import '../widgets/analytics/cycle_period_header.dart';
import 'category_detail_screen.dart';

/// カテゴリ別支出割合の詳細画面
/// 過去サイクルを含めて横スクロールで表示
class CategoryBreakdownDetailScreen extends StatefulWidget {
  const CategoryBreakdownDetailScreen({super.key});

  @override
  State<CategoryBreakdownDetailScreen> createState() =>
      _CategoryBreakdownDetailScreenState();
}

class _CategoryBreakdownDetailScreenState
    extends State<CategoryBreakdownDetailScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // 表示するサイクル数（現在 + 過去5サイクル）
  static const int _cycleCount = 6;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      backgroundColor: context.appTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: context.appTheme.bgCard,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          color: context.appTheme.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'カテゴリ別の支出割合',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // サイクルインジケーター
          CycleIndicator(
            appState: appState,
            currentPage: _currentPage,
            cycleCount: _cycleCount,
            accentColor: AppColors.accentOrange,
            pageController: _pageController,
          ),
          // ページビュー
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _cycleCount,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                return _CyclePageContent(
                  cycleOffset: index,
                  categoryColors: AppColors.categoryColors,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

/// 各サイクルのページコンテンツ
class _CyclePageContent extends StatefulWidget {
  final int cycleOffset;
  final List<Color> categoryColors;

  const _CyclePageContent({
    required this.cycleOffset,
    required this.categoryColors,
  });

  @override
  State<_CyclePageContent> createState() => _CyclePageContentState();
}

class _CyclePageContentState extends State<_CyclePageContent>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>>? _categoryData;
  bool _isLoading = true;
  late DateTime _cycleStart;
  late DateTime _cycleEnd;
  int _touchedIndex = -1;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('[CategoryBreakdown] initState called for cycle ${widget.cycleOffset}');
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appState = context.read<AppState>();

      // オフセットに応じたサイクル期間を取得
      final dates = appState.getCycleDatesForOffset(widget.cycleOffset);
      _cycleStart = dates.start;
      _cycleEnd = dates.end;

      // カテゴリ統計を取得
      final stats = await appState.getCategoryStatsForCycle(widget.cycleOffset);

      // データを整形
      final items = <Map<String, dynamic>>[];
      var colorIndex = 0;
      for (final stat in stats) {
        final total = (stat['total_amount'] as int?) ?? 0;
        final categoryName = (stat['category'] as String?) ?? 'その他';
        if (total > 0) {
          items.add({
            'category': categoryName,
            'amount': total,
            'count': (stat['expense_count'] as int?) ?? 0,
            'color': widget.categoryColors[colorIndex % widget.categoryColors.length],
          });
          colorIndex++;
        }
      }

      // 金額順でソート
      items.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));

      if (mounted) {
        setState(() {
          _categoryData = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading category data: $e');
      if (mounted) {
        setState(() {
          _categoryData = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin requires this

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_categoryData == null || _categoryData!.isEmpty) {
      return _buildEmptyState();
    }

    final total = _categoryData!.fold(0, (sum, item) => sum + (item['amount'] as int));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // サイクル期間
          CyclePeriodHeader(
            cycleStart: _cycleStart,
            cycleEnd: _cycleEnd,
          ),
          const SizedBox(height: 20),
          // 円グラフ
          _buildPieChart(total),
          const SizedBox(height: 24),
          // カテゴリリスト
          _buildCategoryList(total),
        ],
      ),
    );
  }

  Widget _buildPieChart(int total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sections: _categoryData!.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final amount = item['amount'] as int;
                  final percentage = (amount / total) * 100;
                  final color = item['color'] as Color;
                  final isTouched = index == _touchedIndex;

                  return PieChartSectionData(
                    value: amount.toDouble(),
                    title: '${percentage.round()}%',
                    color: color,
                    radius: isTouched ? 65 : 55,
                    titleStyle: GoogleFonts.ibmPlexSans(
                      fontSize: isTouched ? 14 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  );
                }).toList(),
                sectionsSpace: 2,
                centerSpaceRadius: 45,
                pieTouchData: PieTouchData(
                  touchCallback: (event, response) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        _touchedIndex = -1;
                        return;
                      }
                      _touchedIndex = response.touchedSection!.touchedSectionIndex;
                    });

                    // 現サイクルのみタップで詳細へ
                    if (widget.cycleOffset == 0 &&
                        event is FlTapUpEvent &&
                        response != null &&
                        response.touchedSection != null) {
                      final index = response.touchedSection!.touchedSectionIndex;
                      if (index >= 0 && index < _categoryData!.length) {
                        _navigateToCategoryDetail(index);
                      }
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 合計
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.appTheme.bgPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '合計',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '¥${formatNumber(total)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'カテゴリ別内訳',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...(_categoryData!.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final amount = item['amount'] as int;
            final count = item['count'] as int;
            final percentage = ((amount / total) * 100).round();
            final color = item['color'] as Color;
            final category = item['category'] as String;

            return _buildCategoryItem(
              index: index,
              category: category,
              amount: amount,
              count: count,
              percentage: percentage,
              color: color,
            );
          })),
        ],
      ),
    );
  }

  Widget _buildCategoryItem({
    required int index,
    required String category,
    required int amount,
    required int count,
    required int percentage,
    required Color color,
  }) {
    final isCurrentCycle = widget.cycleOffset == 0;

    // カテゴリのアイコンを取得
    final appState = context.read<AppState>();
    final categoryObj = appState.categories.firstWhere(
      (c) => c.name == category,
      orElse: () => appState.categories.first,
    );
    final iconData = CategoryIcons.getIcon(categoryObj.icon);

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              iconData,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count件',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: context.appTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '¥${formatNumber(amount)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$percentage%',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (isCurrentCycle) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: context.appTheme.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ],
      ),
    );

    if (isCurrentCycle) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _navigateToCategoryDetail(index),
          child: content,
        ),
      );
    }

    return content;
  }

  void _navigateToCategoryDetail(int index) {
    final item = _categoryData![index];
    final categoryName = item['category'] as String;
    final color = item['color'] as Color;

    final appState = context.read<AppState>();
    final categoryObj = appState.categories.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => appState.categories.first,
    );

    if (categoryObj.id != null) {
      showCategoryDetailScreen(context, categoryObj.id!, categoryName, color);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.pie_chart_outline,
            size: 48,
            color: context.appTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'このサイクルには\n支出がありません',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.appTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
