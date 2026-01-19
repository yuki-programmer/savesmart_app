import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
import '../models/quick_entry.dart';
import '../config/constants.dart';
import '../core/dev_config.dart';
import '../core/financial_cycle.dart';
import 'database_service.dart';
import 'performance_monitor.dart';

class CategoryStats {
  final String category;
  final int totalAmount;
  final int standardAverage;
  final int expenseCount;

  CategoryStats({
    required this.category,
    required this.totalAmount,
    required this.standardAverage,
    required this.expenseCount,
  });
}

class AppState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();

  List<Expense> _expenses = [];
  List<Category> _categories = [];
  List<FixedCost> _fixedCosts = [];
  List<FixedCostCategory> _fixedCostCategories = [];
  List<QuickEntry> _quickEntries = [];
  Budget? _currentBudget;
  bool _isLoading = true;

  // === Premium / Entitlement ===
  // ignore: prefer_final_fields - 将来の実課金判定で変更予定
  bool _storePremium = false;
  bool? _devPremiumOverride; // null=override無し, true/false=強制
  bool _devModeUnlocked = false; // バージョン10回タップで解放

  static const String _keyDevPremiumOverride = 'dev_premium_override';
  static const String _keyDevModeUnlocked = 'dev_mode_unlocked';

  // === 月別使える金額 ===
  final Map<String, int?> _monthlyAvailableAmounts = {};
  static const String _keyMonthlyAmountPrefix = 'monthly_amount_';

  // === FinancialCycle（給料日ベースのサイクル管理） ===
  int _mainSalaryDay = 1; // デフォルト: 1日（従来のカレンダー月と同じ）
  static const String _keyMainSalaryDay = 'main_salary_day';
  FinancialCycle _financialCycle = const FinancialCycle(mainSalaryDay: 1);

  // === デフォルト支出タイプ ===
  String _defaultExpenseGrade = 'standard'; // デフォルト: 標準
  static const String _keyDefaultExpenseGrade = 'default_expense_grade';

  // === 通貨表示形式 ===
  // 'prefix': ¥1,234 / 'suffix': 1,234円
  String _currencyFormat = 'prefix'; // デフォルト: ¥記号前置
  static const String _keyCurrencyFormat = 'currency_format';

  // === タブ切り替え & incomeSheet自動起動 ===
  int? _requestedTabIndex;
  bool _openIncomeSheetRequested = false;

  // === 今日使えるお金（固定値） ===
  int? _fixedTodayAllowance;

  // === サイクル収入（DB一元管理） ===
  int? _currentCycleIncomeTotal; // 現在サイクルの収入合計（キャッシュ）

  // === 計算キャッシュ（メモ化） ===
  List<Expense>? _cachedThisMonthExpenses;
  String? _cachedThisMonthExpensesCycleKey;
  int? _cachedThisMonthExpensesCount;

  List<Expense>? _cachedLast6MonthsExpenses;
  String? _cachedLast6MonthsKey; // YYYY-MM format

  Map<String, Map<String, Map<String, int>>>? _cachedCategoryGradeAverages;
  String? _cachedCategoryGradeAveragesKey;

  // Getters
  List<Expense> get expenses => _expenses;
  List<Category> get categories => _categories;
  List<FixedCost> get fixedCosts => _fixedCosts;
  List<FixedCostCategory> get fixedCostCategories => _fixedCostCategories;
  List<QuickEntry> get quickEntries => _quickEntries;
  Budget? get currentBudget => _currentBudget;
  bool get isLoading => _isLoading;

  /// プレミアム判定（全画面でこれを参照する）
  bool get isPremium => _devPremiumOverride ?? _storePremium;

  /// 開発者モードが解放されているか
  bool get isDevModeUnlocked => _devModeUnlocked;

  /// 現在のoverride値（null=override無し）
  bool? get devPremiumOverride => _devPremiumOverride;

  /// 給料日（サイクル開始日）
  int get mainSalaryDay => _mainSalaryDay;

  /// FinancialCycleインスタンス
  FinancialCycle get financialCycle => _financialCycle;

  /// デフォルト支出タイプ（saving/standard/reward）
  String get defaultExpenseGrade => _defaultExpenseGrade;

  /// 通貨表示形式（prefix: ¥1,234 / suffix: 1,234円）
  String get currencyFormat => _currencyFormat;

  // === 今日の支出キャッシュ ===
  List<Expense>? _cachedTodayExpenses;
  String? _cachedTodayExpensesDate;
  int? _cachedTodayTotal;
  String? _cachedTodayTotalDate;

  List<Expense> get todayExpenses {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // キャッシュが有効かチェック
    if (_cachedTodayExpenses != null && _cachedTodayExpensesDate == today) {
      return _cachedTodayExpenses!;
    }

    // メモリ内の_expensesからフィルタリング（同期的に返すため）
    final todayDate = DateTime(now.year, now.month, now.day);
    final result = _expenses.where((e) {
      final expenseDate = DateTime(
        e.createdAt.year,
        e.createdAt.month,
        e.createdAt.day,
      );
      return expenseDate == todayDate;
    }).toList();

    _cachedTodayExpenses = result;
    _cachedTodayExpensesDate = today;

    return result;
  }

  List<Expense> get thisWeekExpenses {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return _expenses.where((e) => e.createdAt.isAfter(start)).toList();
  }

  List<Expense> get thisMonthExpenses {
    return perfMonitor.measure('AppState.thisMonthExpenses', () {
      final now = DateTime.now();
      final cycleKey = _financialCycle.getCycleKey(now);

      // キャッシュが有効かチェック（同一サイクル & 同一件数）
      if (_cachedThisMonthExpenses != null &&
          _cachedThisMonthExpensesCycleKey == cycleKey &&
          _cachedThisMonthExpensesCount == _expenses.length) {
        return _cachedThisMonthExpenses!;
      }

      // FinancialCycleを使用してサイクル内の支出をフィルタ
      final result = _expenses.where((e) {
        return _financialCycle.isDateInCurrentCycle(e.createdAt, now);
      }).toList();

      // キャッシュを更新
      _cachedThisMonthExpenses = result;
      _cachedThisMonthExpensesCycleKey = cycleKey;
      _cachedThisMonthExpensesCount = _expenses.length;

      return result;
    });
  }

  /// 前月の支出リストを取得
  List<Expense> get previousMonthExpenses {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    return _expenses.where((e) {
      return e.createdAt.year == prevMonth.year && e.createdAt.month == prevMonth.month;
    }).toList();
  }

  /// 前月の使える金額を取得
  int? get previousMonthAvailableAmount {
    final now = DateTime.now();
    final prevMonth = DateTime(now.year, now.month - 1, 1);
    return getMonthlyAvailableAmount(prevMonth);
  }

  int get todayTotal {
    final now = DateTime.now();
    final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // キャッシュが有効かチェック
    if (_cachedTodayTotal != null && _cachedTodayTotalDate == today) {
      return _cachedTodayTotal!;
    }

    final result = todayExpenses.fold(0, (sum, e) => sum + e.amount);
    _cachedTodayTotal = result;
    _cachedTodayTotalDate = today;

    return result;
  }
  int get thisWeekTotal => thisWeekExpenses.fold(0, (sum, e) => sum + e.amount);
  int get thisMonthTotal => thisMonthExpenses.fold(0, (sum, e) => sum + e.amount);

  /// 固定費の合計
  int get fixedCostsTotal => _fixedCosts.fold(0, (sum, fc) => sum + fc.amount);

  /// 可処分金額 = 収入（使える金額）- 固定費合計
  /// 収入が未設定の場合は null を返す
  int? get disposableAmount {
    final income = thisMonthAvailableAmount;
    if (income == null) return null;
    return income - fixedCostsTotal;
  }

  /// 今日使えるお金（固定値 - DBから取得、なければ計算して保存）
  /// 一日の開始時点で固定され、支出を登録しても変動しない
  int? get fixedTodayAllowance => _fixedTodayAllowance;

  /// 明日の予算予測（変動値 - リアルタイム計算）
  /// 支出を登録するたびに再計算される
  int? get dynamicTomorrowForecast {
    final income = thisMonthAvailableAmount;
    if (income == null) return null;

    final now = DateTime.now();

    // サイクル最終日の場合は計算不可（明日は次のサイクル）
    if (_financialCycle.isLastDayOfCycle(now)) return null;

    // 今日までの支出合計
    final variableExpenseTotal = thisMonthTotal;

    // 現在の残り予算 = 予算 - 今日までの支出 - 固定費
    final remainingBudget = income - variableExpenseTotal - fixedCostsTotal;

    // 明日からサイクル終了日までの日数
    final remainingDaysFromTomorrow = _financialCycle.getDaysRemaining(now) - 1;

    if (remainingDaysFromTomorrow <= 0) return null;

    return (remainingBudget / remainingDaysFromTomorrow).round();
  }

  /// 今日がサイクル最終日かどうか
  bool get isLastDayOfMonth {
    final now = DateTime.now();
    return _financialCycle.isLastDayOfCycle(now);
  }

  /// サイクル終了日までの残り日数（今日を含む）
  int get remainingDaysInMonth {
    final now = DateTime.now();
    return _financialCycle.getDaysRemaining(now);
  }

  /// 昨日までの支出合計を取得（サイクル内、同期版 - メモリ内データ使用）
  int get _expenseTotalUntilYesterday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cycleStart = _financialCycle.getStartDate(now);

    return _expenses
        .where((e) {
          final expenseDate = DateTime(
            e.createdAt.year,
            e.createdAt.month,
            e.createdAt.day,
          );
          // サイクル開始日以降かつ今日より前
          return !expenseDate.isBefore(cycleStart) &&
              expenseDate.isBefore(today);
        })
        .fold(0, (sum, e) => sum + e.amount);
  }

  /// 昨日までの支出合計を取得（サイクル内、非同期版 - SQL集計）
  Future<int> getExpenseTotalUntilYesterdayAsync() async {
    final now = DateTime.now();
    final cycleStart = _financialCycle.getStartDate(now);
    return await _db.getExpenseTotalUntilYesterday(cycleStartDate: cycleStart);
  }

  /// 今日の固定予算を計算（DBに保存用）
  int? _calculateTodayAllowance() {
    final income = thisMonthAvailableAmount;
    if (income == null) return null;

    // 昨日までの支出
    final expensesUntilYesterday = _expenseTotalUntilYesterday;

    // 残り予算 = 予算 - 昨日までの支出 - 固定費
    final remainingBudget = income - expensesUntilYesterday - fixedCostsTotal;

    // 今日を含む残り日数
    final remainingDays = remainingDaysInMonth;

    return (remainingBudget / remainingDays).round();
  }

  /// 今日の固定予算をロード（なければ計算して保存）
  Future<void> _loadOrCreateTodayAllowance() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // DBから今日の値を取得
    final savedAmount = await _db.getDailyBudget(today);

    if (savedAmount != null) {
      _fixedTodayAllowance = savedAmount;
    } else {
      // 計算して保存
      final calculated = _calculateTodayAllowance();
      if (calculated != null) {
        await _db.saveDailyBudget(today, calculated);
        _fixedTodayAllowance = calculated;
      }
    }
  }

  Map<String, CategoryStats> get categoryStats {
    final Map<String, CategoryStats> stats = {};
    final monthExpenses = thisMonthExpenses;

    // カテゴリごとにグループ化（「その他」は除外）
    final Map<String, List<Expense>> byCategory = {};
    for (final expense in monthExpenses) {
      // カテゴリ未選択（その他）は分析対象外
      if (expense.category == 'その他') continue;
      byCategory.putIfAbsent(expense.category, () => []);
      byCategory[expense.category]!.add(expense);
    }

    // 各カテゴリの統計を計算
    for (final entry in byCategory.entries) {
      final expenses = entry.value;
      final totalAmount = expenses.fold(0, (sum, e) => sum + e.amount);

      // スタンダード平均を計算（全支出をスタンダードと仮定した場合）
      int standardTotal = 0;
      for (final expense in expenses) {
        switch (expense.grade) {
          case 'saving':
            standardTotal += (expense.amount / 0.7).round();
            break;
          case 'reward':
            standardTotal += (expense.amount / 1.3).round();
            break;
          default:
            standardTotal += expense.amount;
        }
      }
      final standardAverage = expenses.isNotEmpty
          ? (standardTotal / expenses.length).round()
          : 0;

      stats[entry.key] = CategoryStats(
        category: entry.key,
        totalAmount: totalAmount,
        standardAverage: standardAverage,
        expenseCount: expenses.length,
      );
    }

    return stats;
  }

  /// カテゴリ別統計を取得（非同期版 - SQL集計）
  /// standardAverageの計算はSQL結果から行う
  Future<Map<String, CategoryStats>> getCategoryStatsAsync() async {
    final now = DateTime.now();
    final cycleStart = _financialCycle.getStartDate(now);
    final cycleEnd = _financialCycle.getEndDate(now);

    final sqlStats = await _db.getCategoryStats(
      cycleStartDate: cycleStart,
      cycleEndDate: cycleEnd,
    );

    final Map<String, CategoryStats> stats = {};

    for (final row in sqlStats) {
      final category = row['category'] as String;
      final totalAmount = row['total_amount'] as int;
      final expenseCount = row['expense_count'] as int;
      final savingAmount = row['saving_amount'] as int;
      final standardAmount = row['standard_amount'] as int;
      final rewardAmount = row['reward_amount'] as int;
      final savingCount = row['saving_count'] as int;
      final rewardCount = row['reward_count'] as int;

      // スタンダード平均を計算（全支出をスタンダードと仮定した場合）
      // saving は 0.7倍、reward は 1.3倍で換算
      final standardTotal = (savingCount > 0 ? (savingAmount / 0.7).round() : 0) +
          standardAmount +
          (rewardCount > 0 ? (rewardAmount / 1.3).round() : 0);
      final standardAverage = expenseCount > 0
          ? (standardTotal / expenseCount).round()
          : 0;

      stats[category] = CategoryStats(
        category: category,
        totalAmount: totalAmount,
        standardAverage: standardAverage,
        expenseCount: expenseCount,
      );
    }

    return stats;
  }

  // Actions
  Future<void> loadData() async {
    perfMonitor.startTimer('AppState.loadData');
    _isLoading = true;
    notifyListeners();

    try {
      // デフォルト固定費カテゴリを確保（保険: マイグレーションで漏れた場合に補完）
      await _db.ensureDefaultFixedCostCategories();

      // 並列で取得（高速化）
      perfMonitor.startTimer('AppState.loadData.queries');
      final results = await Future.wait([
        _db.getExpenses(),
        _db.getCategories(),
        _db.getFixedCosts(),
        _db.getFixedCostCategories(),
        _db.getCurrentBudget(),
        _db.getQuickEntries(),
      ]);
      perfMonitor.stopTimer('AppState.loadData.queries');

      _expenses = results[0] as List<Expense>;
      _categories = results[1] as List<Category>;
      _fixedCosts = results[2] as List<FixedCost>;
      _fixedCostCategories = results[3] as List<FixedCostCategory>;
      _currentBudget = results[4] as Budget?;
      _quickEntries = results[5] as List<QuickEntry>;

      // サイクル収入をロード（FinancialCycleロード後に実行）
      await _loadCurrentCycleIncome();

      // 今日の固定予算をロード（データロード後に実行）
      await _loadOrCreateTodayAllowance();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
    perfMonitor.stopTimer('AppState.loadData');
  }

  // === 部分リロードメソッド（パフォーマンス最適化） ===

  Future<void> _reloadExpenses() async {
    _expenses = await _db.getExpenses();
    _invalidateExpensesCaches();
    notifyListeners();
  }

  /// 支出関連のキャッシュを無効化
  void _invalidateExpensesCaches() {
    _cachedThisMonthExpenses = null;
    _cachedThisMonthExpensesCycleKey = null;
    _cachedThisMonthExpensesCount = null;
    _cachedLast6MonthsExpenses = null;
    _cachedLast6MonthsKey = null;
    _cachedCategoryGradeAverages = null;
    _cachedCategoryGradeAveragesKey = null;
    // 今日の支出キャッシュもクリア
    _cachedTodayExpenses = null;
    _cachedTodayExpensesDate = null;
    _cachedTodayTotal = null;
    _cachedTodayTotalDate = null;
  }

  Future<void> _reloadCategories() async {
    _categories = await _db.getCategories();
    notifyListeners();
  }

  Future<void> _reloadFixedCosts() async {
    _fixedCosts = await _db.getFixedCosts();
    notifyListeners();
  }

  Future<void> _reloadFixedCostCategories() async {
    _fixedCostCategories = await _db.getFixedCostCategories();
    notifyListeners();
  }

  Future<void> _reloadBudget() async {
    _currentBudget = await _db.getCurrentBudget();
    notifyListeners();
  }

  Future<void> _reloadQuickEntries() async {
    _quickEntries = await _db.getQuickEntries();
    notifyListeners();
  }

  Future<bool> addExpense(Expense expense) async {
    try {
      await _db.insertExpense(expense);
      await _reloadExpenses();
      return true;
    } catch (e) {
      debugPrint('Error adding expense: $e');
      return false;
    }
  }

  Future<void> addExpenseWithBreakdowns(
    Expense mainExpense,
    List<Map<String, dynamic>> breakdowns,
  ) async {
    // メインの支出を追加
    final mainId = await _db.insertExpense(mainExpense);

    // 内訳を追加
    for (final breakdown in breakdowns) {
      final breakdownExpense = Expense(
        amount: breakdown['amount'] as int,
        category: breakdown['category'] as String,
        grade: breakdown['type'] as String? ?? mainExpense.grade,
        createdAt: mainExpense.createdAt,
        parentId: mainId,
      );
      await _db.insertExpense(breakdownExpense);
    }

    await _reloadExpenses();
  }

  Future<bool> updateExpense(Expense expense) async {
    try {
      await _db.updateExpense(expense);
      await _reloadExpenses();
      return true;
    } catch (e) {
      debugPrint('Error updating expense: $e');
      return false;
    }
  }

  Future<bool> deleteExpense(int id) async {
    try {
      await _db.deleteExpense(id);
      await _reloadExpenses();
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  Future<bool> splitExpense(int id, int splitAmount, String newCategory, {String? grade}) async {
    try {
      final original = _expenses.firstWhere((e) => e.id == id);
      final remainingAmount = original.amount - splitAmount;

      // 元の支出を更新
      final updatedOriginal = Expense(
        id: original.id,
        amount: remainingAmount,
        category: original.category,
        grade: original.grade,
        memo: original.memo,
        createdAt: original.createdAt,
        parentId: original.parentId,
      );
      await _db.updateExpense(updatedOriginal);

      // 新しい支出を作成（gradeが指定されていればそれを使用、なければ元のgrade）
      final newExpense = Expense(
        amount: splitAmount,
        category: newCategory,
        grade: grade ?? original.grade,
        memo: '${original.category}から切り出し',
        createdAt: original.createdAt,
        parentId: original.id,
      );
      await _db.insertExpense(newExpense);

      await _reloadExpenses();
      return true;
    } catch (e) {
      debugPrint('Error splitting expense: $e');
      return false;
    }
  }

  Future<void> addCategory(String name, {String? icon}) async {
    final sortOrder = _categories.length;
    final category = Category(
      name: name,
      sortOrder: sortOrder,
      isDefault: false,
      icon: icon,
    );
    await _db.insertCategory(category);
    await _reloadCategories();
  }

  // カテゴリ名とアイコンを更新
  Future<void> updateCategoryNameAndIcon(int id, String newName, {String? icon}) async {
    await _db.updateCategoryName(id, newName);
    // アイコンも更新する場合
    if (icon != null) {
      final category = _categories.firstWhere((c) => c.id == id);
      category.icon = icon;
      await _db.updateCategory(category);
    }
    await _reloadCategories();
  }

  // カテゴリを削除（関連する支出も削除）
  Future<void> deleteCategory(int id) async {
    await _db.deleteCategoryWithExpenses(id);
    // カテゴリ削除時は関連する支出も削除されるため両方リロード
    await _reloadCategories();
    await _reloadExpenses();
  }

  // カテゴリ別の支出件数を取得
  int getExpenseCountByCategory(String categoryName) {
    return _expenses.where((e) => e.category == categoryName).length;
  }

  /// カテゴリ別のグレード内訳を取得（今月分）
  /// 返り値: { 'saving': {'amount': int, 'count': int}, 'standard': {...}, 'reward': {...} }
  Map<String, Map<String, int>> getCategoryGradeBreakdown(String categoryName) {
    final result = <String, Map<String, int>>{
      'saving': {'amount': 0, 'count': 0},
      'standard': {'amount': 0, 'count': 0},
      'reward': {'amount': 0, 'count': 0},
    };

    final now = DateTime.now();
    final categoryExpenses = _expenses.where((e) {
      return e.category == categoryName &&
          e.createdAt.year == now.year &&
          e.createdAt.month == now.month;
    });

    for (final expense in categoryExpenses) {
      final grade = expense.grade;
      if (result.containsKey(grade)) {
        result[grade]!['amount'] = result[grade]!['amount']! + expense.amount;
        result[grade]!['count'] = result[grade]!['count']! + 1;
      }
    }

    return result;
  }

  /// カテゴリ詳細分析用データを取得（今月分 + 過去6ヶ月平均）
  /// 返り値: {
  ///   'thisMonth': { 'saving': {'amount': int, 'count': int, 'avg': int}, ... },
  ///   'last6MonthsAvg': { 'saving': {'avg': int, 'count': int}, ... },
  ///   'totalAmount': int,
  ///   'totalCount': int,
  /// }
  Map<String, dynamic> getCategoryDetailAnalysis(String categoryName) {
    perfMonitor.startTimer('AppState.getCategoryDetailAnalysis');
    final now = DateTime.now();

    // 今月のデータ
    final thisMonthData = <String, Map<String, int>>{
      'saving': {'amount': 0, 'count': 0},
      'standard': {'amount': 0, 'count': 0},
      'reward': {'amount': 0, 'count': 0},
    };

    final thisMonthExpenses = _expenses.where((e) {
      return e.category == categoryName &&
          e.createdAt.year == now.year &&
          e.createdAt.month == now.month;
    });

    for (final expense in thisMonthExpenses) {
      final grade = expense.grade;
      if (thisMonthData.containsKey(grade)) {
        thisMonthData[grade]!['amount'] = thisMonthData[grade]!['amount']! + expense.amount;
        thisMonthData[grade]!['count'] = thisMonthData[grade]!['count']! + 1;
      }
    }

    // 今月の平均単価を計算
    final thisMonthWithAvg = <String, Map<String, int>>{};
    for (final entry in thisMonthData.entries) {
      final count = entry.value['count']!;
      final amount = entry.value['amount']!;
      thisMonthWithAvg[entry.key] = {
        'amount': amount,
        'count': count,
        'avg': count > 0 ? (amount / count).round() : 0,
      };
    }

    // 過去6ヶ月のデータ（今月を除く）
    final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);
    final startOfThisMonth = DateTime(now.year, now.month, 1);

    final last6MonthsData = <String, Map<String, int>>{
      'saving': {'total': 0, 'count': 0},
      'standard': {'total': 0, 'count': 0},
      'reward': {'total': 0, 'count': 0},
    };

    final last6MonthsExpenses = _expenses.where((e) {
      return e.category == categoryName &&
          e.createdAt.isAfter(sixMonthsAgo) &&
          e.createdAt.isBefore(startOfThisMonth);
    });

    for (final expense in last6MonthsExpenses) {
      final grade = expense.grade;
      if (last6MonthsData.containsKey(grade)) {
        last6MonthsData[grade]!['total'] = last6MonthsData[grade]!['total']! + expense.amount;
        last6MonthsData[grade]!['count'] = last6MonthsData[grade]!['count']! + 1;
      }
    }

    // 過去6ヶ月の平均単価を計算
    final last6MonthsAvg = <String, Map<String, int>>{};
    for (final entry in last6MonthsData.entries) {
      final count = entry.value['count']!;
      final total = entry.value['total']!;
      last6MonthsAvg[entry.key] = {
        'avg': count > 0 ? (total / count).round() : 0,
        'count': count,
      };
    }

    // 合計
    int totalAmount = 0;
    int totalCount = 0;
    for (final data in thisMonthWithAvg.values) {
      totalAmount += data['amount']!;
      totalCount += data['count']!;
    }

    perfMonitor.stopTimer('AppState.getCategoryDetailAnalysis');
    return {
      'thisMonth': thisMonthWithAvg,
      'last6MonthsAvg': last6MonthsAvg,
      'totalAmount': totalAmount,
      'totalCount': totalCount,
    };
  }

  /// 月キーのリストを生成（0埋め用）
  /// 返り値: ['2024-07', '2024-08', ..., '2025-01'] のような形式
  static List<String> generateMonthKeys(int months) {
    final result = <String>[];
    final now = DateTime.now();
    for (var i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      result.add('${date.year}-${date.month.toString().padLeft(2, '0')}');
    }
    return result;
  }

  /// カテゴリ別・月別・グレード別の時系列データを取得（0埋め済み）
  /// 返り値: List<{
  ///   'month': 'YYYY-MM',
  ///   'monthLabel': 'M月',
  ///   'saving': int,
  ///   'standard': int,
  ///   'reward': int,
  ///   'total': int,
  /// }>
  Future<List<Map<String, dynamic>>> getCategoryMonthlyTrend(
    String categoryName, {
    int months = 12,
  }) async {
    // SQLで集計データを取得
    final rawData = await _db.getMonthlyGradeBreakdown(
      categoryName: categoryName,
      months: months,
    );

    // 月キーを生成（0埋め用）
    final monthKeys = generateMonthKeys(months);

    // 月別にデータを整理
    final monthlyData = <String, Map<String, int>>{};
    for (final key in monthKeys) {
      monthlyData[key] = {
        'saving': 0,
        'standard': 0,
        'reward': 0,
      };
    }

    // SQLの結果をマージ
    for (final row in rawData) {
      final month = row['month'] as String;
      final grade = row['grade'] as String;
      final total = row['total'] as int;

      if (monthlyData.containsKey(month) && monthlyData[month]!.containsKey(grade)) {
        monthlyData[month]![grade] = total;
      }
    }

    // 結果をリスト形式に変換
    return monthKeys.map((month) {
      final data = monthlyData[month]!;
      final monthInt = int.parse(month.split('-')[1]);
      return {
        'month': month,
        'monthLabel': '$monthInt月',
        'saving': data['saving']!,
        'standard': data['standard']!,
        'reward': data['reward']!,
        'total': data['saving']! + data['standard']! + data['reward']!,
      };
    }).toList();
  }

  /// 月間支出推移を取得（全カテゴリ合計、グレード別積み上げ）
  /// カテゴリ詳細のgetCategoryMonthlyTrendと同じ構成
  Future<List<Map<String, dynamic>>> getMonthlyExpenseTrend({
    int months = 12,
  }) async {
    // SQLで集計データを取得
    final rawData = await _db.getMonthlyGradeBreakdownAll(months: months);

    // 月キーを生成（0埋め用）
    final monthKeys = generateMonthKeys(months);

    // 月別にデータを整理
    final monthlyData = <String, Map<String, int>>{};
    for (final key in monthKeys) {
      monthlyData[key] = {
        'saving': 0,
        'standard': 0,
        'reward': 0,
      };
    }

    // SQLの結果をマージ
    for (final row in rawData) {
      final month = row['month'] as String;
      final grade = row['grade'] as String;
      final total = row['total'] as int;

      if (monthlyData.containsKey(month) && monthlyData[month]!.containsKey(grade)) {
        monthlyData[month]![grade] = total;
      }
    }

    // 結果をリスト形式に変換
    return monthKeys.map((month) {
      final data = monthlyData[month]!;
      final monthInt = int.parse(month.split('-')[1]);
      return {
        'month': month,
        'monthLabel': '$monthInt月',
        'saving': data['saving']!,
        'standard': data['standard']!,
        'reward': data['reward']!,
        'total': data['saving']! + data['standard']! + data['reward']!,
      };
    }).toList();
  }

  Future<void> setBudget(int amount) async {
    final now = DateTime.now();
    final budget = Budget(
      amount: amount,
      year: now.year,
      month: now.month,
    );
    await _db.insertBudget(budget);
    await _reloadBudget();
  }

  // カテゴリ名リストを取得
  List<String> get categoryNames {
    if (_categories.isEmpty) {
      return AppConstants.defaultCategories;
    }
    return _categories.map((c) => c.name).toList();
  }

  // === Entitlement Methods ===

  /// 起動時に entitlement 情報をロード
  /// DevConfig.canShowDevTools が false の場合は何もしない
  Future<void> loadEntitlement() async {
    if (!DevConfig.canShowDevTools) {
      // Release または DEV_TOOLS=false の場合は override を無効化
      _devPremiumOverride = null;
      _devModeUnlocked = false;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // dev mode unlocked
      _devModeUnlocked = prefs.getBool(_keyDevModeUnlocked) ?? false;

      // premium override (null = 未設定)
      if (prefs.containsKey(_keyDevPremiumOverride)) {
        _devPremiumOverride = prefs.getBool(_keyDevPremiumOverride);
      } else {
        _devPremiumOverride = null;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading entitlement: $e');
    }
  }

  /// Premium override を設定（開発用）
  /// DevConfig.canShowDevTools が false の場合は何もしない
  Future<void> setDevPremiumOverride(bool? value) async {
    if (!DevConfig.canShowDevTools) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      if (value == null) {
        await prefs.remove(_keyDevPremiumOverride);
      } else {
        await prefs.setBool(_keyDevPremiumOverride, value);
      }

      _devPremiumOverride = value;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting dev premium override: $e');
    }
  }

  /// Premium override をリセット（null に戻す）
  Future<void> resetDevPremiumOverride() async {
    await setDevPremiumOverride(null);
  }

  /// 開発者モードを解放（バージョン10回タップ用）
  Future<void> unlockDevMode() async {
    if (!DevConfig.canShowDevTools) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDevModeUnlocked, true);
      _devModeUnlocked = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error unlocking dev mode: $e');
    }
  }

  /// 開発者モードをロック（テスト用）
  Future<void> lockDevMode() async {
    if (!DevConfig.canShowDevTools) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDevModeUnlocked, false);
      _devModeUnlocked = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error locking dev mode: $e');
    }
  }

  // === 月別使える金額 Methods ===

  /// YYYY-MM 形式のキーを生成
  String _monthKey(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  /// 指定月の使える金額を取得（null = 未設定）
  int? getMonthlyAvailableAmount(DateTime month) {
    final key = _monthKey(month);
    return _monthlyAvailableAmounts[key];
  }

  /// 今月の使える金額を取得（DB一元管理）
  /// サイクル収入の合計を返す。未設定の場合はnull
  int? get thisMonthAvailableAmount {
    // DBからロードされた収入合計を使用
    if (_currentCycleIncomeTotal != null && _currentCycleIncomeTotal! > 0) {
      return _currentCycleIncomeTotal;
    }
    // フォールバック: 旧SharedPreferencesデータ
    return getMonthlyAvailableAmount(DateTime.now());
  }

  /// 指定月の使える金額を設定（null = 未設定に戻す）
  Future<void> setMonthlyAvailableAmount(DateTime month, int? amount) async {
    final key = _monthKey(month);
    final prefKey = '$_keyMonthlyAmountPrefix$key';

    try {
      final prefs = await SharedPreferences.getInstance();

      if (amount == null) {
        await prefs.remove(prefKey);
        _monthlyAvailableAmounts.remove(key);
      } else {
        await prefs.setInt(prefKey, amount);
        _monthlyAvailableAmounts[key] = amount;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error setting monthly available amount: $e');
    }
  }

  /// 起動時に当月と前月の使える金額をロード
  Future<void> loadMonthlyAvailableAmount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      // 当月
      final currentKey = _monthKey(now);
      final currentPrefKey = '$_keyMonthlyAmountPrefix$currentKey';
      if (prefs.containsKey(currentPrefKey)) {
        _monthlyAvailableAmounts[currentKey] = prefs.getInt(currentPrefKey);
      }

      // 前月
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final prevKey = _monthKey(prevMonth);
      final prevPrefKey = '$_keyMonthlyAmountPrefix$prevKey';
      if (prefs.containsKey(prevPrefKey)) {
        _monthlyAvailableAmounts[prevKey] = prefs.getInt(prevPrefKey);
      }
    } catch (e) {
      debugPrint('Error loading monthly available amount: $e');
    }
  }

  // === FinancialCycle（給料日）Methods ===

  /// 給料日設定を読み込み
  Future<void> loadMainSalaryDay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mainSalaryDay = prefs.getInt(_keyMainSalaryDay) ?? 1;
      _financialCycle = FinancialCycle(mainSalaryDay: _mainSalaryDay);
    } catch (e) {
      debugPrint('Error loading main salary day: $e');
    }
  }

  /// デフォルト支出タイプを読み込み
  Future<void> loadDefaultExpenseGrade() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyDefaultExpenseGrade);
      if (saved != null && ['saving', 'standard', 'reward'].contains(saved)) {
        _defaultExpenseGrade = saved;
      }
    } catch (e) {
      debugPrint('Error loading default expense grade: $e');
    }
  }

  /// デフォルト支出タイプを設定
  Future<void> setDefaultExpenseGrade(String grade) async {
    if (!['saving', 'standard', 'reward'].contains(grade)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDefaultExpenseGrade, grade);
      _defaultExpenseGrade = grade;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting default expense grade: $e');
    }
  }

  /// 通貨表示形式を読み込み
  Future<void> loadCurrencyFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_keyCurrencyFormat);
      if (saved != null && ['prefix', 'suffix'].contains(saved)) {
        _currencyFormat = saved;
      }
    } catch (e) {
      debugPrint('Error loading currency format: $e');
    }
  }

  /// 通貨表示形式を設定
  Future<void> setCurrencyFormat(String format) async {
    if (!['prefix', 'suffix'].contains(format)) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrencyFormat, format);
      _currencyFormat = format;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting currency format: $e');
    }
  }

  /// 給料日を設定（1〜28、29〜31は末日扱いに注意）
  Future<void> setMainSalaryDay(int day) async {
    // 有効範囲: 1〜31
    final clampedDay = day.clamp(1, 31);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyMainSalaryDay, clampedDay);
      _mainSalaryDay = clampedDay;
      _financialCycle = FinancialCycle(mainSalaryDay: clampedDay);

      // 給料日変更時は今日の固定予算を再計算
      await _recalculateTodayAllowance();

      notifyListeners();
    } catch (e) {
      debugPrint('Error setting main salary day: $e');
    }
  }

  /// 今日の固定予算を強制再計算（給料日変更時用）
  Future<void> _recalculateTodayAllowance() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final calculated = _calculateTodayAllowance();
    if (calculated != null) {
      await _db.saveDailyBudget(today, calculated);
      _fixedTodayAllowance = calculated;
    }
  }

  /// サイクル開始日を取得
  DateTime get cycleStartDate => _financialCycle.getStartDate(DateTime.now());

  /// サイクル終了日を取得
  DateTime get cycleEndDate => _financialCycle.getEndDate(DateTime.now());

  /// サイクル開始日から今日までの全日程を生成（降順）
  List<DateTime> get cycleAllDates =>
      _financialCycle.generateDatesFromStartToToday(DateTime.now());

  /// 現在のサイクルキーを取得（例: 'cycle_2025_01_25'）
  String get currentCycleKey => _financialCycle.getCycleKey(DateTime.now());

  // === タブ切り替え & incomeSheet自動起動 Methods ===

  /// タブ切り替えリクエストがあるか
  int? get requestedTabIndex => _requestedTabIndex;

  /// タブ切り替えリクエストを消費（呼び出し後nullに戻る）
  int? consumeRequestedTabIndex() {
    final index = _requestedTabIndex;
    _requestedTabIndex = null;
    return index;
  }

  /// incomeSheet自動起動リクエストがあるか
  bool consumeOpenIncomeSheetRequest() {
    if (!_openIncomeSheetRequested) return false;
    _openIncomeSheetRequested = false;
    return true;
  }

  /// ホームから分析タブへ切り替え + incomeSheet自動起動をリクエスト
  void requestOpenIncomeSheet() {
    _requestedTabIndex = 2; // 分析タブのindex
    _openIncomeSheetRequested = true;
    notifyListeners();
  }

  /// 指定したタブへの切り替えをリクエスト
  void requestTabChange(int tabIndex) {
    _requestedTabIndex = tabIndex;
    notifyListeners();
  }

  // === 固定費 CRUD Methods ===

  /// 固定費を追加
  Future<bool> addFixedCost(FixedCost fixedCost) async {
    try {
      await _db.insertFixedCost(fixedCost);
      await _reloadFixedCosts();
      return true;
    } catch (e) {
      debugPrint('Error adding fixed cost: $e');
      return false;
    }
  }

  /// 固定費を更新
  Future<bool> updateFixedCost(FixedCost fixedCost) async {
    try {
      await _db.updateFixedCost(fixedCost);
      await _reloadFixedCosts();
      return true;
    } catch (e) {
      debugPrint('Error updating fixed cost: $e');
      return false;
    }
  }

  /// 固定費を削除
  Future<bool> removeFixedCost(int id) async {
    try {
      await _db.deleteFixedCost(id);
      await _reloadFixedCosts();
      return true;
    } catch (e) {
      debugPrint('Error removing fixed cost: $e');
      return false;
    }
  }

  // === 固定費カテゴリ CRUD Methods ===

  /// 固定費カテゴリを追加
  Future<void> addFixedCostCategory(String name) async {
    final sortOrder = _fixedCostCategories.length;
    final category = FixedCostCategory(
      name: name,
      isDefault: false,
      sortOrder: sortOrder,
    );
    await _db.insertFixedCostCategory(category);
    await _reloadFixedCostCategories();
  }

  /// 固定費カテゴリ名を更新
  Future<void> renameFixedCostCategory(int id, String newName) async {
    final category = _fixedCostCategories.firstWhere((c) => c.id == id);
    final updated = category.copyWith(name: newName);
    await _db.updateFixedCostCategory(updated);
    await _reloadFixedCostCategories();
  }

  /// 固定費カテゴリを削除（参照されている場合は削除不可）
  /// 戻り値: 削除成功=true, 参照あり=false
  Future<bool> deleteFixedCostCategory(int id) async {
    final isInUse = await _db.isFixedCostCategoryInUse(id);
    if (isInUse) {
      return false;
    }
    await _db.deleteFixedCostCategory(id);
    await _reloadFixedCostCategories();
    return true;
  }

  /// カテゴリIDから名前を取得
  String? getFixedCostCategoryName(int? categoryId) {
    if (categoryId == null) return null;
    final category = _fixedCostCategories.where((c) => c.id == categoryId);
    return category.isNotEmpty ? category.first.name : null;
  }

  // === 家計の余白（Budget Margin）計算 Methods ===

  /// ペースバッファ（余裕額）を計算
  /// = (月間変動費予算 * (経過日数 / 月の日数)) - 現在の累積支出額
  /// 可処分金額が未設定の場合は null を返す
  int? get paceBuffer {
    final disposable = disposableAmount;
    if (disposable == null) return null;

    final now = DateTime.now();
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final elapsedDays = now.day;

    // 経過日数に応じた予算ペース
    final expectedBudget = (disposable * elapsedDays / daysInMonth).round();
    // 余裕額 = 予算ペース - 実際の支出
    return expectedBudget - thisMonthTotal;
  }

  /// 直近6ヶ月の支出を取得（メモ化）
  List<Expense> get _last6MonthsExpenses {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // キャッシュが有効かチェック（同一月 & 同一件数）
    if (_cachedLast6MonthsExpenses != null &&
        _cachedLast6MonthsKey == monthKey &&
        _cachedLast6MonthsExpenses!.length <= _expenses.length) {
      // 件数が増えていなければキャッシュを返す
      // 注: 厳密な検証ではないが、パフォーマンス優先
      return _cachedLast6MonthsExpenses!;
    }

    final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);
    final result = _expenses.where((e) => e.createdAt.isAfter(sixMonthsAgo)).toList();

    // キャッシュを更新
    _cachedLast6MonthsExpenses = result;
    _cachedLast6MonthsKey = monthKey;

    return result;
  }

  /// カテゴリ別・グレード別の平均単価を計算（直近6ヶ月、メモ化）
  /// 返り値: { 'カテゴリ名': { 'standard': {'avg': int, 'count': int}, 'reward': {...} } }
  Map<String, Map<String, Map<String, int>>> get _categoryGradeAverages {
    final now = DateTime.now();
    final cacheKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${_expenses.length}';

    // キャッシュが有効かチェック
    if (_cachedCategoryGradeAverages != null &&
        _cachedCategoryGradeAveragesKey == cacheKey) {
      return _cachedCategoryGradeAverages!;
    }

    final result = <String, Map<String, Map<String, int>>>{};
    final recentExpenses = _last6MonthsExpenses;

    for (final expense in recentExpenses) {
      if (expense.category == 'その他') continue;
      final grade = expense.grade;
      if (grade != 'standard' && grade != 'reward') continue;

      result.putIfAbsent(expense.category, () => {
        'standard': {'total': 0, 'count': 0},
        'reward': {'total': 0, 'count': 0},
      });

      result[expense.category]![grade]!['total'] =
          result[expense.category]![grade]!['total']! + expense.amount;
      result[expense.category]![grade]!['count'] =
          result[expense.category]![grade]!['count']! + 1;
    }

    // total/count を avg に変換
    final averages = <String, Map<String, Map<String, int>>>{};
    for (final entry in result.entries) {
      averages[entry.key] = {};
      for (final gradeEntry in entry.value.entries) {
        final total = gradeEntry.value['total']!;
        final count = gradeEntry.value['count']!;
        averages[entry.key]![gradeEntry.key] = {
          'avg': count > 0 ? (total / count).round() : 0,
          'count': count,
        };
      }
    }

    // キャッシュを更新
    _cachedCategoryGradeAverages = averages;
    _cachedCategoryGradeAveragesKey = cacheKey;

    return averages;
  }

  /// 全期間の「ご褒美」回数をカテゴリ別に集計
  Map<String, int> get _rewardCountsByCategory {
    final counts = <String, int>{};
    for (final expense in _expenses) {
      if (expense.category == 'その他') continue;
      if (expense.grade != 'reward') continue;
      counts[expense.category] = (counts[expense.category] ?? 0) + 1;
    }
    return counts;
  }

  /// 格上げ可能カテゴリのデータを取得
  /// 返り値: List<{ 'category': String, 'diff': int, 'possibleCount': int, 'standardAvg': int, 'rewardAvg': int }>
  /// 条件: 「標準」「ご褒美」各1件以上、全期間ご褒美回数上位2カテゴリ
  List<Map<String, dynamic>> getUpgradeCategories() {
    final buffer = paceBuffer;
    if (buffer == null || buffer <= 0) return [];

    final averages = _categoryGradeAverages;
    final rewardCounts = _rewardCountsByCategory;

    // 条件を満たすカテゴリを抽出（各グレード1件以上）
    final eligibleCategories = <String>[];
    for (final entry in averages.entries) {
      final standardCount = entry.value['standard']?['count'] ?? 0;
      final rewardCount = entry.value['reward']?['count'] ?? 0;
      if (standardCount >= 1 && rewardCount >= 1) {
        eligibleCategories.add(entry.key);
      }
    }

    if (eligibleCategories.isEmpty) return [];

    // ご褒美回数でソートして上位3つを取得
    eligibleCategories.sort((a, b) {
      final countA = rewardCounts[a] ?? 0;
      final countB = rewardCounts[b] ?? 0;
      return countB.compareTo(countA);
    });

    final topCategories = eligibleCategories.take(3).toList();

    // 各カテゴリの格上げコストと回数を計算
    final result = <Map<String, dynamic>>[];
    for (final category in topCategories) {
      final standardAvg = averages[category]!['standard']!['avg']!;
      final rewardAvg = averages[category]!['reward']!['avg']!;
      final diff = rewardAvg - standardAvg;

      // diff が 0 以下の場合はスキップ（格上げコストなし）
      if (diff <= 0) continue;

      final possibleCount = (buffer / diff).floor();
      // 0回の場合は表示しない
      if (possibleCount <= 0) continue;

      result.add({
        'category': category,
        'diff': diff,
        'possibleCount': possibleCount,
        'standardAvg': standardAvg,
        'rewardAvg': rewardAvg,
      });
    }

    return result;
  }

  /// スマート・コンボ予測を取得
  /// カテゴリ別に頻出の「金額×支出タイプ」組み合わせを最大3つ返す
  /// 返り値: List<{ 'amount': int, 'grade': String, 'freq': int, 'lastUsed': String }>
  Future<List<Map<String, dynamic>>> getSmartCombos(String categoryName) async {
    return await _db.getSmartCombos(categoryName: categoryName, limit: 3);
  }

  // === QuickEntry CRUD ===

  /// クイック登録を追加
  Future<bool> addQuickEntry(QuickEntry entry) async {
    try {
      // 新規追加時は末尾に追加（sortOrder = 現在の件数）
      final newEntry = entry.copyWith(sortOrder: _quickEntries.length);
      await _db.insertQuickEntry(newEntry);
      await _reloadQuickEntries();
      return true;
    } catch (e) {
      debugPrint('Error adding quick entry: $e');
      return false;
    }
  }

  /// クイック登録を更新
  Future<bool> updateQuickEntry(QuickEntry entry) async {
    try {
      await _db.updateQuickEntry(entry);
      await _reloadQuickEntries();
      return true;
    } catch (e) {
      debugPrint('Error updating quick entry: $e');
      return false;
    }
  }

  /// クイック登録を削除
  Future<bool> deleteQuickEntry(int id) async {
    try {
      await _db.deleteQuickEntry(id);
      await _reloadQuickEntries();
      return true;
    } catch (e) {
      debugPrint('Error deleting quick entry: $e');
      return false;
    }
  }

  /// クイック登録から支出を即座に登録
  /// QuickEntryの内容でExpenseを作成し、DBに保存
  Future<bool> executeQuickEntry(QuickEntry entry) async {
    final expense = Expense(
      amount: entry.amount,
      category: entry.category,
      grade: entry.grade,
      memo: entry.memo,
      createdAt: DateTime.now(),
    );
    return await addExpense(expense);
  }

  // ========================================
  // サイクル収入管理（DB一元管理）
  // ========================================

  /// 現在サイクルの収入合計をDBからロード
  Future<void> _loadCurrentCycleIncome() async {
    try {
      final cycleKey = currentCycleKey;

      // SP→DB移行: DBにデータがなく、SPにデータがある場合は移行
      final hasDbIncome = await _db.hasMainIncome(cycleKey);
      if (!hasDbIncome) {
        await _migrateSpToDb();
      }

      _currentCycleIncomeTotal = await _db.getCycleIncomeTotal(cycleKey);
    } catch (e) {
      debugPrint('Error loading cycle income: $e');
      _currentCycleIncomeTotal = null;
    }
  }

  /// SharedPreferences → DB 移行
  /// 現在月のmonthly_amountがあればDBに移行
  Future<void> _migrateSpToDb() async {
    try {
      final now = DateTime.now();
      final spAmount = getMonthlyAvailableAmount(now);

      if (spAmount != null && spAmount > 0) {
        // DBにメイン収入として登録
        await _db.insertCycleIncome(
          cycleKey: currentCycleKey,
          isMain: true,
          name: '給料',
          amount: spAmount,
        );
        debugPrint('Migrated SP monthly_amount to DB: $spAmount');
      }
    } catch (e) {
      debugPrint('Error migrating SP to DB: $e');
    }
  }

  /// 収入をリロード（追加・更新・削除後に呼び出し）
  Future<void> _reloadCycleIncome() async {
    await _loadCurrentCycleIncome();
    // 収入変更時は今日の固定予算も再計算
    await _recalculateTodayAllowance();
    notifyListeners();
  }

  /// 現在サイクルの全収入データを取得
  Future<List<Map<String, dynamic>>> getCurrentCycleIncomes() async {
    return await _db.getCycleIncomes(currentCycleKey);
  }

  /// 現在サイクルのメイン収入を取得
  Future<Map<String, dynamic>?> getMainIncome() async {
    return await _db.getMainIncome(currentCycleKey);
  }

  /// 現在サイクルのサブ収入一覧を取得
  Future<List<Map<String, dynamic>>> getSubIncomes() async {
    return await _db.getSubIncomes(currentCycleKey);
  }

  /// メイン収入を登録（1サイクルに1件のみ）
  /// 既にメイン収入がある場合は更新
  Future<bool> setMainIncome(int amount, {String name = '給料'}) async {
    try {
      final cycleKey = currentCycleKey;
      final existing = await _db.getMainIncome(cycleKey);

      if (existing != null) {
        // 既存のメイン収入を更新
        await _db.updateCycleIncome(
          id: existing['id'] as int,
          name: name,
          amount: amount,
        );
      } else {
        // 新規登録
        await _db.insertCycleIncome(
          cycleKey: cycleKey,
          isMain: true,
          name: name,
          amount: amount,
        );
      }

      await _reloadCycleIncome();
      return true;
    } catch (e) {
      debugPrint('Error setting main income: $e');
      return false;
    }
  }

  /// サブ収入を追加（補填・ボーナス等）
  Future<bool> addSubIncome(int amount, String name) async {
    try {
      await _db.insertCycleIncome(
        cycleKey: currentCycleKey,
        isMain: false,
        name: name,
        amount: amount,
      );

      await _reloadCycleIncome();
      return true;
    } catch (e) {
      debugPrint('Error adding sub income: $e');
      return false;
    }
  }

  /// 収入を更新
  Future<bool> updateIncome(int id, int amount, String name) async {
    try {
      await _db.updateCycleIncome(id: id, name: name, amount: amount);
      await _reloadCycleIncome();
      return true;
    } catch (e) {
      debugPrint('Error updating income: $e');
      return false;
    }
  }

  /// 収入を削除
  Future<bool> deleteIncome(int id) async {
    try {
      await _db.deleteCycleIncome(id);
      await _reloadCycleIncome();
      return true;
    } catch (e) {
      debugPrint('Error deleting income: $e');
      return false;
    }
  }

  /// 現在サイクルにメイン収入が設定されているか
  Future<bool> hasMainIncome() async {
    return await _db.hasMainIncome(currentCycleKey);
  }

  // ========================================
  // 前サイクル比較用データ取得
  // ========================================

  /// 前サイクルのキーを取得
  String get previousCycleKey => _financialCycle.getPreviousCycleKey(DateTime.now());

  /// 前サイクルの開始日を取得
  DateTime get previousCycleStartDate =>
      _financialCycle.getPreviousCycleStartDate(DateTime.now());

  /// 前サイクルの終了日を取得
  DateTime get previousCycleEndDate =>
      _financialCycle.getPreviousCycleEndDate(DateTime.now());

  /// 前サイクルの総日数を取得
  int get previousCycleTotalDays =>
      _financialCycle.getPreviousCycleTotalDays(DateTime.now());

  /// 前サイクルの収入合計を取得
  Future<int> getPreviousCycleIncomeTotal() async {
    return await _db.getCycleIncomeTotal(previousCycleKey);
  }

  /// 前サイクルの日ごとの支出を取得
  /// 返り値: Map<日オフセット(0-indexed), 支出額>
  Future<Map<int, int>> getPreviousCycleDailyExpenses() async {
    return await _db.getDailyExpensesByCycle(
      cycleStartDate: previousCycleStartDate,
      cycleEndDate: previousCycleEndDate,
    );
  }

  /// 前サイクルの支出合計を取得
  Future<int> getPreviousCycleTotalExpenses() async {
    return await _db.getTotalExpensesByCycle(
      cycleStartDate: previousCycleStartDate,
      cycleEndDate: previousCycleEndDate,
    );
  }

  /// 前サイクルの累積支出率を計算
  /// 返り値: { 'rates': List<double>, 'startDay': int, 'totalDays': int, 'income': int }
  /// ratesは日ごとの累積支出率（%）
  Future<Map<String, dynamic>?> getPreviousCycleBurnRateData() async {
    try {
      final prevIncome = await getPreviousCycleIncomeTotal();
      if (prevIncome <= 0) return null;

      // 前サイクルの可処分金額 = 収入 - 固定費
      // 注: 固定費は現在のものを使用（過去の固定費データは保存していない）
      final prevDisposable = prevIncome - fixedCostsTotal;
      if (prevDisposable <= 0) return null;

      final dailyExpenses = await getPreviousCycleDailyExpenses();
      final totalDays = previousCycleTotalDays;

      // 累積支出率を計算
      final rates = <double>[];
      int cumulative = 0;

      // 記録開始日を検出
      int startDay = 1;
      bool recordStarted = false;

      for (var i = 0; i < totalDays; i++) {
        cumulative += dailyExpenses[i] ?? 0;

        // 最初の支出を検出
        if (!recordStarted && (dailyExpenses[i] ?? 0) > 0) {
          startDay = i + 1;
          recordStarted = true;
        }

        final rate = (cumulative / prevDisposable) * 100;
        rates.add(rate);
      }

      // 記録日数が3日未満の場合は比較に不十分
      final recordedDays = dailyExpenses.keys.length;
      if (recordedDays < 3) return null;

      return {
        'rates': rates,
        'startDay': startDay,
        'totalDays': totalDays,
        'income': prevIncome,
        'disposable': prevDisposable,
        'totalExpenses': cumulative,
      };
    } catch (e) {
      debugPrint('Error getting previous cycle burn rate data: $e');
      return null;
    }
  }

  /// 今サイクルと前サイクルの同時点での差額を計算
  /// 返り値: 正の値 = 今サイクルの方が支出が少ない（節約中）
  ///         負の値 = 今サイクルの方が支出が多い（使いすぎ）
  Future<int?> getCycleComparisonDiff() async {
    try {
      final prevData = await getPreviousCycleBurnRateData();
      if (prevData == null) return null;

      final prevRates = prevData['rates'] as List<double>;
      final prevTotalDays = prevData['totalDays'] as int;
      final prevDisposable = prevData['disposable'] as int;

      final now = DateTime.now();
      final currentTodayInCycle = _financialCycle.getDaysElapsed(now);
      final currentTotalDays = _financialCycle.getTotalDays(now);

      // 進捗率を合わせるための補間
      // 今サイクルの進捗率 = currentTodayInCycle / currentTotalDays
      // 前サイクルの対応する日 = 進捗率 * prevTotalDays
      final progress = currentTodayInCycle / currentTotalDays;
      final prevEquivalentDay = (progress * prevTotalDays).round().clamp(1, prevTotalDays);

      // 前サイクルの同時点での累積支出率
      final prevRateAtSameProgress = prevRates[prevEquivalentDay - 1];

      // 今サイクルの可処分金額を確認
      final currentDisposable = disposableAmount;
      if (currentDisposable == null || currentDisposable <= 0) return null;

      // 差額を金額に変換
      // 前サイクル基準の支出額
      final prevExpenseAtProgress = prevDisposable * (prevRateAtSameProgress / 100);
      // 今サイクルの実際の支出額
      final currentExpense = thisMonthTotal;

      // 差額（正 = 節約、負 = 使いすぎ）
      return (prevExpenseAtProgress - currentExpense).round();
    } catch (e) {
      debugPrint('Error calculating cycle comparison diff: $e');
      return null;
    }
  }
}
