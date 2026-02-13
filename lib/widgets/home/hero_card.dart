import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/home_constants.dart';
import '../../config/theme.dart';
import '../../utils/formatters.dart';
import '../../services/app_state.dart';
import '../night_reflection_dialog.dart';
import 'daily_allowance_sparkline.dart';

/// HeroCardの時間帯モード
enum HeroCardTimeMode {
  day,      // 4:00-5:59 & 10:00-18:59
  morning,  // 6:00-9:59（暖色グラデーション）
  night,    // 19:00-3:59（夜テーマ）
}

/// HeroCardの状態
class _HeroCardState {
  final HeroCardTimeMode displayMode;
  final bool useNightDecoration;
  final bool canOpenReflection;  // 夜 && 未開封

  _HeroCardState({
    required this.displayMode,
    required this.useNightDecoration,
    required this.canOpenReflection,
  });

  factory _HeroCardState.fromDateTime(
    DateTime now,
    bool hasTodayExpense,
    bool hasOpenedReflection, {
    required bool isDarkMode,
  }) {
    final hour = now.hour;
    final HeroCardTimeMode displayMode;
    final bool useNightDecoration;

    if (isDarkMode) {
      displayMode = HeroCardTimeMode.day;
      useNightDecoration = true;
    } else if (hour >= 6 && hour < 10) {
      displayMode = HeroCardTimeMode.morning;
      useNightDecoration = false;
    } else if (hour >= 19 || hour < 4) {
      displayMode = HeroCardTimeMode.night;
      useNightDecoration = true;
    } else {
      displayMode = HeroCardTimeMode.day;
      useNightDecoration = false;
    }

    // 振り返り起動可否（夜テーマ && 既存ロジック && 未開封）
    final canOpenReflection = displayMode == HeroCardTimeMode.night &&
        NightReflectionDialog.shouldShowNightCard(hasTodayExpense: hasTodayExpense) &&
        !hasOpenedReflection;

    return _HeroCardState(
      displayMode: displayMode,
      useNightDecoration: useNightDecoration,
      canOpenReflection: canOpenReflection,
    );
  }
}

/// ホーム画面のヒーローカード（今日使えるお金）
class HeroCard extends StatefulWidget {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final int remainingDays;
  final bool hasOpenedReflection;
  final VoidCallback? onTapReflection;
  final String currencyFormat;

  const HeroCard({
    super.key,
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.remainingDays,
    required this.hasOpenedReflection,
    this.onTapReflection,
    this.currencyFormat = 'prefix',
  });

  @override
  State<HeroCard> createState() => _HeroCardWidgetState();
}

class _HeroCardWidgetState extends State<HeroCard> {
  static const int _historyDaysForSparkline = 7;
  List<Map<String, dynamic>> _historyData = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshHistoryIfNeeded();
  }

  void _refreshHistoryIfNeeded() {
    if (_isLoadingHistory) return;
    if (_historyData.length >= _historyDaysForSparkline) return;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final appState = context.read<AppState>();
    // Fetch 7 days: 6 for display + 1 for oldest point comparison
    final history = await appState.getDailyAllowanceHistory(_historyDaysForSparkline);
    if (mounted) {
      setState(() {
        _historyData = history;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final state = _HeroCardState.fromDateTime(
      now,
      widget.todayTotal > 0,
      widget.hasOpenedReflection,
      isDarkMode: Theme.of(context).brightness == Brightness.dark,
    );

    final canTapReflection =
        state.canOpenReflection && Theme.of(context).brightness != Brightness.dark;

    return GestureDetector(
      onTap: canTapReflection ? widget.onTapReflection : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(HomeConstants.heroCardPadding),
        decoration: _buildDecoration(
          context,
          state.useNightDecoration ? HeroCardTimeMode.night : state.displayMode,
        ),
        child: _buildContent(context, state),
      ),
    );
  }

  BoxDecoration _buildDecoration(BuildContext context, HeroCardTimeMode mode) {
    switch (mode) {
      case HeroCardTimeMode.night:
        return BoxDecoration(
          color: HomeConstants.nightCardBackground,
          borderRadius: BorderRadius.circular(HomeConstants.heroCardRadius),
          boxShadow: context.cardElevationShadow,
        );

      case HeroCardTimeMode.morning:
        return BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: HomeConstants.morningGradient,
          ),
          borderRadius: BorderRadius.circular(HomeConstants.heroCardRadius),
          boxShadow: context.cardElevationShadow,
        );

      case HeroCardTimeMode.day:
        return BoxDecoration(
          color: HomeConstants.cardBackground,
          borderRadius: BorderRadius.circular(HomeConstants.heroCardRadius),
          boxShadow: context.cardElevationShadow,
        );
    }
  }

  Widget _buildContent(BuildContext context, _HeroCardState state) {
    switch (state.displayMode) {
      case HeroCardTimeMode.night:
        return _NightContent(
          fixedTodayAllowance: widget.fixedTodayAllowance,
          dynamicTomorrowForecast: widget.dynamicTomorrowForecast,
          todayTotal: widget.todayTotal,
          remainingDays: widget.remainingDays,
          canOpenReflection: state.canOpenReflection,
          currencyFormat: widget.currencyFormat,
          historyData: _historyData,
          isLoadingHistory: _isLoadingHistory,
        );

      case HeroCardTimeMode.morning:
      case HeroCardTimeMode.day:
        return _DayContent(
          fixedTodayAllowance: widget.fixedTodayAllowance,
          dynamicTomorrowForecast: widget.dynamicTomorrowForecast,
          todayTotal: widget.todayTotal,
          remainingDays: widget.remainingDays,
          isMorningGlow: state.displayMode == HeroCardTimeMode.morning,
          useNightStyle: state.useNightDecoration,
          currencyFormat: widget.currencyFormat,
          historyData: _historyData,
          isLoadingHistory: _isLoadingHistory,
        );
    }
  }
}

/// 日中Content（Day/Morning共通）
class _DayContent extends StatelessWidget {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final int remainingDays;
  final bool isMorningGlow;
  final bool useNightStyle;
  final String currencyFormat;
  final List<Map<String, dynamic>> historyData;
  final bool isLoadingHistory;

  const _DayContent({
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.remainingDays,
    required this.isMorningGlow,
    required this.useNightStyle,
    required this.currencyFormat,
    required this.historyData,
    required this.isLoadingHistory,
  });

  void _showTodaySpendSheet(BuildContext context) {
    final appState = context.read<AppState>();
    final expenses = appState.todayExpenses;
    final Map<String, int> categoryTotals = {};
    for (final expense in expenses) {
      if (expense.category.isEmpty) continue;
      categoryTotals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final topCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TodaySpendSheetContent(
        currencyFormat: currencyFormat,
        todayTotal: todayTotal,
        todayLimit: fixedTodayAllowance ?? 0,
        topCategories: topCategories.take(3).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIncreasing = (dynamicTomorrowForecast ?? 0) > (fixedTodayAllowance ?? 0);
    final labelColor =
        useNightStyle ? HomeConstants.nightPrimaryText.withValues(alpha: 0.8) : Colors.grey[600]!;
    final helpIconColor =
        useNightStyle ? HomeConstants.nightPrimaryText.withValues(alpha: 0.6) : Colors.grey[400]!;
    final amountColor =
        useNightStyle ? HomeConstants.nightPrimaryText : HomeConstants.primaryText;
    final subTextColor =
        useNightStyle ? HomeConstants.nightPrimaryText.withValues(alpha: 0.7) : Colors.grey[600]!;
    final badgeBgColor = useNightStyle
        ? HomeConstants.nightPrimaryText.withValues(alpha: 0.15)
        : AppColors.accentBlue.withValues(alpha: 0.1);
    final badgeTextColor = useNightStyle
        ? HomeConstants.nightPrimaryText.withValues(alpha: 0.85)
        : AppColors.accentBlue.withValues(alpha: 0.8);
    final lineColor = useNightStyle
        ? HomeConstants.nightPrimaryText.withValues(alpha: 0.45)
        : AppColors.accentBlue.withValues(alpha: 0.6);

    return Column(
      children: [
        // ラベル + ヘルプアイコン + 残り日数
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '今日使えるお金',
              style: TextStyle(
                fontSize: HomeConstants.heroLabelSize,
                color: labelColor,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _showHelpDialog(context),
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: helpIconColor,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: badgeBgColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'あと$remainingDays日',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 金額（主役）
        Text(
          formatCurrency(fixedTodayAllowance ?? 0, currencyFormat),
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: HomeConstants.heroAmountSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: amountColor,
          ),
        ),
        const SizedBox(height: 8),

        // 今日使った金額
        GestureDetector(
          onTap: () => _showTodaySpendSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '今日使った金額 ',
                style: TextStyle(
                  fontSize: HomeConstants.heroSubtextSize,
                  color: subTextColor,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
                  return FadeTransition(
                    opacity: fade,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(fade),
                      child: child,
                    ),
                  );
                },
                child: Text(
                  todayTotal > 0 ? formatCurrency(todayTotal, currencyFormat) : 'まだありません',
                  key: ValueKey<int>(todayTotal > 0 ? todayTotal : -1),
                  style: TextStyle(
                    fontFamily: todayTotal > 0 ? 'IBMPlexSans' : null,
                    fontSize: HomeConstants.heroSubtextSize,
                    fontWeight: todayTotal > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: subTextColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 16,
                color: subTextColor.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Sparkline（過去6日間のトレンド）
        if (!isLoadingHistory && historyData.length >= 2) ...[
          // タイトル + ヘルプ
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '過去６日間のリズム',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _showRhythmHelpDialog(context),
                child: Icon(
                  Icons.help_outline,
                  size: 14,
                  color: helpIconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: DailyAllowanceSparkline(
              historyData: historyData,
              lineColor: lineColor,
              height: 32,
              currencyFormat: currencyFormat,
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 明日の予測
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'このままなら明日は ',
              style: TextStyle(
                fontSize: HomeConstants.heroSubtextSize,
                color: subTextColor,
              ),
            ),
            Text(
              formatCurrency(dynamicTomorrowForecast ?? 0, currencyFormat),
              style: TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isIncreasing ? AppColors.accentGreen : AppColors.accentRed,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              isIncreasing ? Icons.arrow_upward : Icons.arrow_downward,
              size: 14,
              color: isIncreasing ? AppColors.accentGreen : AppColors.accentRed,
            ),
          ],
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '今日使えるお金とは？',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '残り使えるお金を残りの日数で割った金額です。\n\n毎朝計算され、1日の中では変わりません。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('わかった'),
          ),
        ],
      ),
    );
  }

  void _showRhythmHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '過去６日間のリズム',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '前日より「今日使えるお金」が増えた日を「控えめ」、減った日を「使った」と表示します。\n\n点をタップすると詳細が見られます。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('わかった'),
          ),
        ],
      ),
    );
  }
}

class _TodaySpendSheetContent extends StatelessWidget {
  final String currencyFormat;
  final int todayTotal;
  final int todayLimit;
  final List<MapEntry<String, int>> topCategories;

  const _TodaySpendSheetContent({
    required this.currencyFormat,
    required this.todayTotal,
    required this.todayLimit,
    required this.topCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                  color: context.appTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                '今日の支出',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              if (topCategories.isEmpty) ...[
                Text(
                  '今日の支出はまだありません',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appTheme.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ] else ...[
                ...topCategories.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.appTheme.bgPrimary.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              entry.key,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: context.appTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.center,
                            child: Text(
                              formatCurrency(entry.value, currencyFormat),
                              style: TextStyle(
                                fontFamily: 'IBMPlexSans',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              const SizedBox(height: 16),
              Container(
                height: 1,
                color: context.appTheme.borderSubtle.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: _buildMetric(
                        context,
                        label: '今日使った金額',
                        amount: todayTotal,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.center,
                      child: _buildMetric(
                        context,
                        label: '今日使えるお金',
                        amount: todayLimit,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetric(
    BuildContext context, {
    required String label,
    required int amount,
    required Color color,
    bool alignCenter = false,
  }) {
    final content = Column(
      crossAxisAlignment: alignCenter ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: context.appTheme.textMuted.withValues(alpha: 0.9),
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatCurrency(amount, currencyFormat),
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );

    if (!alignCenter) return content;
    return Center(child: content);
  }
}

/// 夜Content（修正版：答えを残す）
class _NightContent extends StatelessWidget {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final int remainingDays;
  final bool canOpenReflection;
  final String currencyFormat;
  final List<Map<String, dynamic>> historyData;
  final bool isLoadingHistory;

  const _NightContent({
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.remainingDays,
    required this.canOpenReflection,
    required this.currencyFormat,
    required this.historyData,
    required this.isLoadingHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 🌙 コンテキスト表示
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(
              '今日のふりかえり',
              style: TextStyle(
                fontSize: 14,
                color: HomeConstants.nightPrimaryText.withValues(alpha: 0.9),
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 主役：今日使えるお金（夜でも表示）
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '今日使えるお金',
                  style: TextStyle(
                    fontSize: 12,
                    color: HomeConstants.nightPrimaryText.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => _showHelpDialog(context),
                  child: Icon(
                    Icons.help_outline,
                    size: 14,
                    color: HomeConstants.nightPrimaryText.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: HomeConstants.nightPrimaryText.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'あと$remainingDays日',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: HomeConstants.nightPrimaryText.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatCurrency(fixedTodayAllowance ?? 0, currencyFormat),
              style: const TextStyle(
                fontFamily: 'IBMPlexSans',
                fontSize: HomeConstants.heroAmountSizeNight,
                fontWeight: FontWeight.w600,
                color: HomeConstants.nightPrimaryText,
                height: 1.1,
              ),
            ),
            // Sparkline（過去6日間のトレンド）
            if (!isLoadingHistory && historyData.length >= 2) ...[
              const SizedBox(height: 12),
              // タイトル + ヘルプ
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '過去６日間のリズム',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: HomeConstants.nightPrimaryText.withValues(alpha: 0.6),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showRhythmHelpDialog(context),
                    child: Icon(
                      Icons.help_outline,
                      size: 12,
                      color: HomeConstants.nightPrimaryText.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: DailyAllowanceSparkline(
                  historyData: historyData,
                  lineColor: HomeConstants.nightPrimaryText.withValues(alpha: 0.4),
                  height: 28,
                  currencyFormat: currencyFormat,
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 20),

        // 区切り線
        Container(
          width: 120,
          height: 1,
          color: HomeConstants.nightPrimaryText.withValues(alpha: 0.2),
        ),

        const SizedBox(height: 16),

        // 補足：今日/明日（振り返り導線）
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMetric('今日', todayTotal, HomeConstants.nightPrimaryText.withValues(alpha: 0.75)),
            const SizedBox(width: 32),
            _buildMetric('明日', dynamicTomorrowForecast ?? 0, HomeConstants.nightPrimaryText),
          ],
        ),

        // CTA（振り返り可能時のみ）
        if (canOpenReflection) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.touch_app_outlined,
                size: 14,
                color: HomeConstants.nightPrimaryText.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                'タップして振り返る',
                style: TextStyle(
                  fontSize: 12,
                  color: HomeConstants.nightPrimaryText.withValues(alpha: 0.6),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildMetric(String label, int amount, Color textColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: textColor.withValues(alpha: textColor.a * 0.7),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatCurrency(amount, currencyFormat),
          style: TextStyle(
            fontFamily: 'IBMPlexSans',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '今日使えるお金とは？',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '残り使えるお金を残りの日数で割った金額です。\n\n毎朝計算され、1日の中では変わりません。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('わかった'),
          ),
        ],
      ),
    );
  }

  void _showRhythmHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '過去６日間のリズム',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          '前日より「今日使えるお金」が増えた日を「控えめ」、減った日を「使った」と表示します。\n\n点をタップすると詳細が見られます。',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('わかった'),
          ),
        ],
      ),
    );
  }
}
