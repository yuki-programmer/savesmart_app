import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';
import '../../config/typography.dart';
import '../../services/app_state.dart';
import '../../utils/formatters.dart';

/// 月間支出推移グラフ（グレード別積み上げ棒グラフ）
/// カテゴリ詳細の月別推移と同じ構成
class MonthlyExpenseTrendChart extends StatefulWidget {
  final AppState appState;

  const MonthlyExpenseTrendChart({
    super.key,
    required this.appState,
  });

  @override
  State<MonthlyExpenseTrendChart> createState() => _MonthlyExpenseTrendChartState();
}

class _MonthlyExpenseTrendChartState extends State<MonthlyExpenseTrendChart> {
  // グレードカラー定義
  static const _savingColor = Color(0xFF6B8E6B); // セージグリーン
  static const _standardColor = Color(0xFF6B7B8C); // ブルーグレー
  static const _rewardColor = Color(0xFFD4A853); // ゴールド

  // 月別グラフ用スクロールコントローラー
  final ScrollController _chartScrollController = ScrollController();

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '月間の支出推移',
          style: AppTextStyles.sectionTitle(context),
        ),
        const SizedBox(height: 4),
        Text(
          '支出タイプ別の推移が見えてきます',
          style: AppTextStyles.sub(context),
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: widget.appState.getMonthlyExpenseTrend(months: 12),
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

            // すべて0のデータかチェック
            final hasData = snapshot.data!.any((d) => (d['total'] as int) > 0);
            if (!hasData) {
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
