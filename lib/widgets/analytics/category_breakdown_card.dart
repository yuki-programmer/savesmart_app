import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/typography.dart';
import '../../config/category_icons.dart';
import '../../services/app_state.dart';
import '../../screens/category_breakdown_detail_screen.dart';
import 'analytics_card_header.dart';

/// カテゴリ別支出割合カード（常時表示版）
/// Free/Premium 共通: 実データ円グラフ + 矢印（詳細画面へ）
class CategoryBreakdownCard extends StatelessWidget {
  final AppState appState;

  const CategoryBreakdownCard({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        decoration: analyticsCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnalyticsCardHeader(
              icon: Icons.pie_chart_outline,
              iconColor: AppColors.accentOrange,
              title: 'カテゴリ別の支出割合',
              subtitle: _getSummaryText(),
              isPremium: true,
            ),
            const AnalyticsCardDivider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildPremiumContent(context),
            ),
          ],
        ),
      ),
    );
  }

  String _getSummaryText() {
    final categoryStats = appState.categoryStats;
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

  Widget _buildPremiumContent(BuildContext context) {
    final categoryStats = appState.categoryStats;

    if (categoryStats.isEmpty) {
      return _buildEmptyState(context);
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
                final iconData = appState.categories.isEmpty
                    ? Icons.category_outlined
                    : CategoryIcons.getIcon(
                        appState.categories
                            .firstWhere(
                              (c) => c.name == categoryName,
                              orElse: () => appState.categories.first,
                            )
                            .icon,
                      );

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
                            color: context.appTheme.textPrimary.withValues(alpha: 0.85),
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
                            color: context.appTheme.textSecondary.withValues(alpha: 0.8),
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '記録するとここに表示されます',
          style: AppTextStyles.sub(context),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryBreakdownDetailScreen()),
    );
  }
}
