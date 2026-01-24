import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../config/home_constants.dart';
import '../services/app_state.dart';
import '../models/expense.dart';
import '../models/quick_entry.dart';
import '../models/scheduled_expense.dart';
import 'add_scheduled_expense_screen.dart';
import 'scheduled_expenses_list_screen.dart';
import '../utils/formatters.dart';
import '../widgets/quick_entry/quick_entry_edit_modal.dart';
import '../widgets/night_reflection_dialog.dart';
import '../widgets/home/hero_card.dart';
import '../widgets/home/weekly_budget_card.dart';
import 'premium_screen.dart';
import 'quick_entry_manage_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'category_budget_screen.dart';
import '../widgets/home/category_budget_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
      isPremium: appState.isPremium,
    );

    // 開封マーク
    await _markReflectionAsOpened(DateTime.now());
    if (mounted) {
      setState(() {
        _hasOpenedReflectionToday = true;
      });
    }
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
                        // カテゴリ予算セクション（Premium機能）
                        _buildCategoryBudgetSection(),
                        // クイック登録セクション - Selector化
                        _buildQuickEntrySectionWithSelector(),
                        const SizedBox(height: 16),
                        // 予定支出セクション（Premium機能）
                        _buildScheduledExpensesSection(),
                        // 日々の出費 - Selector化
                        _buildRecentExpensesSection(),
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
        remainingDays: appState.remainingDaysInMonth,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        final appState = context.read<AppState>();
        return HeroCard(
          fixedTodayAllowance: data.fixedTodayAllowance,
          dynamicTomorrowForecast: data.dynamicTomorrowForecast,
          todayTotal: data.todayTotal,
          remainingDays: data.remainingDays,
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
        // Free版では非表示
        if (!data.isPremium) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: WeeklyBudgetCard(
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
          ),
        );
      },
    );
  }

  /// 予定支出セクション（Premium機能）
  Widget _buildScheduledExpensesSection() {
    return Selector<AppState, _ScheduledExpensesData>(
      selector: (_, appState) => _ScheduledExpensesData(
        scheduledExpenses: appState.unconfirmedScheduledExpenses,
        isPremium: appState.isPremium,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        // Premiumでない場合、または予定支出がない場合は非表示
        if (!data.isPremium || data.scheduledExpenses.isEmpty) {
          return const SizedBox.shrink();
        }

        final allExpenses = data.scheduledExpenses;
        final hasMore = allExpenses.length > 2;
        final displayExpenses = hasMore ? allExpenses.take(2).toList() : allExpenses;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // セクションヘッダー
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '予定している支出',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (hasMore)
                  GestureDetector(
                    onTap: () => _showAllScheduledExpenses(allExpenses, data.currencyFormat),
                    child: Text(
                      'すべて見る',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.accentBlue,
                      ),
                    ),
                  )
                else
                  Text(
                    '${allExpenses.length}件',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // 予定支出リスト
            Container(
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                children: displayExpenses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final scheduled = entry.value;
                  final isLast = index == displayExpenses.length - 1;

                  return _buildScheduledExpenseItem(
                    scheduled,
                    data.currencyFormat,
                    isLast: isLast,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  /// すべての予定支出を表示
  void _showAllScheduledExpenses(List<ScheduledExpense> expenses, String currencyFormat) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduledExpensesListScreen(
          expenses: expenses,
          currencyFormat: currencyFormat,
        ),
      ),
    );
  }

  /// 予定支出アイテム
  Widget _buildScheduledExpenseItem(
    ScheduledExpense scheduled,
    String currencyFormat, {
    bool isLast = false,
  }) {
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final date = scheduled.scheduledDate;
    final weekday = weekdays[date.weekday - 1];
    final dateStr = '${date.month}/${date.day}（$weekday）';

    // グレードの色、ラベル、アイコン
    Color gradeColor;
    String gradeLabel;
    IconData gradeIcon;
    switch (scheduled.grade) {
      case 'saving':
        gradeColor = AppColors.accentGreen;
        gradeLabel = '節約';
        gradeIcon = Icons.savings_outlined;
        break;
      case 'reward':
        gradeColor = AppColors.accentOrange;
        gradeLabel = 'ご褒美';
        gradeIcon = Icons.star_outline;
        break;
      default:
        gradeColor = AppColors.accentBlue;
        gradeLabel = '標準';
        gradeIcon = Icons.balance_outlined;
    }

    return GestureDetector(
      onTap: () => _showScheduledExpenseActionSheet(scheduled),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: AppColors.borderSubtle),
                ),
        ),
        child: Row(
          children: [
            // カテゴリアイコン
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                gradeIcon,
                size: 18,
                color: gradeColor,
              ),
            ),
            const SizedBox(width: 12),

            // カテゴリ名と日付
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          scheduled.memo?.isNotEmpty == true
                              ? scheduled.memo!
                              : scheduled.category,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // グレードバッジ
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gradeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          gradeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: gradeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // 金額
            Text(
              formatCurrency(scheduled.amount, currencyFormat),
              style: GoogleFonts.ibmPlexSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 予定支出アクションシート
  void _showScheduledExpenseActionSheet(ScheduledExpense scheduled) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ハンドル
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                // 編集
                ListTile(
                  leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
                  title: Text(
                    '編集',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddScheduledExpenseScreen(
                          editingExpense: scheduled,
                        ),
                      ),
                    );
                  },
                ),

                // 削除
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: AppColors.accentRed),
                  title: Text(
                    '削除',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: AppColors.accentRed,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final appState = context.read<AppState>();
                    await appState.deleteScheduledExpense(scheduled.id!);
                  },
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// カテゴリ予算セクション（Premium機能）
  Widget _buildCategoryBudgetSection() {
    return Selector<AppState, _CategoryBudgetSectionData>(
      selector: (_, appState) => _CategoryBudgetSectionData(
        isPremium: appState.isPremium,
        categoryBudgets: appState.categoryBudgets,
        currencyFormat: appState.currencyFormat,
      ),
      builder: (context, data, child) {
        // Premiumでない場合は非表示
        if (!data.isPremium) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: context.read<AppState>().getCategoryBudgetStatus(),
          builder: (context, snapshot) {
            final budgetStatusList = snapshot.data ?? [];

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: CategoryBudgetSection(
                budgetStatusList: budgetStatusList,
                currencyFormat: data.currencyFormat,
                onEditTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryBudgetScreen(),
                    ),
                  );
                },
                onSetupTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryBudgetScreen(),
                    ),
                  );
                },
              ),
            );
          },
        );
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

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _getFormattedDate(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
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
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(Icons.settings_outlined, size: 18, color: AppColors.textMuted.withValues(alpha: 0.6)),
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
                color: AppColors.textPrimary.withValues(alpha: 0.85),
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
                  color: AppColors.accentBlue.withValues(alpha: 0.8),
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
            color: AppColors.accentBlue.withValues(alpha: 0.2),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 18,
              color: AppColors.accentBlue.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              'よく使う支出を登録して、1タップで記録',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
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
            color: gradeColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: gradeColor.withValues(alpha: 0.06),
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
                color: AppColors.textPrimary.withValues(alpha: 0.9),
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
                    color: AppColors.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeLightColor.withValues(alpha: 0.6),
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
              '日々の支出',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary.withValues(alpha: 0.85),
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
                  color: AppColors.accentBlue.withValues(alpha: 0.8),
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
                  color: AppColors.textMuted.withValues(alpha: 0.8),
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

  Widget _buildExpenseItem(Expense expense, String currencyFormat) {
    // カテゴリが「その他」の場合は非表示
    final showCategory = expense.category != 'その他';
    final dateLabel = _getDateLabel(expense.createdAt);

    // グレードの色とアイコン
    Color gradeColor;
    IconData gradeIcon;
    switch (expense.grade) {
      case 'saving':
        gradeColor = AppColors.accentGreen;
        gradeIcon = Icons.savings_outlined;
        break;
      case 'reward':
        gradeColor = AppColors.accentOrange;
        gradeIcon = Icons.star_outline;
        break;
      default:
        gradeColor = AppColors.accentBlue;
        gradeIcon = Icons.balance_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // グレードアイコン
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              gradeIcon,
              size: 18,
              color: gradeColor,
            ),
          ),
          const SizedBox(width: 12),
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
                      color: AppColors.textPrimary.withValues(alpha: 0.9),
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
                      color: AppColors.textMuted.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(expense.amount, currencyFormat),
            style: GoogleFonts.ibmPlexSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary.withValues(alpha: 0.9),
            ),
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
}

// === Selector用データクラス ===

/// HeroCard用データ
class _HeroCardData {
  final int? fixedTodayAllowance;
  final int? dynamicTomorrowForecast;
  final int todayTotal;
  final int remainingDays;
  final String currencyFormat;

  const _HeroCardData({
    required this.fixedTodayAllowance,
    required this.dynamicTomorrowForecast,
    required this.todayTotal,
    required this.remainingDays,
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
          remainingDays == other.remainingDays &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      fixedTodayAllowance.hashCode ^
      dynamicTomorrowForecast.hashCode ^
      todayTotal.hashCode ^
      remainingDays.hashCode ^
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

/// 予定支出用データ
class _ScheduledExpensesData {
  final List<ScheduledExpense> scheduledExpenses;
  final bool isPremium;
  final String currencyFormat;

  const _ScheduledExpensesData({
    required this.scheduledExpenses,
    required this.isPremium,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _ScheduledExpensesData &&
          runtimeType == other.runtimeType &&
          _listEquals(scheduledExpenses, other.scheduledExpenses) &&
          isPremium == other.isPremium &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      scheduledExpenses.length.hashCode ^
      isPremium.hashCode ^
      currencyFormat.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// カテゴリ予算セクション用データ
class _CategoryBudgetSectionData {
  final bool isPremium;
  final List<dynamic> categoryBudgets;
  final String currencyFormat;

  const _CategoryBudgetSectionData({
    required this.isPremium,
    required this.categoryBudgets,
    required this.currencyFormat,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _CategoryBudgetSectionData &&
          runtimeType == other.runtimeType &&
          isPremium == other.isPremium &&
          categoryBudgets.length == other.categoryBudgets.length &&
          currencyFormat == other.currencyFormat;

  @override
  int get hashCode =>
      isPremium.hashCode ^
      categoryBudgets.length.hashCode ^
      currencyFormat.hashCode;
}
