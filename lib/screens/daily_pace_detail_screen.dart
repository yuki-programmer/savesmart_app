import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/analytics/cycle_indicator.dart';
import '../widgets/analytics/cycle_period_header.dart';

/// 1日あたりの支出の詳細画面
/// 過去サイクルを含めて横スクロールで表示
class DailyPaceDetailScreen extends StatefulWidget {
  const DailyPaceDetailScreen({super.key});

  @override
  State<DailyPaceDetailScreen> createState() => _DailyPaceDetailScreenState();
}

class _DailyPaceDetailScreenState extends State<DailyPaceDetailScreen> {
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
          '1日あたりの支出',
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
            accentColor: AppColors.accentGreen,
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
                return _CyclePageContent(cycleOffset: index);
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

  const _CyclePageContent({required this.cycleOffset});

  @override
  State<_CyclePageContent> createState() => _CyclePageContentState();
}

class _CyclePageContentState extends State<_CyclePageContent>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>>? _paceData;
  bool _isLoading = true;
  late DateTime _cycleStart;
  late DateTime _cycleEnd;
  int _elapsedDays = 0;
  int _totalExpenses = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('[DailyPace] initState called for cycle ${widget.cycleOffset}');
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appState = context.read<AppState>();

      // オフセットに応じたサイクル期間を取得
      final dates = appState.getCycleDatesForOffset(widget.cycleOffset);
      _cycleStart = dates.start;
      _cycleEnd = dates.end;

      // 経過日数を計算
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (widget.cycleOffset == 0) {
        // 現在のサイクル: 今日までの経過日数
        _elapsedDays = today.difference(_cycleStart).inDays + 1;
      } else {
        // 過去サイクル: サイクル全日数
        _elapsedDays = _cycleEnd.difference(_cycleStart).inDays + 1;
      }

      // カテゴリ統計を取得
      final stats = await appState.getCategoryStatsForCycle(widget.cycleOffset);

      // データを整形
      final items = <Map<String, dynamic>>[];
      int total = 0;

      for (final stat in stats) {
        final amount = (stat['total_amount'] as int?) ?? 0;
        if (amount > 0) {
          final dailyPace = _elapsedDays > 0 ? amount / _elapsedDays : 0.0;
          final weeklyPace = dailyPace * 7;

          final categoryName = (stat['category'] as String?) ?? 'その他';
          items.add({
            'category': categoryName,
            'total': amount,
            'dailyPace': _roundToHundred(dailyPace),
            'weeklyPace': _roundToHundred(weeklyPace),
          });
          total += amount;
        }
      }

      // 金額順でソート
      items.sort((a, b) => (b['total'] as int).compareTo(a['total'] as int));

      if (mounted) {
        setState(() {
          _paceData = items;
          _totalExpenses = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading pace data: $e');
      if (mounted) {
        setState(() {
          _paceData = [];
          _totalExpenses = 0;
          _isLoading = false;
        });
      }
    }
  }

  int _roundToHundred(double value) {
    return ((value / 100).round() * 100);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin requires this

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paceData == null || _paceData!.isEmpty) {
      return _buildEmptyState();
    }

    final totalDailyPace = _elapsedDays > 0 ? _totalExpenses / _elapsedDays : 0.0;
    final totalWeeklyPace = totalDailyPace * 7;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // サイクル期間と経過日数
          CyclePeriodHeader(
            cycleStart: _cycleStart,
            cycleEnd: _cycleEnd,
            badgeText: '$_elapsedDays日間',
            badgeColor: AppColors.accentGreen,
          ),
          const SizedBox(height: 20),
          // 全体ペース
          _buildTotalPace(totalDailyPace, totalWeeklyPace),
          const SizedBox(height: 16),
          // カテゴリ別ペース
          _buildCategoryPaceList(),
        ],
      ),
    );
  }

  Widget _buildTotalPace(double dailyPace, double weeklyPace) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          Text(
            '全体',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // 1日あたり
              Expanded(
                child: _buildPaceBox(
                  label: '1日あたり',
                  value: _roundToHundred(dailyPace),
                  color: AppColors.accentGreen,
                  isLarge: true,
                ),
              ),
              const SizedBox(width: 12),
              // 1週間あたり
              Expanded(
                child: _buildPaceBox(
                  label: '1週間あたり',
                  value: _roundToHundred(weeklyPace),
                  color: AppColors.accentBlue,
                  isLarge: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 合計
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: context.appTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '¥${formatNumber(_totalExpenses)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 15,
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

  Widget _buildPaceBox({
    required String label,
    required int value,
    required Color color,
    bool isLarge = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isLarge ? 16 : 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: isLarge ? 12 : 11,
              fontWeight: FontWeight.w500,
              color: context.appTheme.textSecondary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '約',
                style: GoogleFonts.inter(
                  fontSize: isLarge ? 13 : 11,
                  fontWeight: FontWeight.w400,
                  color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                '¥${formatNumber(value)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: isLarge ? 22 : 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPaceList() {
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
            'カテゴリ別',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.appTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...(_paceData!.map((item) => _buildCategoryPaceItem(item))),
        ],
      ),
    );
  }

  Widget _buildCategoryPaceItem(Map<String, dynamic> item) {
    final category = item['category'] as String;
    final total = item['total'] as int;
    final dailyPace = item['dailyPace'] as int;
    final weeklyPace = item['weeklyPace'] as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.appTheme.bgPrimary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // カテゴリ名と合計
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                '¥${formatNumber(total)}',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ペース
          Row(
            children: [
              // 日ペース
              Expanded(
                child: Row(
                  children: [
                    Text(
                      '約',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '¥${formatNumber(dailyPace)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentGreen,
                      ),
                    ),
                    Text(
                      '/日',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              // 週ペース
              Row(
                children: [
                  Text(
                    '約',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '¥${formatNumber(weeklyPace)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.accentBlue.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    '/週',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textMuted.withValues(alpha: 0.6),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.speed,
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
