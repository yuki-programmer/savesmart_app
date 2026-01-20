import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../config/home_constants.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import '../models/fixed_cost.dart';
import '../models/quick_entry.dart';
import '../utils/formatters.dart';
import '../widgets/quick_entry/quick_entry_edit_modal.dart';
import '../widgets/night_reflection_dialog.dart';
import '../widgets/home/hero_card.dart';
import '../widgets/home/weekly_budget_card.dart';
import 'premium_screen.dart';
import 'quick_entry_manage_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'fixed_cost_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _fixedCostsExpanded = false;
  bool _hasOpenedReflectionToday = false;

  @override
  void initState() {
    super.initState();
    _checkReflectionStatus();
  }

  Future<void> _checkReflectionStatus() async {
    final opened = await _getReflectionStatus(DateTime.now());
    if (mounted) {
      setState(() {
        _hasOpenedReflectionToday = opened;
      });
    }
  }

  Future<bool> _getReflectionStatus(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'reflection_opened_${_formatDate(date)}';
    return prefs.getBool(key) ?? false;
  }

  Future<void> _markReflectionAsOpened(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'reflection_opened_${_formatDate(date)}';
    await prefs.setBool(key, true);
  }

  String _formatDate(DateTime date) {
    return '${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}';
  }

  /// 夜の振り返りダイアログを表示
  Future<void> _showNightReflectionDialog(AppState appState) async {
    await NightReflectionDialog.show(
      context,
      todayTotal: appState.todayTotal,
      tomorrowBudget: appState.dynamicTomorrowForecast,
    );

    // 開封マーク
    await _markReflectionAsOpened(DateTime.now());
    if (mounted) {
      setState(() {
        _hasOpenedReflectionToday = true;
      });
    }
  }


  // 日付ベースのランダムステータス文言
  String _getDailyStatusText() {
    final statusMessages = [
      '今月は標準ペースです',
      '今月は落ち着いた使い方',
      '最近は安定しています',
    ];

    // YYYY-MM-DD形式で日付をハッシュ化して同じ日は同じ文言を表示
    final now = DateTime.now();
    final dateString = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final hash = dateString.hashCode.abs();
    final index = hash % statusMessages.length;

    return statusMessages[index];
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}曜日';
  }

  @override
  Widget build(BuildContext context) {
    // isLoading のみを監視するSelector
    return Selector<AppState, bool>(
      selector: (_, appState) => appState.isLoading,
      builder: (context, isLoading, child) {
        return Scaffold(
          backgroundColor: HomeConstants.screenBackground,
          body: SafeArea(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 20),
                        // ヒーローカード（今日使えるお金）- Selector化
                        _buildHeroCardSection(),
                        const SizedBox(height: 12),
                        // 週間バジェットカード（Premium機能）
                        _buildWeeklyBudgetSection(),
                        const SizedBox(height: 16),
                        // 今月サマリーカード - Selector化
                        _buildMonthlySummarySection(),
                        const SizedBox(height: 16),
                        // クイック登録セクション - Selector化
                        _buildQuickEntrySectionWithSelector(),
                        const SizedBox(height: 16),
                        // 日々の出費 - Selector化
                        _buildRecentExpensesSection(),
                        const SizedBox(height: 28),
                        // 固定費 - Selector化
                        _buildFixedCostsSectionWithSelector(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }

  /// ヒーローカードセクション（Selector使用）
  Widget _buildHeroCardSection() {
    return Selector<AppState, _HeroCardData>(
      selector: (_, appState) => _HeroCardData(
        fixedTodayAllowance: appState.fixedTodayAllowance,
        dynamicTomorrowForecast: appState.dynamicTomorrowForecast,
        todayTotal: appState.todayTotal,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        final appState = context.read<AppState>();
        return HeroCard(
          fixedTodayAllowance: data.fixedTodayAllowance,
          dynamicTomorrowForecast: data.dynamicTomorrowForecast,
          todayTotal: data.todayTotal,
          hasOpenedReflection: _hasOpenedReflectionToday,
          onTapReflection: () => _showNightReflectionDialog(appState),
          currencyFormat: data.currencyFormat,
        );
      },
    );
  }

  /// 週間バジェットセクション（Premium機能）
  Widget _buildWeeklyBudgetSection() {
    return Selector<AppState, _WeeklyBudgetData>(
      selector: (_, appState) {
        final info = appState.weeklyBudgetInfo;
        return _WeeklyBudgetData(
          amount: info['amount'] as int?,
          daysRemaining: info['daysRemaining'] as int,
          endDate: info['endDate'] as DateTime,
          isWeekMode: info['isWeekMode'] as bool,
          isOverBudget: info['isOverBudget'] as bool,
          isPremium: appState.isPremium,
          currencyFormat: appState.currencyFormat,
        );
      },
      builder: (context, data, child) {
        return WeeklyBudgetCard(
          amount: data.amount,
          daysRemaining: data.daysRemaining,
          endDate: data.endDate,
          isWeekMode: data.isWeekMode,
          isOverBudget: data.isOverBudget,
          isPremium: data.isPremium,
          currencyFormat: data.currencyFormat,
          onTapLocked: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumScreen()),
            );
          },
        );
      },
    );
  }

  /// 今月サマリーセクション（Selector使用）
  Widget _buildMonthlySummarySection() {
    return Selector<AppState, _MonthlySummaryData>(
      selector: (_, appState) => _MonthlySummaryData(
        usableAmount: appState.thisMonthAvailableAmount,
        fixedCostsTotal: appState.fixedCostsTotal,
        thisMonthTotal: appState.thisMonthTotal,
        remainingDays: appState.remainingDaysInMonth,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        return _buildMonthlySummaryCard(data);
      },
    );
  }

  /// クイック登録セクション（Selector使用）
  Widget _buildQuickEntrySectionWithSelector() {
    return Selector<AppState, _QuickEntryData>(
      selector: (_, appState) => _QuickEntryData(
        quickEntries: appState.quickEntries,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        return _buildQuickEntrySection(data);
      },
    );
  }

  /// 日々の出費セクション（Selector使用）
  Widget _buildRecentExpensesSection() {
    return Selector<AppState, _RecentExpensesData>(
      selector: (_, appState) => _RecentExpensesData(
        recentExpenses: appState.thisMonthExpenses.take(3).toList(),
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        return _buildRecentExpenses(data);
      },
    );
  }

  /// 固定費セクション（Selector使用）
  Widget _buildFixedCostsSectionWithSelector() {
    return Selector<AppState, _FixedCostsData>(
      selector: (_, appState) => _FixedCostsData(
        fixedCosts: appState.fixedCosts,
        totalFixedCosts: appState.fixedCostsTotal,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        return _buildFixedCostsSection(data);
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _getFormattedDate(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary.withOpacity(0.7),
            height: 1.3,
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.settings_outlined, size: 18, color: AppColors.textMuted.withOpacity(0.6)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 今月サマリーカード（リファクタ版）
  Widget _buildMonthlySummaryCard(_MonthlySummaryData data) {
    final monthlyExpenseTotal = data.thisMonthTotal + data.fixedCostsTotal;
    final remaining = (data.usableAmount ?? 0) - monthlyExpenseTotal;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HomeConstants.standardCardPadding),
      decoration: BoxDecoration(
        color: HomeConstants.cardBackground,
        borderRadius: BorderRadius.circular(HomeConstants.standardCardRadius),
        boxShadow: HomeConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '今月の状況',
            style: GoogleFonts.inter(
              fontSize: HomeConstants.summaryTitleSize,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // 残り金額（メイン）
          Row(
            children: [
              Text(
                '残り ',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                formatCurrency(remaining, data.currencyFormat),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: HomeConstants.summaryMainSize,
                  fontWeight: FontWeight.w600,
                  color: remaining < 0 ? AppColors.accentRed : HomeConstants.primaryText,
                ),
              ),
              const Spacer(),
              Text(
                'あと ${data.remainingDays}日',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 収入/出費（サブ）
          Row(
            children: [
              _buildMetric('収入', data.usableAmount ?? 0, AppColors.accentBlue, data.currencyFormat),
              const SizedBox(width: 24),
              _buildMetric('出費', monthlyExpenseTotal, Colors.grey[700]!, data.currencyFormat),
            ],
          ),
          const SizedBox(height: 8),
          // 状態メッセージ
          Text(
            _getDailyStatusText(),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, int value, Color color, String currencyFormat) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: HomeConstants.summaryLabelSize,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          formatCurrency(value, currencyFormat),
          style: GoogleFonts.ibmPlexSans(
            fontSize: HomeConstants.summaryMetricSize,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// クイック登録セクション（2カラムグリッド）
  Widget _buildQuickEntrySection(_QuickEntryData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'クイック登録',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuickEntryManageScreen(),
                ),
              ),
              child: Text(
                '+ 追加・管理',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (data.quickEntries.isEmpty)
          _buildEmptyQuickEntryHint()
        else
          _buildQuickEntryGrid(data.quickEntries, data.currencyFormat),
      ],
    );
  }

  /// クイック登録グリッド（2行×横スクロール）
  Widget _buildQuickEntryGrid(List<QuickEntry> entries, String currencyFormat) {
    // 2行に分割（奇数インデックスは上段、偶数インデックスは下段）
    final topRow = <QuickEntry>[];
    final bottomRow = <QuickEntry>[];
    for (var i = 0; i < entries.length; i++) {
      if (i % 2 == 0) {
        topRow.add(entries[i]);
      } else {
        bottomRow.add(entries[i]);
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上段
          Row(
            children: topRow
                .map((entry) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _buildQuickEntryTile(entry, currencyFormat),
                    ))
                .toList(),
          ),
          if (bottomRow.isNotEmpty) const SizedBox(height: 10),
          // 下段
          if (bottomRow.isNotEmpty)
            Row(
              children: bottomRow
                  .map((entry) => Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _buildQuickEntryTile(entry, currencyFormat),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }

  /// クイック登録が空の時のヒント表示
  Widget _buildEmptyQuickEntryHint() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const QuickEntryManageScreen(),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.accentBlue.withOpacity(0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: AppColors.accentBlue.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'よく使う支出を登録して、1タップで記録',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 今日使えるお金セクション（夜時間帯は振り返りカードに切り替え）

  /// クイック登録タイル（コンパクト・縦並びレイアウト）
  Widget _buildQuickEntryTile(QuickEntry entry, String currencyFormat) {
    // グレードに対応する色を取得
    Color gradeColor;
    Color gradeLightColor;
    String gradeLabel;

    switch (entry.grade) {
      case 'saving':
        gradeColor = AppColors.accentGreen;
        gradeLightColor = AppColors.accentGreenLight;
        gradeLabel = '節約';
        break;
      case 'reward':
        gradeColor = AppColors.accentOrange;
        gradeLightColor = AppColors.accentOrangeLight;
        gradeLabel = 'ご褒美';
        break;
      default:
        gradeColor = AppColors.accentBlue;
        gradeLightColor = AppColors.accentBlueLight;
        gradeLabel = '標準';
    }

    return GestureDetector(
      onTap: () => _executeQuickEntry(entry),
      onLongPress: () => showQuickEntryEditModal(context, entry: entry),
      child: Container(
        width: 130,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: gradeColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gradeColor.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上段: 項目名（十分なスペースを確保）
            Text(
              entry.title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 5),
            // 下段: 金額とラベル
            Row(
              children: [
                Text(
                  formatCurrency(entry.amount, currencyFormat),
                  style: GoogleFonts.ibmPlexSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary.withOpacity(0.85),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeLightColor.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    gradeLabel,
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// クイック登録を実行
  Future<void> _executeQuickEntry(QuickEntry entry) async {
    final appState = context.read<AppState>();
    final success = await appState.executeQuickEntry(entry);

    if (!mounted) return;

    if (success) {
      // グレードに対応する色を取得
      Color gradeColor;
      switch (entry.grade) {
        case 'saving':
          gradeColor = AppColors.accentGreen;
          break;
        case 'reward':
          gradeColor = AppColors.accentOrange;
          break;
        default:
          gradeColor = AppColors.accentBlue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${entry.title} を記録しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: gradeColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '記録に失敗しました',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.accentRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildRecentExpenses(_RecentExpensesData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '日々の出費',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withOpacity(0.85),
                height: 1.4,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
              child: Text(
                'すべて見る',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentBlue.withOpacity(0.8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (data.recentExpenses.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                '記録がありません',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textMuted.withOpacity(0.8),
                  height: 1.4,
                ),
              ),
            ),
          )
        else
          ...data.recentExpenses.map((expense) => _buildExpenseItem(expense, data.currencyFormat)),
      ],
    );
  }

  Widget _buildFixedCostsSection(_FixedCostsData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '今月の固定費',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary.withOpacity(0.85),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
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
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '合計',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary.withOpacity(0.8),
                              ),
                            ),
                            Text(
                              formatCurrency(data.totalFixedCosts, data.currencyFormat),
                              style: GoogleFonts.ibmPlexSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: _fixedCostsExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          size: 20,
                          color: AppColors.textMuted.withOpacity(0.6),
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
                          if (data.fixedCosts.isNotEmpty)
                            ...data.fixedCosts.map((fc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fc.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400,
                                          color: AppColors.textSecondary.withOpacity(0.9),
                                        ),
                                      ),
                                      Text(
                                        formatCurrency(fc.amount, data.currencyFormat),
                                        style: GoogleFonts.ibmPlexSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textPrimary.withOpacity(0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                          if (data.fixedCosts.isEmpty)
                            Text(
                              '固定費が登録されていません',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textMuted.withOpacity(0.7),
                              ),
                            ),
                          const SizedBox(height: 8),
                          // 編集リンク
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const FixedCostHistoryScreen()),
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '編集',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentBlue.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.accentBlue.withOpacity(0.6),
                                ),
                              ],
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
        ),
      ],
    );
  }

  Widget _buildExpenseItem(Expense expense, String currencyFormat) {
    // カテゴリが「その他」の場合は非表示
    final showCategory = expense.category != 'その他';
    final dateLabel = _getDateLabel(expense.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showCategory)
                  Text(
                    expense.category,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary.withOpacity(0.9),
                      height: 1.4,
                    ),
                  ),
                // メモまたは日付を表示
                Padding(
                  padding: EdgeInsets.only(top: showCategory ? 4 : 0),
                  child: Text(
                    expense.memo != null && expense.memo!.isNotEmpty
                        ? '${expense.memo} • $dateLabel'
                        : dateLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textMuted.withOpacity(0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatCurrency(expense.amount, currencyFormat),
                style: GoogleFonts.ibmPlexSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary.withOpacity(0.9),
                ),
              ),
              const SizedBox(height: 3),
              _buildTypeBadge(expense.grade),
            ],
          ),
        ],
      ),
    );
  }

  String _getDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final expenseDate = DateTime(date.year, date.month, date.day);

    if (expenseDate == today) {
      return '今日';
    } else if (expenseDate == yesterday) {
      return '昨日';
    } else {
      return '${date.month}/${date.day}';
    }
  }

  Widget _buildTypeBadge(String type) {
    Color bgColor;
    Color textColor;
    String label = AppConstants.typeLabels[type] ?? type;

    switch (type) {
      case 'saving':
        bgColor = AppColors.accentGreenLight.withOpacity(0.7);
        textColor = AppColors.accentGreen;
        break;
      case 'standard':
        bgColor = AppColors.accentBlueLight.withOpacity(0.7);
        textColor = AppColors.accentBlue;
        break;
      case 'reward':
        bgColor = AppColors.accentPurpleLight.withOpacity(0.7);
        textColor = AppColors.accentPurple;
        break;
      default:
        bgColor = AppColors.textMuted.withOpacity(0.08);
        textColor = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

// === Selector用データクラス ===

/// HeroCard用データ
class _HeroCardData {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final String currencyFormat;

  const _HeroCardData({
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeroCardData &&
          runtimeType == other.runtimeType &&
          fixedTodayAllowance == other.fixedTodayAllowance &&
          dynamicTomorrowForecast == other.dynamicTomorrowForecast &&
          todayTotal == other.todayTotal &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      fixedTodayAllowance.hashCode ^
      dynamicTomorrowForecast.hashCode ^
      todayTotal.hashCode ^
      currencyFormat.hashCode;
}

/// 週間バジェット用データ
class _WeeklyBudgetData {
  final int? amount;
  final int daysRemaining;
  final DateTime endDate;
  final bool isWeekMode;
  final bool isOverBudget;
  final bool isPremium;
  final String currencyFormat;

  const _WeeklyBudgetData({
    required this.amount,
    required this.daysRemaining,
    required this.endDate,
    required this.isWeekMode,
    required this.isOverBudget,
    required this.isPremium,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _WeeklyBudgetData &&
          runtimeType == other.runtimeType &&
          amount == other.amount &&
          daysRemaining == other.daysRemaining &&
          endDate == other.endDate &&
          isWeekMode == other.isWeekMode &&
          isOverBudget == other.isOverBudget &&
          isPremium == other.isPremium &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      amount.hashCode ^
      daysRemaining.hashCode ^
      endDate.hashCode ^
      isWeekMode.hashCode ^
      isOverBudget.hashCode ^
      isPremium.hashCode ^
      currencyFormat.hashCode;
}

/// 今月サマリー用データ
class _MonthlySummaryData {
  final int? usableAmount;
  final int fixedCostsTotal;
  final int thisMonthTotal;
  final int remainingDays;
  final String currencyFormat;

  const _MonthlySummaryData({
    required this.usableAmount,
    required this.fixedCostsTotal,
    required this.thisMonthTotal,
    required this.remainingDays,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MonthlySummaryData &&
          runtimeType == other.runtimeType &&
          usableAmount == other.usableAmount &&
          fixedCostsTotal == other.fixedCostsTotal &&
          thisMonthTotal == other.thisMonthTotal &&
          remainingDays == other.remainingDays &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      usableAmount.hashCode ^
      fixedCostsTotal.hashCode ^
      thisMonthTotal.hashCode ^
      remainingDays.hashCode ^
      currencyFormat.hashCode;
}

/// クイック登録用データ
class _QuickEntryData {
  final List<QuickEntry> quickEntries;
  final String currencyFormat;

  const _QuickEntryData({
    required this.quickEntries,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _QuickEntryData &&
          runtimeType == other.runtimeType &&
          _listEquals(quickEntries, other.quickEntries) &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode => quickEntries.length.hashCode ^ currencyFormat.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 日々の出費用データ
class _RecentExpensesData {
  final List<Expense> recentExpenses;
  final String currencyFormat;

  const _RecentExpensesData({
    required this.recentExpenses,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _RecentExpensesData &&
          runtimeType == other.runtimeType &&
          _listEquals(recentExpenses, other.recentExpenses) &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode => recentExpenses.length.hashCode ^ currencyFormat.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 固定費用データ
class _FixedCostsData {
  final List<FixedCost> fixedCosts;
  final int totalFixedCosts;
  final String currencyFormat;

  const _FixedCostsData({
    required this.fixedCosts,
    required this.totalFixedCosts,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FixedCostsData &&
          runtimeType == other.runtimeType &&
          _listEquals(fixedCosts, other.fixedCosts) &&
          totalFixedCosts == other.totalFixedCosts &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      fixedCosts.length.hashCode ^
      totalFixedCosts.hashCode ^
      currencyFormat.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
