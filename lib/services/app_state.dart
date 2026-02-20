import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
import '../models/quick_entry.dart';
import '../models/scheduled_expense.dart';
import '../models/category_budget.dart';
import '../config/theme.dart';
import '../config/constants.dart';
import '../core/dev_config.dart';
import '../core/financial_cycle.dart';
import 'database_service.dart';
import 'performance_monitor.dart';
import 'purchase_service.dart';

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
  List<ScheduledExpense> _scheduledExpenses = [];
  List<CategoryBudget> _categoryBudgets = [];
  Budget? _currentBudget;
  bool _isLoading = true;

  // === Premium / Entitlement ===
  bool? _devPremiumOverride; // null=override無し, true/false=強制
  bool _devModeUnlocked = false; // バージョン10回タップで解放
  bool _lastPremiumStatus = false;

  static const String _keyDevPremiumOverride = 'dev_premium_override';
  static const String _keyDevModeUnlocked = 'dev_mode_unlocked';
  static const String _keyPlusAutoRecordPrefix = 'plus_auto_record_';

  static const int _plusMonthlyAmount = 300;
  static const int _plusYearlyAmount = 3000;
  static const String _plusMonthlyLabel = 'Plus月額';
  static const String _plusYearlyLabel = 'Plus年額';

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

  // === テーマ設定 ===
  bool _isDark = false;
  ColorPattern _colorPattern = ColorPattern.pink;
  static const String _keyIsDark = 'theme_is_dark';
  static const String _keyColorPattern = 'theme_color_pattern';

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

  // === categoryStatsキャッシュ（SQLベース） ===
  Map<String, CategoryStats>? _cachedCategoryStats;
  String? _cachedCategoryStatsCycleKey;

  AppState() {
    _lastPremiumStatus = isPremium;
    PurchaseService.instance.onPurchaseConfirmed = _handlePlusPurchaseConfirmed;
    PurchaseService.instance.onPurchaseUpdated = _handlePurchaseUpdated;
  }

  // Getters
  List<Expense> get expenses => _expenses;
  List<Category> get categories => _categories;
  List<FixedCost> get fixedCosts => _fixedCosts;
  List<FixedCostCategory> get fixedCostCategories => _fixedCostCategories;
  List<QuickEntry> get quickEntries => _quickEntries;
  List<ScheduledExpense> get scheduledExpenses => _scheduledExpenses;
  List<CategoryBudget> get categoryBudgets => _categoryBudgets;
  Budget? get currentBudget => _currentBudget;
  bool get isLoading => _isLoading;

  // === テーマ ===
  bool get isDark => _isDark;
  ColorPattern get colorPattern => _colorPattern;
  ThemeData get currentTheme =>
      AppTheme.build(isDark: _isDark, pattern: _colorPattern);

  /// プレミアム判定（全画面でこれを参照する）
  /// PREMIUM_TEST=true の場合は常に true を返す
  bool get isPremium =>
      DevConfig.premiumTestEnabled ||
      (_devPremiumOverride ?? PurchaseService.instance.isPremium);

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

    // 現在サイクル内の未確定予定支出合計
    final scheduledTotal = _scheduledExpensesTotalInCurrentCycle;

    // 現在の残り予算 = 予算 - 今日までの支出 - 固定費 - 予定支出
    final remainingBudget = income - variableExpenseTotal - fixedCostsTotal - scheduledTotal;

    // 明日からサイクル終了日までの日数
    final remainingDaysFromTomorrow = _financialCycle.getDaysRemaining(now) - 1;

    if (remainingDaysFromTomorrow <= 0) return null;

    return (remainingBudget / remainingDaysFromTomorrow).round();
  }

  /// 過去N日分の「今日使えるお金」履歴を取得（Sparkline用）
  /// 返り値: List<Map<String, dynamic>> [{ 'date': DateTime, 'amount': int }, ...]
  Future<List<Map<String, dynamic>>> getDailyAllowanceHistory(int days) async {
    final now = DateTime.now();
    final baseDate = DateTime(now.year, now.month, now.day);
    final result = <Map<String, dynamic>>[];

    for (int i = 0; i < days; i++) {
      final targetDate = baseDate.subtract(Duration(days: days - 1 - i));
      final savedAmount = await _db.getDailyBudget(targetDate);
      final amount = savedAmount ?? await _calculateAllowanceForDate(targetDate);
      if (amount != null) {
        result.add({
          'date': targetDate,
          'amount': amount,
        });
      }
    }

    return result;
  }

  /// 指定日の「今日使えるお金」を計算（履歴補完用）
  Future<int?> _calculateAllowanceForDate(DateTime date) async {
    final income = thisMonthAvailableAmount;
    if (income == null) return null;

    final cycleStart = _financialCycle.getStartDate(date);
    final expensesUntilDate = await _db.getExpenseTotalUntilDate(
      cycleStartDate: cycleStart,
      endDateExclusive: date,
    );

    // 現在サイクル内の未確定予定支出合計（同期計算）
    final scheduledTotal = _scheduledExpensesTotalInCurrentCycle;

    final remainingBudget = income - expensesUntilDate - fixedCostsTotal - scheduledTotal;
    final remainingDays = _financialCycle.getDaysRemaining(date);
    if (remainingDays <= 0) return null;

    return (remainingBudget / remainingDays).round();
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

  /// 週間バジェット情報を取得（Premium機能）
  /// 返り値: { 'amount': int?, 'daysRemaining': int, 'endDate': DateTime, 'isWeekMode': bool, 'isOverBudget': bool }
  Map<String, dynamic> get weeklyBudgetInfo {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cycleEnd = cycleEndDate;
    final remainingDays = remainingDaysInMonth;

    // 今週の日曜日を計算（今日が日曜なら今日、それ以外は次の日曜）
    final daysUntilSunday = DateTime.sunday - today.weekday;
    final nextSunday = daysUntilSunday <= 0
        ? today.add(Duration(days: daysUntilSunday + 7))
        : today.add(Duration(days: daysUntilSunday));

    // 対象終了日: 「今週日曜」と「サイクル終了日」の早い方
    final targetEndDate = nextSunday.isBefore(cycleEnd) ? nextSunday : cycleEnd;
    final isWeekMode = nextSunday.isBefore(cycleEnd) || nextSunday.isAtSameMomentAs(cycleEnd);

    // 今日から対象終了日までの日数（今日を含む）
    final daysToTarget = targetEndDate.difference(today).inDays + 1;

    // 日割り額の計算（dynamicTomorrowForecast と同様のロジック）
    final income = thisMonthAvailableAmount;
    if (income == null) {
      return {
        'amount': null,
        'daysRemaining': daysToTarget,
        'endDate': targetEndDate,
        'isWeekMode': isWeekMode,
        'isOverBudget': false,
      };
    }

    // 今日までの支出合計
    final variableExpenseTotal = thisMonthTotal;

    // 現在サイクル内の未確定予定支出合計
    final scheduledTotal = _scheduledExpensesTotalInCurrentCycle;

    // 現在の残り予算 = 予算 - 今日までの支出 - 固定費 - 予定支出
    final remainingBudget = income - variableExpenseTotal - fixedCostsTotal - scheduledTotal;

    // 予算オーバー判定
    if (remainingBudget <= 0) {
      return {
        'amount': null,
        'daysRemaining': daysToTarget,
        'endDate': targetEndDate,
        'isWeekMode': isWeekMode,
        'isOverBudget': true,
      };
    }

    // 日割り額 × 対象日数
    final dailyAllowance = remainingBudget / remainingDays;
    final weeklyAmount = (dailyAllowance * daysToTarget).round();

    return {
      'amount': weeklyAmount,
      'daysRemaining': daysToTarget,
      'endDate': targetEndDate,
      'isWeekMode': isWeekMode,
      'isOverBudget': false,
    };
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

    // 現在サイクル内の未確定予定支出合計（同期計算）
    final scheduledTotal = _scheduledExpensesTotalInCurrentCycle;

    // 残り予算 = 予算 - 昨日までの支出 - 固定費 - 予定支出
    final remainingBudget = income - expensesUntilYesterday - fixedCostsTotal - scheduledTotal;

    // 今日を含む残り日数
    final remainingDays = remainingDaysInMonth;

    return (remainingBudget / remainingDays).round();
  }

  /// 現在サイクル内の未確定予定支出の合計（同期計算、キャッシュ使用）
  int get _scheduledExpensesTotalInCurrentCycle {
    final now = DateTime.now();
    final cycleStart = _financialCycle.getStartDate(now);
    final cycleEnd = _financialCycle.getEndDate(now);

    return _scheduledExpenses
        .where((se) =>
            !se.confirmed &&
            !se.scheduledDate.isBefore(cycleStart) &&
            !se.scheduledDate.isAfter(cycleEnd))
        .fold(0, (sum, se) => sum + se.amount);
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

  /// カテゴリ別統計（キャッシュ版）
  /// 初回アクセス時やキャッシュ無効時は空を返す（非同期でリフレッシュ）
  Map<String, CategoryStats> get categoryStats {
    final currentCycleKey = _financialCycle.getCycleKey(DateTime.now());

    // キャッシュが有効ならそのまま返す
    if (_cachedCategoryStats != null &&
        _cachedCategoryStatsCycleKey == currentCycleKey) {
      return _cachedCategoryStats!;
    }

    // キャッシュが無効な場合は非同期でリフレッシュをトリガー
    // （UIには空または古いキャッシュを返して、後でnotifyListenersで更新）
    _refreshCategoryStats();
    return _cachedCategoryStats ?? {};
  }

  /// カテゴリ統計をSQLから非同期でリフレッシュ
  Future<void> _refreshCategoryStats() async {
    final now = DateTime.now();
    final currentCycleKey = _financialCycle.getCycleKey(now);

    // 既にリフレッシュ中または最新なら何もしない
    if (_cachedCategoryStatsCycleKey == currentCycleKey &&
        _cachedCategoryStats != null) {
      return;
    }

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
      final standardTotal =
          (savingCount > 0 ? (savingAmount / 0.7).round() : 0) +
              standardAmount +
              (rewardCount > 0 ? (rewardAmount / 1.3).round() : 0);
      final standardAverage =
          expenseCount > 0 ? (standardTotal / expenseCount).round() : 0;

      stats[category] = CategoryStats(
        category: category,
        totalAmount: totalAmount,
        standardAverage: standardAverage,
        expenseCount: expenseCount,
      );
    }

    _cachedCategoryStats = stats;
    _cachedCategoryStatsCycleKey = currentCycleKey;
    notifyListeners();
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
        _db.getUnconfirmedScheduledExpenses(),
        _db.getCategoryBudgets(),
      ]);
      perfMonitor.stopTimer('AppState.loadData.queries');

      _expenses = results[0] as List<Expense>;
      _categories = results[1] as List<Category>;
      _fixedCosts = results[2] as List<FixedCost>;
      _fixedCostCategories = results[3] as List<FixedCostCategory>;
      _currentBudget = results[4] as Budget?;
      _quickEntries = results[5] as List<QuickEntry>;
      _scheduledExpenses = results[6] as List<ScheduledExpense>;
      _categoryBudgets = results[7] as List<CategoryBudget>;

      // サイクル収入をロード（FinancialCycleロード後に実行）
      await _loadCurrentCycleIncome();

      // 今日の固定予算をロード（データロード後に実行）
      await _loadOrCreateTodayAllowance();

      // カテゴリ統計をプリロード（SQLベース、非同期）
      await _refreshCategoryStats();

      // Premiumが無効の場合はクイック登録の上限を適用
      await _enforceQuickEntryLimitIfNeeded(notify: false);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
    perfMonitor.stopTimer('AppState.loadData');
  }

  // === 部分リロードメソッド（パフォーマンス最適化） ===

  Future<void> _reloadExpenses({bool notify = true}) async {
    _expenses = await _db.getExpenses();
    _invalidateExpensesCaches();
    if (notify) notifyListeners();
  }

  /// 支出関連のキャッシュを無効化
  void _invalidateExpensesCaches() {
    _cachedThisMonthExpenses = null;
    _cachedThisMonthExpensesCycleKey = null;
    _cachedThisMonthExpensesCount = null;
    // 今日の支出キャッシュもクリア
    _cachedTodayExpenses = null;
    _cachedTodayExpensesDate = null;
    _cachedTodayTotal = null;
    _cachedTodayTotalDate = null;
    // カテゴリ統計キャッシュもクリア
    _cachedCategoryStats = null;
    _cachedCategoryStatsCycleKey = null;
  }

  Future<void> _reloadCategories({bool notify = true}) async {
    _categories = await _db.getCategories();
    if (notify) notifyListeners();
  }

  Future<void> _reloadFixedCosts({bool notify = true}) async {
    _fixedCosts = await _db.getFixedCosts();
    if (notify) notifyListeners();
  }

  Future<void> _reloadFixedCostCategories({bool notify = true}) async {
    _fixedCostCategories = await _db.getFixedCostCategories();
    if (notify) notifyListeners();
  }

  Future<void> _reloadBudget({bool notify = true}) async {
    _currentBudget = await _db.getCurrentBudget();
    if (notify) notifyListeners();
  }

  Future<void> _reloadQuickEntries({bool notify = true}) async {
    _quickEntries = await _db.getQuickEntries();
    if (notify) notifyListeners();
  }

  Future<void> _reloadScheduledExpenses({bool notify = true}) async {
    _scheduledExpenses = await _db.getUnconfirmedScheduledExpenses();
    if (notify) notifyListeners();
  }

  Future<void> _reloadCategoryBudgets({bool notify = true}) async {
    _categoryBudgets = await _db.getCategoryBudgets();
    if (notify) notifyListeners();
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

  Future<void> _handlePlusPurchaseConfirmed(
    PurchaseConfirmation confirmation,
  ) async {
    final signature = confirmation.signature.isNotEmpty
        ? confirmation.signature
        : 'unknown';
    final recordKey = '$_keyPlusAutoRecordPrefix${confirmation.productId}';

    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(recordKey) == signature) {
        return;
      }

      if (_categories.isEmpty) {
        await _reloadCategories(notify: false);
      }

      final createdAt = confirmation.purchasedAt ?? DateTime.now();

      if (confirmation.subscriptionType == 'monthly') {
        final fixedCost = FixedCost(
          categoryId: null,
          categoryNameSnapshot: _plusMonthlyLabel,
          amount: _plusMonthlyAmount,
          memo: _plusMonthlyLabel,
          createdAt: createdAt,
        );
        await addFixedCost(fixedCost);
      } else if (confirmation.subscriptionType == 'yearly') {
        final category = _resolvePlusExpenseCategory();
        if (category == null || category.id == null) {
          debugPrint('Plus auto record: category not found');
          return;
        }

        final expense = Expense(
          amount: _plusYearlyAmount,
          categoryId: category.id!,
          category: category.name,
          grade: 'standard',
          memo: _plusYearlyLabel,
          createdAt: createdAt,
        );
        await addExpense(expense);
      }

      await prefs.setString(recordKey, signature);
    } catch (e) {
      debugPrint('Plus auto record error: $e');
    }
  }

  Category? _resolvePlusExpenseCategory() {
    if (_categories.isEmpty) return null;
    return _categories.firstWhere(
      (category) => category.name == 'その他',
      orElse: () => _categories.first,
    );
  }

  void _handlePurchaseUpdated() async {
    final isNowPremium = isPremium;
    if (_lastPremiumStatus && !isNowPremium) {
      await _enforceQuickEntryLimitIfNeeded();
    }
    _lastPremiumStatus = isNowPremium;
    notifyListeners();
  }

  Future<void> _enforceQuickEntryLimitIfNeeded({bool notify = true}) async {
    if (isPremium) return;
    const freeLimit = 2;
    if (_quickEntries.length <= freeLimit) return;

    final toDelete = _quickEntries.skip(freeLimit).where((e) => e.id != null).toList();
    if (toDelete.isEmpty) return;

    for (final entry in toDelete) {
      await _db.deleteQuickEntry(entry.id!);
    }
    await _reloadQuickEntries(notify: false);

    if (notify) {
      notifyListeners();
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
        categoryId: breakdown['categoryId'] as int,
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

  Future<bool> splitExpense(int id, int splitAmount, int newCategoryId, String newCategoryName, {String? grade}) async {
    try {
      final original = _expenses.firstWhere((e) => e.id == id);
      final remainingAmount = original.amount - splitAmount;

      // 元の支出を更新
      final updatedOriginal = original.copyWith(amount: remainingAmount);
      await _db.updateExpense(updatedOriginal);

      // 新しい支出を作成（gradeが指定されていればそれを使用、なければ元のgrade）
      final newExpense = Expense(
        amount: splitAmount,
        categoryId: newCategoryId,
        category: newCategoryName,
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

  Future<bool> addCategory(String name, {String? icon}) async {
    try {
      final sortOrder = _categories.length;
      final category = Category(
        name: name,
        sortOrder: sortOrder,
        isDefault: false,
        icon: icon,
      );
      await _db.insertCategory(category);
      await _reloadCategories();
      return true;
    } catch (e) {
      debugPrint('Error adding category: $e');
      return false;
    }
  }

  // カテゴリ名とアイコンを更新（関連する全テーブルも連動更新）
  Future<bool> updateCategoryNameAndIcon(int id, String newName, {String? icon}) async {
    try {
      await _db.updateCategoryName(id, newName);
      // アイコンも更新する場合
      if (icon != null) {
        final category = _categories.firstWhere((c) => c.id == id);
        category.icon = icon;
        await _db.updateCategory(category);
      }
      // 全関連データをリロード（notifyはバッチ化して最後に1回だけ）
      await _reloadCategories(notify: false);
      await _reloadExpenses(notify: false);
      await _reloadQuickEntries(notify: false);
      await _reloadScheduledExpenses(notify: false);
      await _reloadCategoryBudgets(notify: false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating category: $e');
      return false;
    }
  }

  // カテゴリを削除（関連する全テーブルのデータも連動削除）
  Future<bool> deleteCategory(int id) async {
    try {
      // DBトランザクションで全関連データを一括削除
      await _db.deleteCategoryWithExpenses(id);
      // 全関連データをリロード（notifyはバッチ化して最後に1回だけ）
      await _reloadCategories(notify: false);
      await _reloadExpenses(notify: false);
      await _reloadQuickEntries(notify: false);
      await _reloadScheduledExpenses(notify: false);
      await _reloadCategoryBudgets(notify: false);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
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

    // 今サイクルの期間
    final cycleStart = cycleStartDate;
    final cycleEnd = cycleEndDate;

    // 今サイクルのデータ
    final thisCycleData = <String, Map<String, int>>{
      'saving': {'amount': 0, 'count': 0},
      'standard': {'amount': 0, 'count': 0},
      'reward': {'amount': 0, 'count': 0},
    };

    final thisCycleExpenses = _expenses.where((e) {
      final expenseDate = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final startDate = DateTime(cycleStart.year, cycleStart.month, cycleStart.day);
      final endDate = DateTime(cycleEnd.year, cycleEnd.month, cycleEnd.day);
      return e.category == categoryName &&
          !expenseDate.isBefore(startDate) &&
          !expenseDate.isAfter(endDate);
    });

    for (final expense in thisCycleExpenses) {
      final grade = expense.grade;
      if (thisCycleData.containsKey(grade)) {
        thisCycleData[grade]!['amount'] = thisCycleData[grade]!['amount']! + expense.amount;
        thisCycleData[grade]!['count'] = thisCycleData[grade]!['count']! + 1;
      }
    }

    // 今サイクルの平均単価を計算
    final thisCycleWithAvg = <String, Map<String, int>>{};
    for (final entry in thisCycleData.entries) {
      final count = entry.value['count']!;
      final amount = entry.value['amount']!;
      thisCycleWithAvg[entry.key] = {
        'amount': amount,
        'count': count,
        'avg': count > 0 ? (amount / count).round() : 0,
      };
    }

    // 過去6サイクルのデータ（今サイクルを除く）
    final last6CyclesData = <String, Map<String, int>>{
      'saving': {'total': 0, 'count': 0},
      'standard': {'total': 0, 'count': 0},
      'reward': {'total': 0, 'count': 0},
    };

    // offset 1〜6 で過去6サイクル分を集計
    for (var offset = 1; offset <= 6; offset++) {
      final cycleDates = getCycleDatesForOffset(offset);
      final prevCycleStart = DateTime(cycleDates.start.year, cycleDates.start.month, cycleDates.start.day);
      final prevCycleEnd = DateTime(cycleDates.end.year, cycleDates.end.month, cycleDates.end.day);

      final cycleExpenses = _expenses.where((e) {
        final expenseDate = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
        return e.category == categoryName &&
            !expenseDate.isBefore(prevCycleStart) &&
            !expenseDate.isAfter(prevCycleEnd);
      });

      for (final expense in cycleExpenses) {
        final grade = expense.grade;
        if (last6CyclesData.containsKey(grade)) {
          last6CyclesData[grade]!['total'] = last6CyclesData[grade]!['total']! + expense.amount;
          last6CyclesData[grade]!['count'] = last6CyclesData[grade]!['count']! + 1;
        }
      }
    }

    // 過去6サイクルの平均単価を計算
    final last6CyclesAvg = <String, Map<String, int>>{};
    for (final entry in last6CyclesData.entries) {
      final count = entry.value['count']!;
      final total = entry.value['total']!;
      last6CyclesAvg[entry.key] = {
        'avg': count > 0 ? (total / count).round() : 0,
        'count': count,
      };
    }

    // 合計
    int totalAmount = 0;
    int totalCount = 0;
    for (final data in thisCycleWithAvg.values) {
      totalAmount += data['amount']!;
      totalCount += data['count']!;
    }

    perfMonitor.stopTimer('AppState.getCategoryDetailAnalysis');
    return {
      'thisMonth': thisCycleWithAvg,
      'last6MonthsAvg': last6CyclesAvg,
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
    int categoryId, {
    int months = 12,
  }) async {
    // SQLで集計データを取得
    final rawData = await _db.getMonthlyGradeBreakdown(
      categoryId: categoryId,
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
      final wasPremium = isPremium;

      if (value == null) {
        await prefs.remove(_keyDevPremiumOverride);
      } else {
        await prefs.setBool(_keyDevPremiumOverride, value);
      }

      _devPremiumOverride = value;
      final isNowPremium = isPremium;
      if (wasPremium && !isNowPremium) {
        await _enforceQuickEntryLimitIfNeeded();
      }
      _lastPremiumStatus = isNowPremium;
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

  // ============================================================
  // テーマ設定
  // ============================================================

  /// テーマ設定を読み込み
  Future<void> loadThemeSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_keyIsDark) ?? false;
      final patternKey = prefs.getString(_keyColorPattern);
      if (patternKey != null) {
        _colorPattern = ColorPatternInfo.fromKey(patternKey);
      }
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    }
  }

  /// ダークモード切り替え
  Future<void> setDarkMode(bool isDark) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsDark, isDark);
      _isDark = isDark;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting dark mode: $e');
    }
  }

  /// 背景色パターン切り替え
  Future<void> setColorPattern(ColorPattern pattern) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyColorPattern, pattern.key);
      _colorPattern = pattern;
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting color pattern: $e');
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

  /// スマート・コンボ予測を取得
  /// カテゴリ別に頻出の「金額×支出タイプ」組み合わせを最大3つ返す
  /// 返り値: List<{ 'amount': int, 'grade': String, 'freq': int, 'lastUsed': String }>
  Future<List<Map<String, dynamic>>> getSmartCombos(int categoryId) async {
    return await _db.getSmartCombos(categoryId: categoryId, limit: 3);
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
      categoryId: entry.categoryId,
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

  /// N個前のサイクルの期間を取得
  /// offset: 0 = 現在のサイクル, 1 = 1つ前のサイクル, ...
  ({DateTime start, DateTime end}) getCycleDatesForOffset(int offset) {
    var date = DateTime.now();
    for (var i = 0; i < offset; i++) {
      final currentStart = _financialCycle.getStartDate(date);
      date = currentStart.subtract(const Duration(days: 1));
    }
    return (
      start: _financialCycle.getStartDate(date),
      end: _financialCycle.getEndDate(date),
    );
  }

  /// N個前のサイクルのカテゴリ別統計を取得
  Future<List<Map<String, dynamic>>> getCategoryStatsForCycle(int offset) async {
    final dates = getCycleDatesForOffset(offset);
    return await _db.getCategoryStats(
      cycleStartDate: dates.start,
      cycleEndDate: dates.end,
    );
  }

  /// N個前のサイクルの日別支出を取得
  Future<Map<int, int>> getDailyExpensesForCycle(int offset) async {
    final dates = getCycleDatesForOffset(offset);
    return await _db.getDailyExpensesByCycle(
      cycleStartDate: dates.start,
      cycleEndDate: dates.end,
    );
  }

  /// N個前のサイクルの収入合計を取得
  Future<int> getCycleIncomeTotal(int offset) async {
    final dates = getCycleDatesForOffset(offset);
    final cycleKey = _financialCycle.getCycleKey(dates.start);
    return await _db.getCycleIncomeTotal(cycleKey);
  }

  /// N個前のサイクルの支出合計を取得
  Future<int> getCycleTotalExpenses(int offset) async {
    final dates = getCycleDatesForOffset(offset);
    return await _db.getCycleTotalExpenses(
      cycleStartDate: dates.start,
      cycleEndDate: dates.end,
    );
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

  // ========================================
  // 予定支出（ScheduledExpense）
  // ========================================

  /// 未確定の予定支出一覧（予定日昇順）
  List<ScheduledExpense> get unconfirmedScheduledExpenses => _scheduledExpenses;

  /// 期限切れの予定支出を取得（予定日が今日より前）
  Future<List<ScheduledExpense>> getOverdueScheduledExpenses() async {
    return await _db.getOverdueScheduledExpenses();
  }

  /// 現在サイクル内の未確定予定支出の合計金額
  Future<int> getScheduledExpensesTotalInCurrentCycle() async {
    return await _db.getScheduledExpensesTotalInCycle(
      cycleStartDate: cycleStartDate,
      cycleEndDate: cycleEndDate,
    );
  }

  /// 予定支出を追加
  Future<bool> addScheduledExpense(ScheduledExpense scheduledExpense) async {
    try {
      await _db.insertScheduledExpense(scheduledExpense);
      await _reloadScheduledExpenses();
      return true;
    } catch (e) {
      debugPrint('Error adding scheduled expense: $e');
      return false;
    }
  }

  /// 予定支出を更新
  Future<bool> updateScheduledExpense(ScheduledExpense scheduledExpense) async {
    try {
      await _db.updateScheduledExpense(scheduledExpense);
      await _reloadScheduledExpenses();
      return true;
    } catch (e) {
      debugPrint('Error updating scheduled expense: $e');
      return false;
    }
  }

  /// 予定支出を削除
  Future<bool> deleteScheduledExpense(int id) async {
    try {
      await _db.deleteScheduledExpense(id);
      await _reloadScheduledExpenses();
      return true;
    } catch (e) {
      debugPrint('Error deleting scheduled expense: $e');
      return false;
    }
  }

  /// 予定支出を確定（expensesテーブルに登録）
  Future<bool> confirmScheduledExpense(ScheduledExpense scheduledExpense) async {
    try {
      await _db.confirmScheduledExpense(scheduledExpense);
      await _reloadScheduledExpenses();
      await _reloadExpenses();
      return true;
    } catch (e) {
      debugPrint('Error confirming scheduled expense: $e');
      return false;
    }
  }

  /// 予定支出を修正して確定
  Future<bool> confirmScheduledExpenseWithModification(
    ScheduledExpense original, {
    required int newAmount,
    int? newCategoryId,
    String? newCategory,
    String? newGrade,
    String? newMemo,
  }) async {
    try {
      // 修正された予定支出を作成
      final modified = original.copyWith(
        amount: newAmount,
        categoryId: newCategoryId ?? original.categoryId,
        category: newCategory ?? original.category,
        grade: newGrade ?? original.grade,
        memo: newMemo ?? original.memo,
      );

      // 修正内容で確定
      await _db.updateScheduledExpense(modified);
      await _db.confirmScheduledExpense(modified);
      await _reloadScheduledExpenses();
      await _reloadExpenses();
      return true;
    } catch (e) {
      debugPrint('Error confirming modified scheduled expense: $e');
      return false;
    }
  }

  // ========================================
  // カテゴリ別予算（CategoryBudget）
  // ========================================

  /// カテゴリ予算を追加
  Future<bool> addCategoryBudget(CategoryBudget budget) async {
    try {
      await _db.insertCategoryBudget(budget);
      await _reloadCategoryBudgets();
      return true;
    } catch (e) {
      debugPrint('Error adding category budget: $e');
      return false;
    }
  }

  /// カテゴリ予算を更新
  Future<bool> updateCategoryBudget(CategoryBudget budget) async {
    try {
      await _db.updateCategoryBudget(budget);
      await _reloadCategoryBudgets();
      return true;
    } catch (e) {
      debugPrint('Error updating category budget: $e');
      return false;
    }
  }

  /// カテゴリ予算を削除
  Future<bool> deleteCategoryBudget(int id) async {
    try {
      await _db.deleteCategoryBudget(id);
      await _reloadCategoryBudgets();
      return true;
    } catch (e) {
      debugPrint('Error deleting category budget: $e');
      return false;
    }
  }

  /// 今月のみ（one_time）のカテゴリ予算を全て削除
  Future<bool> deleteOneTimeCategoryBudgets() async {
    try {
      await _db.deleteOneTimeCategoryBudgets();
      await _reloadCategoryBudgets();
      return true;
    } catch (e) {
      debugPrint('Error deleting one-time category budgets: $e');
      return false;
    }
  }

  /// カテゴリ別の支出合計を取得（現在サイクル内）
  Future<Map<String, int>> getCategoryExpenseTotals() async {
    return await _db.getCategoryExpenseTotals(
      cycleStartDate: cycleStartDate,
      cycleEndDate: cycleEndDate,
    );
  }

  /// カテゴリ予算と実績を合わせたデータを取得（消費率順）
  /// 返り値: List<{
  ///   'budget': CategoryBudget,
  ///   'spent': int,
  ///   'rate': double (消費率 0.0〜),
  ///   'isOverBudget': bool,
  /// }>
  Future<List<Map<String, dynamic>>> getCategoryBudgetStatus() async {
    if (_categoryBudgets.isEmpty) return [];

    final totals = await getCategoryExpenseTotals();
    final result = <Map<String, dynamic>>[];

    for (final budget in _categoryBudgets) {
      final spent = totals[budget.categoryName] ?? 0;
      final rate = budget.budgetAmount > 0
          ? spent / budget.budgetAmount
          : 0.0;

      result.add({
        'budget': budget,
        'spent': spent,
        'rate': rate,
        'isOverBudget': spent > budget.budgetAmount,
      });
    }

    // 消費率が高い順にソート
    result.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));

    return result;
  }

  /// 予算設定済みのカテゴリ名リストを取得
  List<String> get budgetedCategoryNames {
    return _categoryBudgets.map((b) => b.categoryName).toList();
  }

  /// 予算未設定のカテゴリ名リストを取得
  List<String> get unbudgetedCategoryNames {
    final budgeted = budgetedCategoryNames;
    return categoryNames.where((name) => !budgeted.contains(name)).toList();
  }

  /// 前サイクルのカテゴリ予算達成状況を取得（サイクル切替時のレポート用）
  /// 返り値: List<{
  ///   'budget': CategoryBudget,
  ///   'spent': int,
  ///   'rate': double (消費率 0.0〜),
  ///   'isOverBudget': bool,
  /// }>
  Future<List<Map<String, dynamic>>> getPreviousCycleBudgetStatus() async {
    if (_categoryBudgets.isEmpty) return [];

    final now = DateTime.now();
    final prevStartDate = _financialCycle.getPreviousCycleStartDate(now);
    final prevEndDate = _financialCycle.getPreviousCycleEndDate(now);

    final totals = await _db.getCategoryExpenseTotals(
      cycleStartDate: prevStartDate,
      cycleEndDate: prevEndDate,
    );

    final result = <Map<String, dynamic>>[];

    for (final budget in _categoryBudgets) {
      final spent = totals[budget.categoryName] ?? 0;
      final rate = budget.budgetAmount > 0
          ? spent / budget.budgetAmount
          : 0.0;

      result.add({
        'budget': budget,
        'spent': spent,
        'rate': rate,
        'isOverBudget': spent > budget.budgetAmount,
      });
    }

    // 消費率が高い順にソート
    result.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));

    return result;
  }

  /// 継続予算（recurring）のリストを取得
  List<CategoryBudget> get continuingBudgets {
    return _categoryBudgets.where((b) => b.isRecurring).toList();
  }

  /// 今月のみ予算（one_time）のリストを取得
  List<CategoryBudget> get endingBudgets {
    return _categoryBudgets.where((b) => b.isOneTime).toList();
  }
}
