import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../config/typography.dart';
import '../config/constants.dart';
import '../services/app_state.dart';
import '../services/database_service.dart';
import '../core/financial_cycle.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';
import '../widgets/split_modal.dart';
import '../widgets/edit_amount_modal.dart';

/// 垂直タイムライン形式の履歴画面（全履歴対応・サイクル境界表示）
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final DatabaseService _databaseService = DatabaseService();

  // ページネーション用状態
  static const int _pageSize = 50;
  final List<Expense> _allExpenses = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _totalCount = 0;

  // 検索用状態
  final List<Expense> _searchResults = [];
  bool _isSearchLoading = false;
  bool _searchHasMore = true;
  int _searchTotalCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 初期データ読み込み
  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _allExpenses.clear();
      _hasMore = true;
    });

    try {
      _totalCount = await _databaseService.getAllExpensesCount();
      final expenses = await _databaseService.getAllExpensesPaged(
        limit: _pageSize,
        offset: 0,
      );
      setState(() {
        _allExpenses.addAll(expenses);
        _hasMore = expenses.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// スクロール時に追加データ読み込み
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_isSearching && _searchController.text.isNotEmpty) {
        _loadMoreSearchResults();
      } else {
        _loadMoreExpenses();
      }
    }
  }

  /// 追加の支出データを読み込み
  Future<void> _loadMoreExpenses() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final expenses = await _databaseService.getAllExpensesPaged(
        limit: _pageSize,
        offset: _allExpenses.length,
      );
      setState(() {
        _allExpenses.addAll(expenses);
        _hasMore = expenses.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  /// 検索実行
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _searchHasMore = true;
        _searchTotalCount = 0;
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
      _searchResults.clear();
      _searchHasMore = true;
    });

    try {
      _searchTotalCount = await _databaseService.searchExpensesCount(query);
      final results = await _databaseService.searchExpensesPaged(
        query: query,
        limit: _pageSize,
        offset: 0,
      );
      setState(() {
        _searchResults.addAll(results);
        _searchHasMore = results.length == _pageSize;
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() => _isSearchLoading = false);
    }
  }

  /// 追加の検索結果を読み込み
  Future<void> _loadMoreSearchResults() async {
    if (_isSearchLoading || !_searchHasMore) return;
    final query = _searchController.text;
    if (query.isEmpty) return;

    setState(() => _isSearchLoading = true);

    try {
      final results = await _databaseService.searchExpensesPaged(
        query: query,
        limit: _pageSize,
        offset: _searchResults.length,
      );
      setState(() {
        _searchResults.addAll(results);
        _searchHasMore = results.length == _pageSize;
        _isSearchLoading = false;
      });
    } catch (e) {
      setState(() => _isSearchLoading = false);
    }
  }

  /// 支出を日付でグループ化（日付降順）
  Map<DateTime, List<Expense>> _groupExpensesByDate(List<Expense> expenses) {
    final Map<DateTime, List<Expense>> grouped = {};

    for (final expense in expenses) {
      final expenseDate = DateTime(
        expense.createdAt.year,
        expense.createdAt.month,
        expense.createdAt.day,
      );
      grouped.putIfAbsent(expenseDate, () => []);
      grouped[expenseDate]!.add(expense);
    }

    // 各日の支出を時刻順（新しい順）にソート
    for (final list in grouped.values) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return grouped;
  }

  /// 指定日付のサイクルキーを取得
  String _getCycleKeyForDate(DateTime date, int mainSalaryDay) {
    final cycle = FinancialCycle(mainSalaryDay: mainSalaryDay);
    return cycle.getCycleKey(date);
  }

  /// サイクルの期間文字列を生成（例: "2025/12/25 〜 2026/01/24"）
  String _getCyclePeriodLabel(DateTime date, int mainSalaryDay) {
    final cycle = FinancialCycle(mainSalaryDay: mainSalaryDay);
    final startDate = cycle.getStartDate(date);
    final endDate = cycle.getEndDate(date);
    return '${startDate.year}/${startDate.month}/${startDate.day} 〜 ${endDate.year}/${endDate.month}/${endDate.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppState, int>(
      selector: (_, appState) => appState.mainSalaryDay,
      builder: (context, mainSalaryDay, child) {
        return Scaffold(
          backgroundColor: context.appTheme.bgPrimary,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                if (_isSearching) _buildSearchBar(),
                Expanded(
                  child: _buildContent(mainSalaryDay),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(int mainSalaryDay) {
    // 初期ロード中
    if (_isLoading && _allExpenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 検索中
    if (_isSearching && _searchController.text.isNotEmpty) {
      return _buildSearchResults(mainSalaryDay);
    }

    // 全履歴表示
    return _buildFullHistoryList(mainSalaryDay);
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.appTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                boxShadow: context.cardElevationShadow,
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: context.appTheme.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '履歴',
                  style: AppTextStyles.pageTitle(context),
                ),
                if (_totalCount > 0)
                  Text(
                    '全 ${formatNumber(_totalCount)} 件',
                    style: AppTextStyles.caption(context),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults.clear();
                }
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isSearching
                    ? AppColors.accentBlueLight.withValues(alpha: 0.7)
                    : context.appTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                boxShadow: context.cardElevationShadow,
              ),
              child: Icon(
                Icons.search_rounded,
                size: 20,
                color: _isSearching
                    ? AppColors.accentBlue
                    : context.appTheme.textSecondary.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        onChanged: (value) {
          _performSearch(value);
        },
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: context.appTheme.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: 'カテゴリ・メモで検索（全期間）',
          hintStyle: GoogleFonts.inter(
            color: context.appTheme.textMuted.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: context.appTheme.textMuted.withValues(alpha: 0.6),
            size: 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear,
                      color: context.appTheme.textMuted.withValues(alpha: 0.6), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: context.appTheme.bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: context.appTheme.borderSubtle.withValues(alpha: 0.5)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: context.appTheme.borderSubtle.withValues(alpha: 0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: AppColors.accentBlue.withValues(alpha: 0.5)),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  /// 全履歴リスト（サイクル境界ヘッダー付き）
  Widget _buildFullHistoryList(int mainSalaryDay) {
    if (_allExpenses.isEmpty) {
      return _buildEmptyState();
    }
    final groupedExpenses = _groupExpensesByDate(_allExpenses);
    final sortedDates = groupedExpenses.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // 降順

    // リストアイテムを構築（日付 + サイクルヘッダー）
    final List<_HistoryListItem> listItems = [];
    String? previousCycleKey;

    for (final date in sortedDates) {
      final cycleKey = _getCycleKeyForDate(date, mainSalaryDay);

      // サイクルが変わったらヘッダーを挿入
      if (previousCycleKey != null && cycleKey != previousCycleKey) {
        listItems.add(_HistoryListItem(
          type: _ListItemType.cycleHeader,
          cycleKey: cycleKey,
          cyclePeriod: _getCyclePeriodLabel(date, mainSalaryDay),
        ));
      } else if (previousCycleKey == null) {
        // 最初のサイクルのヘッダー
        listItems.add(_HistoryListItem(
          type: _ListItemType.cycleHeader,
          cycleKey: cycleKey,
          cyclePeriod: _getCyclePeriodLabel(date, mainSalaryDay),
        ));
      }

      listItems.add(_HistoryListItem(
        type: _ListItemType.dateRow,
        date: date,
        expenses: groupedExpenses[date]!,
      ));

      previousCycleKey = cycleKey;
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
      itemCount: listItems.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= listItems.length) {
          // ローディングインジケーター
          return _buildLoadingIndicator();
        }

        final item = listItems[index];
        if (item.type == _ListItemType.cycleHeader) {
          return _buildCycleHeader(item.cyclePeriod!);
        } else {
          final expenses = item.expenses!;
          final dayTotal = expenses.fold(0, (sum, e) => sum + e.amount);
          final isFirst = index == 0 ||
              listItems[index - 1].type == _ListItemType.cycleHeader;
          final isLast = index == listItems.length - 1 ||
              (index + 1 < listItems.length &&
                  listItems[index + 1].type == _ListItemType.cycleHeader);

          return _buildTimelineRow(
            date: item.date!,
            expenses: expenses,
            dayTotal: dayTotal,
            isFirst: isFirst,
            isLast: isLast,
          );
        }
      },
    );
  }

  /// サイクル境界ヘッダー
  Widget _buildCycleHeader(String periodLabel) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentBlueLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accentBlue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: 18,
            color: AppColors.accentBlue.withValues(alpha: 0.8),
          ),
          const SizedBox(width: 10),
          Text(
            periodLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.accentBlue,
            ),
          ),
        ],
      ),
    );
  }

  /// ローディングインジケーター
  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentBlue.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// 検索結果表示
  Widget _buildSearchResults(int mainSalaryDay) {
    if (_isSearchLoading && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: context.appTheme.textMuted.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 14),
            Text(
              '検索結果がありません',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.appTheme.textMuted.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // 検索結果件数
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatNumber(_searchTotalCount)} 件の結果',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textMuted.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            itemCount: _searchResults.length + (_searchHasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _searchResults.length) {
                return _buildLoadingIndicator();
              }

              final expense = _searchResults[index];
              // サイクル境界チェック
              final currentCycleKey =
                  _getCycleKeyForDate(expense.createdAt, mainSalaryDay);
              final showCycleHeader = index == 0 ||
                  _getCycleKeyForDate(
                          _searchResults[index - 1].createdAt, mainSalaryDay) !=
                      currentCycleKey;

              return Column(
                children: [
                  if (showCycleHeader)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 8),
                      child: _buildCycleHeader(
                        _getCyclePeriodLabel(expense.createdAt, mainSalaryDay),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildExpenseRow(expense, showDate: true),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 56,
            color: context.appTheme.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 14),
          Text(
            '支出データがありません',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.appTheme.textMuted.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// タイムライン行（左: 日付、中央: 垂直線、右: コンテンツ）
  Widget _buildTimelineRow({
    required DateTime date,
    required List<Expense> expenses,
    required int dayTotal,
    required bool isFirst,
    required bool isLast,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date == today;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 左カラム: 日付エリア（固定幅）
          SizedBox(
            width: 56,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 12, bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 月表示（日が1日の場合、または今日の場合）
                  if (date.day == 1 || isToday)
                    Text(
                      '${date.month}月',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isToday
                            ? AppColors.accentBlue.withValues(alpha: 0.7)
                            : context.appTheme.textMuted.withValues(alpha: 0.6),
                      ),
                    ),
                  // 日付（数字を大きく）
                  Text(
                    '${date.day}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 22,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday
                          ? AppColors.accentBlue
                          : context.appTheme.textPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  // 曜日（小さく）
                  Text(
                    _getWeekdayLabel(date.weekday),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isToday
                          ? AppColors.accentBlue.withValues(alpha: 0.8)
                          : context.appTheme.textMuted.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 中央: 垂直線
          SizedBox(
            width: 20,
            child: Column(
              children: [
                // 上部の線（最初の行は非表示）
                Expanded(
                  child: Container(
                    width: 1,
                    color: isFirst ? Colors.transparent : context.appTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                // ドット
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: expenses.isNotEmpty
                        ? AppColors.accentBlue.withValues(alpha: 0.6)
                        : context.appTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                // 下部の線（最後の行は非表示）
                Expanded(
                  child: Container(
                    width: 1,
                    color: isLast ? Colors.transparent : context.appTheme.textMuted.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
          ),
          // 右カラム: コンテンツエリア
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              child: expenses.isEmpty
                  ? _buildEmptyDay()
                  : _buildDayContent(expenses, dayTotal),
            ),
          ),
        ],
      ),
    );
  }

  /// 支出がない日の表示
  Widget _buildEmptyDay() {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      alignment: Alignment.centerLeft,
      child: Text(
        '',
        style: GoogleFonts.inter(
          fontSize: 12,
          color: context.appTheme.textMuted.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  /// 日のコンテンツ（合計 + 明細）
  Widget _buildDayContent(List<Expense> expenses, int dayTotal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 日の合計金額
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            '¥${formatNumber(dayTotal)}',
            style: GoogleFonts.ibmPlexSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: context.appTheme.textPrimary,
            ),
          ),
        ),
        // 支出明細
        ...expenses.asMap().entries.map((entry) {
          final index = entry.key;
          final expense = entry.value;
          final isLast = index == expenses.length - 1;

          return Column(
            children: [
              _buildExpenseRow(expense),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 0.5,
                  color: Colors.grey[200],
                ),
            ],
          );
        }),
      ],
    );
  }

  /// 支出明細行（タップでボトムシート）
  Widget _buildExpenseRow(Expense expense, {bool showDate = false}) {
    final time =
        '${expense.createdAt.hour.toString().padLeft(2, '0')}:${expense.createdAt.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showActionBottomSheet(expense),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              // 左: カテゴリと時刻
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          expense.category,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: context.appTheme.textPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          time,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    if (expense.memo != null && expense.memo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          expense.memo!,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (showDate)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${expense.createdAt.year}/${expense.createdAt.month}/${expense.createdAt.day}',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textMuted.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 右: 金額とグレード
              Row(
                children: [
                  Text(
                    '¥${formatNumber(expense.amount)}',
                    style: GoogleFonts.ibmPlexSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.appTheme.textPrimary.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildGradeBadge(expense.grade),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// グレードバッジ
  Widget _buildGradeBadge(String grade) {
    Color bgColor;
    Color textColor;
    String label = AppConstants.typeLabels[grade] ?? grade;

    switch (grade) {
      case 'saving':
        bgColor = AppColors.accentGreenLight.withValues(alpha: 0.7);
        textColor = AppColors.accentGreen;
        break;
      case 'standard':
        bgColor = AppColors.accentBlueLight.withValues(alpha: 0.7);
        textColor = AppColors.accentBlue;
        break;
      case 'reward':
        bgColor = AppColors.accentOrangeLight.withValues(alpha: 0.7);
        textColor = AppColors.accentOrange;
        break;
      default:
        bgColor = context.appTheme.textMuted.withValues(alpha: 0.08);
        textColor = context.appTheme.textMuted;
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
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// 曜日ラベル
  String _getWeekdayLabel(int weekday) {
    const labels = ['月', '火', '水', '木', '金', '土', '日'];
    return labels[weekday - 1];
  }

  /// アクションボトムシート
  void _showActionBottomSheet(Expense expense) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドル
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appTheme.textMuted.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // 選択した支出の情報
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            expense.category,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: context.appTheme.textPrimary,
                            ),
                          ),
                          if (expense.memo != null && expense.memo!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                expense.memo!,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: context.appTheme.textSecondary,
                                ),
                              ),
                            ),
                          // 日付表示
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${expense.createdAt.year}/${expense.createdAt.month}/${expense.createdAt.day}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: context.appTheme.textMuted.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '¥${formatNumber(expense.amount)}',
                      style: GoogleFonts.ibmPlexSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.appTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),
              // アクションメニュー
              _buildBottomSheetAction(
                icon: Icons.edit_outlined,
                label: '金額を修正',
                onTap: () {
                  Navigator.pop(context);
                  _showEditAmountModal(expense);
                },
              ),
              _buildBottomSheetAction(
                icon: Icons.content_cut_outlined,
                label: 'この支出を切り出す',
                onTap: () {
                  Navigator.pop(context);
                  _showSplitModal(expense);
                },
              ),
              _buildBottomSheetAction(
                icon: Icons.delete_outline,
                label: '削除する',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(expense);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// ボトムシートのアクション行
  Widget _buildBottomSheetAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: isDestructive
                    ? AppColors.accentRed
                    : context.appTheme.textSecondary,
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDestructive
                      ? AppColors.accentRed
                      : context.appTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSplitModal(Expense expense) {
    showSplitModal(context, expense, () {
      context.read<AppState>().loadData();
      _loadInitialData(); // 履歴も再読み込み
    });
  }

  void _showEditAmountModal(Expense expense) {
    showEditAmountModal(context, expense, () {
      context.read<AppState>().loadData();
      _loadInitialData(); // 履歴も再読み込み
    });
  }

  void _showDeleteConfirmation(Expense expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '支出を削除',
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.appTheme.textPrimary,
          ),
        ),
        content: Text(
          '「${expense.category}」¥${formatNumber(expense.amount)} を削除しますか？\n\nこの操作は取り消せません。',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: context.appTheme.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'キャンセル',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: context.appTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final success =
                  await context.read<AppState>().deleteExpense(expense.id!);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                _loadInitialData(); // 履歴を再読み込み
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? '削除しました' : '削除に失敗しました',
                    style: GoogleFonts.inter(),
                  ),
                  backgroundColor:
                      success ? AppColors.accentGreen : AppColors.accentRed,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              '削除',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accentRed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 履歴リストアイテムの種類
enum _ListItemType {
  cycleHeader,
  dateRow,
}

/// 履歴リストアイテム
class _HistoryListItem {
  final _ListItemType type;
  final String? cycleKey;
  final String? cyclePeriod;
  final DateTime? date;
  final List<Expense>? expenses;

  _HistoryListItem({
    required this.type,
    this.cycleKey,
    this.cyclePeriod,
    this.date,
    this.expenses,
  });
}
