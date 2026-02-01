import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/category_icons.dart';
import '../../services/app_state.dart';
import '../../screens/category_breakdown_detail_screen.dart';
import '../../screens/premium_screen.dart';
import 'analytics_card_header.dart';

/// カテゴリ別支出割合カード（常時表示版）
/// Premium: 実データ円グラフ + 矢印（詳細画面へ）
/// Free: ダミー円グラフ + ループアニメ + ロックアイコン（Premium画面へ）
class CategoryBreakdownCard extends StatefulWidget {
  final AppState appState;
  final bool isPremium;

  const CategoryBreakdownCard({
    super.key,
    required this.appState,
    required this.isPremium,
  });

  @override
  State<CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<CategoryBreakdownCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  // ダミーデータ（Free用）
  static const List<Map<String, dynamic>> _dummyData = [
    {'category': '食費', 'amount': 35, 'color': Color(0xFF2196F3)},
    {'category': '交通費', 'amount': 20, 'color': Color(0xFF4CAF50)},
    {'category': '娯楽', 'amount': 25, 'color': Color(0xFFFFC107)},
    {'category': 'その他', 'amount': 20, 'color': Color(0xFF607D8B)},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    if (!widget.isPremium) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CategoryBreakdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPremium != oldWidget.isPremium) {
      if (widget.isPremium) {
        _animationController.stop();
        _animationController.reset();
      } else {
        _animationController.repeat(reverse: true);
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
        decoration: analyticsCardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalyticsCardHeader(
              icon: Icons.pie_chart_outline,
              iconColor: AppColors.accentOrange,
              title: 'カテゴリ別の支出割合',
              subtitle: widget.isPremium
                  ? _getSummaryText()
                  : 'どこにお金を使っているかわかります',
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
    final categoryStats = widget.appState.categoryStats;
    if (categoryStats.isEmpty) return '-';

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

  Widget _buildPremiumContent() {
    final categoryStats = widget.appState.categoryStats;

    if (categoryStats.isEmpty) {
      return _buildEmptyState();
    }

    // データ準備
    final items = <Map<String, dynamic>>[];
    var colorIndex = 0;
    for (final entry in categoryStats.entries) {
      items.add({
        'category': entry.key,
        'amount': entry.value.totalAmount,
        'color': AppColors.categoryColors[colorIndex % AppColors.categoryColors.length],
      });
      colorIndex++;
    }
    items.sort((a, b) => (b['amount'] as int).compareTo(a['amount'] as int));
    final total = items.fold(0, (sum, item) => sum + (item['amount'] as int));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 20),
        // 円グラフ
        SizedBox(
          width: 110,
          height: 110,
          child: PieChart(
            PieChartData(
              sections: items.take(6).map((item) {
                final percentage = (item['amount'] as int) / total;
                return PieChartSectionData(
                  value: percentage * 100,
                  color: item['color'] as Color,
                  radius: 44,
                  showTitle: false,
                );
              }).toList(),
              sectionsSpace: 1,
              centerSpaceRadius: 22,
            ),
          ),
        ),
        const SizedBox(width: 50),
        // 上位カテゴリ
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.take(3).map((item) {
                final percentage = ((item['amount'] as int) / total * 100).round();
                final categoryName = item['category'] as String;
                final displayName = categoryName.length > 10
                    ? '${categoryName.substring(0, 10)}...'
                    : categoryName;
                final color = item['color'] as Color;

              // カテゴリのアイコンを取得
              final categoryObj = widget.appState.categories.firstWhere(
                (c) => c.name == categoryName,
                orElse: () => widget.appState.categories.first,
              );
              final iconData = CategoryIcons.getIcon(categoryObj.icon);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          iconData,
                          size: 12,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          '$percentage%',
                          textAlign: TextAlign.right,
                          style: GoogleFonts.ibmPlexSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFreeContent() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // アニメーションでセクションサイズを微妙に変化
        final animValue = _animation.value;
        final items = _dummyData.map((item) {
          final baseAmount = item['amount'] as int;
          final variance = (animValue - 0.5) * 10;
          return {
            ...item,
            'animatedAmount': baseAmount + variance,
          };
        }).toList();

        final total = items.fold(0.0, (sum, item) => sum + (item['animatedAmount'] as double));

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 20),
            // ダミー円グラフ
            SizedBox(
              width: 110,
              height: 110,
              child: PieChart(
                PieChartData(
                  sections: items.map((item) {
                    final percentage = (item['animatedAmount'] as double) / total;
                    return PieChartSectionData(
                      value: percentage * 100,
                      color: (item['color'] as Color).withValues(alpha: 0.5),
                      radius: 44,
                      showTitle: false,
                    );
                  }).toList(),
                  sectionsSpace: 1,
                  centerSpaceRadius: 22,
                ),
              ),
            ),
            const SizedBox(width: 50),
            // ダミーカテゴリ
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _dummyData.take(3).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppColors.textMuted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 48,
                            child: Text(
                              '--%',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '記録するとここに表示されます',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  void _handleTap() {
    if (widget.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CategoryBreakdownDetailScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PremiumScreen()),
      );
    }
  }
}
