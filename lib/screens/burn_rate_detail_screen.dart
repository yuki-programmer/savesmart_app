import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../services/app_state.dart';
import '../utils/formatters.dart';
import '../widgets/analytics/cycle_indicator.dart';
import '../widgets/analytics/cycle_period_header.dart';
import '../widgets/burn_rate_chart.dart';

/// 支出ペースの詳細画面
/// 過去サイクルを含めて横スクロールで表示
class BurnRateDetailScreen extends StatefulWidget {
  const BurnRateDetailScreen({super.key});

  @override
  State<BurnRateDetailScreen> createState() => _BurnRateDetailScreenState();
}

class _BurnRateDetailScreenState extends State<BurnRateDetailScreen> {
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
          '支出ペース',
          style: AppTextStyles.screenTitle(context),
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
            accentColor: AppColors.accentBlue,
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
  bool _isLoading = true;
  late DateTime _cycleStart;
  late DateTime _cycleEnd;
  int _totalDays = 0;
  int _elapsedDays = 0;
  int _income = 0;
  int _fixedCosts = 0;
  int _disposable = 0;
  int _totalExpenses = 0;
  double _burnRate = 0;
  List<double> _dailyRates = [];
  int _startDay = 1;

  // 前サイクル比較用
  List<double>? _prevRates;
  int? _prevDays;
  int? _prevStartDay;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    debugPrint('[BurnRate] initState called for cycle ${widget.cycleOffset}');
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final appState = context.read<AppState>();

      // オフセットに応じたサイクル期間を取得
      final dates = appState.getCycleDatesForOffset(widget.cycleOffset);
      _cycleStart = dates.start;
      _cycleEnd = dates.end;
      _totalDays = _cycleEnd.difference(_cycleStart).inDays + 1;

      // 経過日数を計算
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      if (widget.cycleOffset == 0) {
        _elapsedDays = today.difference(_cycleStart).inDays + 1;
      } else {
        _elapsedDays = _totalDays;
      }

      // 収入を取得
      _income = await appState.getCycleIncomeTotal(widget.cycleOffset);
      _fixedCosts = appState.fixedCostsTotal;
      _disposable = _income - _fixedCosts;

      // 支出合計を取得
      _totalExpenses = await appState.getCycleTotalExpenses(widget.cycleOffset);

      // 消化率を計算
      if (_disposable > 0) {
        _burnRate = (_totalExpenses / _disposable) * 100;
      }

      // 日別支出を取得
      final dailyExpenses = await appState.getDailyExpensesForCycle(widget.cycleOffset);

      // 累積支出率を計算
      _dailyRates = List<double>.filled(_totalDays, 0.0);
      int cumulative = 0;
      bool recordStarted = false;

      for (var i = 0; i < _totalDays; i++) {
        cumulative += dailyExpenses[i] ?? 0;
        if (!recordStarted && (dailyExpenses[i] ?? 0) > 0) {
          _startDay = i + 1;
          recordStarted = true;
        }
        if (_disposable > 0) {
          _dailyRates[i] = (cumulative / _disposable) * 100;
        }
      }

      // 前サイクル比較データを取得（現サイクルのみ）
      if (widget.cycleOffset == 0) {
        final prevData = await appState.getPreviousCycleBurnRateData();
        if (prevData != null) {
          _prevRates = (prevData['rates'] as List<dynamic>).cast<double>();
          _prevDays = prevData['totalDays'] as int;
          _prevStartDay = prevData['startDay'] as int;
        }
      } else if (widget.cycleOffset < 5) {
        // 過去サイクルの場合、その前のサイクルデータを取得
        final prevOffset = widget.cycleOffset + 1;
        final prevDates = appState.getCycleDatesForOffset(prevOffset);
        final prevTotalDays = prevDates.end.difference(prevDates.start).inDays + 1;
        final prevIncome = await appState.getCycleIncomeTotal(prevOffset);
        final prevDisposable = prevIncome - _fixedCosts;

        if (prevDisposable > 0) {
          final prevDailyExpenses = await appState.getDailyExpensesForCycle(prevOffset);
          final rates = <double>[];
          int cumulativeAmt = 0;
          int startDay = 1;
          bool started = false;

          for (var i = 0; i < prevTotalDays; i++) {
            cumulativeAmt += prevDailyExpenses[i] ?? 0;
            if (!started && (prevDailyExpenses[i] ?? 0) > 0) {
              startDay = i + 1;
              started = true;
            }
            rates.add((cumulativeAmt / prevDisposable) * 100);
          }

          if (rates.isNotEmpty) {
            _prevRates = rates;
            _prevDays = prevTotalDays;
            _prevStartDay = startDay;
          }
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading burn rate data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin requires this

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_income == 0) {
      return _buildEmptyState('収入が設定されていません', Icons.account_balance_wallet_outlined);
    }

    if (_disposable <= 0) {
      return _buildEmptyState('可処分金額がありません', Icons.warning_amber_outlined);
    }

    final isOverBudget = _burnRate > 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // サイクル期間
          CyclePeriodHeader(
            cycleStart: _cycleStart,
            cycleEnd: _cycleEnd,
            badgeText: widget.cycleOffset == 0 ? '$_elapsedDays/$_totalDays日目' : '$_totalDays日間',
            badgeColor: AppColors.accentBlue,
          ),
          const SizedBox(height: 20),
          // 消化率サマリー
          _buildBurnRateSummary(isOverBudget),
          const SizedBox(height: 20),
          // グラフ
          _buildChartCard(),
          const SizedBox(height: 20),
          // 詳細情報
          _buildDetailInfo(),
        ],
      ),
    );
  }

  Widget _buildBurnRateSummary(bool isOverBudget) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          // 消化率
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '消化率',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.appTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${_burnRate.toStringAsFixed(1)}%',
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w600,
                  color: isOverBudget ? AppColors.accentRed : AppColors.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 支出 / 可処分
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isOverBudget
                  ? AppColors.accentRed.withValues(alpha: 0.08)
                  : AppColors.accentBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '¥${formatNumber(_totalExpenses)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isOverBudget ? AppColors.accentRed : context.appTheme.textPrimary,
                  ),
                ),
                Text(
                  ' / ',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.appTheme.textSecondary,
                  ),
                ),
                Text(
                  '¥${formatNumber(_disposable)}',
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: context.appTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '支出額の推移',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textSecondary,
                ),
              ),
              const Spacer(),
              // 凡例
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.cycleOffset == 0 ? '今サイクル' : 'このサイクル',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: context.appTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 12,
                    height: 2,
                    decoration: BoxDecoration(
                      color: context.appTheme.textMuted.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _prevRates != null ? '前サイクル' : '理想線',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: context.appTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          BurnRateChart(
            dailyRates: _dailyRates,
            todayDay: widget.cycleOffset == 0 ? _elapsedDays : _totalDays,
            daysInMonth: _totalDays,
            startDay: _startDay,
            cycleStartDate: _cycleStart,
            previousMonthRates: _prevRates,
            previousMonthDays: _prevDays,
            previousMonthStartDay: _prevStartDay,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.cardElevationShadow,
      ),
      child: Column(
        children: [
          _buildDetailRow('収入', _income),
          const Divider(height: 20),
          _buildDetailRow('固定費', _fixedCosts),
          const Divider(height: 20),
          _buildDetailRow('可処分金額', _disposable, highlight: true),
          const Divider(height: 20),
          _buildDetailRow('変動費支出', _totalExpenses),
          const Divider(height: 20),
          _buildDetailRow('残り', _disposable - _totalExpenses,
              highlight: true,
              isNegative: _disposable - _totalExpenses < 0),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, int amount, {bool highlight = false, bool isNegative = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            color: highlight ? context.appTheme.textPrimary : context.appTheme.textSecondary,
          ),
        ),
        Text(
          '¥${formatNumber(amount)}',
          style: GoogleFonts.ibmPlexSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isNegative
                ? AppColors.accentRed
                : (highlight ? AppColors.accentBlue : context.appTheme.textPrimary),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: context.appTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            message,
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
