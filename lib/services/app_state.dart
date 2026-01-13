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
import 'database_service.dart';

class CategoryStats {
  final String category;
  final int totalAmount;
  final int standardAverage;
  final int savingsAmount;
  final int expenseCount;

  CategoryStats({
    required this.category,
    required this.totalAmount,
    required this.standardAverage,
    required this.savingsAmount,
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

  // === タブ切り替え & incomeSheet自動起動 ===
  int? _requestedTabIndex;
  bool _openIncomeSheetRequested = false;

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

  List<Expense> get todayExpenses {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _expenses.where((e) {
      final expenseDate = DateTime(
        e.createdAt.year,
        e.createdAt.month,
        e.createdAt.day,
      );
      return expenseDate == today;
    }).toList();
  }

  List<Expense> get thisWeekExpenses {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    return _expenses.where((e) => e.createdAt.isAfter(start)).toList();
  }

  List<Expense> get thisMonthExpenses {
    final now = DateTime.now();
    return _expenses.where((e) {
      return e.createdAt.year == now.year && e.createdAt.month == now.month;
    }).toList();
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

  int get todayTotal => todayExpenses.fold(0, (sum, e) => sum + e.amount);
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

  // スタンダード比での節約額を計算
  // 節約タイプの支出は「スタンダード価格の70%」と仮定
  // ご褒美タイプの支出は「スタンダード価格の130%」と仮定

  /// 単一支出の節約額を計算
  int _savingsForExpense(Expense expense) {
    switch (expense.grade) {
      case 'saving':
        // 節約タイプ: 通常より30%安い → 節約額 = 実額 / 0.7 - 実額
        return (expense.amount / 0.7 - expense.amount).round();
      case 'reward':
        // ご褒美タイプ: 通常より30%高い → 損失 = 実額 - 実額 / 1.3
        return -(expense.amount - expense.amount / 1.3).round();
      default:
        // 標準タイプ: 差分なし
        return 0;
    }
  }

  /// 支出リストの節約額合計を計算
  int _calculateSavings(List<Expense> expenses) {
    return expenses.fold(0, (sum, e) => sum + _savingsForExpense(e));
  }

  int get thisMonthSavings => _calculateSavings(thisMonthExpenses);
  int get todaySavings => _calculateSavings(todayExpenses);
  int get thisWeekSavings => _calculateSavings(thisWeekExpenses);

  double get savingsPercentage {
    if (thisMonthTotal == 0) return 0;
    return (thisMonthSavings / thisMonthTotal) * 100;
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

      final savingsAmount = standardTotal - totalAmount;

      stats[entry.key] = CategoryStats(
        category: entry.key,
        totalAmount: totalAmount,
        standardAverage: standardAverage,
        savingsAmount: savingsAmount,
        expenseCount: expenses.length,
      );
    }

    return stats;
  }

  // Actions
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // デフォルト固定費カテゴリを確保（保険: マイグレーションで漏れた場合に補完）
      await _db.ensureDefaultFixedCostCategories();

      // 並列で取得（高速化）
      final results = await Future.wait([
        _db.getExpenses(),
        _db.getCategories(),
        _db.getFixedCosts(),
        _db.getFixedCostCategories(),
        _db.getCurrentBudget(),
        _db.getQuickEntries(),
      ]);

      _expenses = results[0] as List<Expense>;
      _categories = results[1] as List<Category>;
      _fixedCosts = results[2] as List<FixedCost>;
      _fixedCostCategories = results[3] as List<FixedCostCategory>;
      _currentBudget = results[4] as Budget?;
      _quickEntries = results[5] as List<QuickEntry>;
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // === 部分リロードメソッド（パフォーマンス最適化） ===

  Future<void> _reloadExpenses() async {
    _expenses = await _db.getExpenses();
    notifyListeners();
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

  Future<void> addCategory(String name) async {
    final sortOrder = _categories.length;
    final category = Category(
      name: name,
      sortOrder: sortOrder,
      isDefault: false,
    );
    await _db.insertCategory(category);
    await _reloadCategories();
  }

  // カテゴリ名を更新
  Future<void> updateCategory(int id, String newName) async {
    await _db.updateCategoryName(id, newName);
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

  /// 今月の使える金額を取得（便利getter）
  int? get thisMonthAvailableAmount {
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

  /// 直近6ヶ月の支出を取得
  List<Expense> get _last6MonthsExpenses {
    final now = DateTime.now();
    final sixMonthsAgo = DateTime(now.year, now.month - 6, 1);
    return _expenses.where((e) => e.createdAt.isAfter(sixMonthsAgo)).toList();
  }

  /// カテゴリ別・グレード別の平均単価を計算（直近6ヶ月）
  /// 返り値: { 'カテゴリ名': { 'standard': {'avg': int, 'count': int}, 'reward': {...} } }
  Map<String, Map<String, Map<String, int>>> get _categoryGradeAverages {
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
}
