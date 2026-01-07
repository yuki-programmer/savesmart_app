import 'package:flutter/foundation.dart' hide Category;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
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

  int get todayTotal => todayExpenses.fold(0, (sum, e) => sum + e.amount);
  int get thisWeekTotal => thisWeekExpenses.fold(0, (sum, e) => sum + e.amount);
  int get thisMonthTotal => thisMonthExpenses.fold(0, (sum, e) => sum + e.amount);

  // スタンダード比での節約額を計算
  // 節約タイプの支出は「スタンダード価格の70%」と仮定
  // ご褒美タイプの支出は「スタンダード価格の130%」と仮定
  int get thisMonthSavings {
    int savings = 0;
    for (final expense in thisMonthExpenses) {
      switch (expense.grade) {
        case 'saving':
          // 節約タイプ: 通常より30%安い → 節約額 = 実額 / 0.7 - 実額
          savings += (expense.amount / 0.7 - expense.amount).round();
          break;
        case 'reward':
          // ご褒美タイプ: 通常より30%高い → 損失 = 実額 - 実額 / 1.3
          savings -= (expense.amount - expense.amount / 1.3).round();
          break;
        default:
          // 標準タイプ: 差分なし
          break;
      }
    }
    return savings;
  }

  int get todaySavings {
    int savings = 0;
    for (final expense in todayExpenses) {
      switch (expense.grade) {
        case 'saving':
          savings += (expense.amount / 0.7 - expense.amount).round();
          break;
        case 'reward':
          savings -= (expense.amount - expense.amount / 1.3).round();
          break;
        default:
          break;
      }
    }
    return savings;
  }

  int get thisWeekSavings {
    int savings = 0;
    for (final expense in thisWeekExpenses) {
      switch (expense.grade) {
        case 'saving':
          savings += (expense.amount / 0.7 - expense.amount).round();
          break;
        case 'reward':
          savings -= (expense.amount - expense.amount / 1.3).round();
          break;
        default:
          break;
      }
    }
    return savings;
  }

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

      _expenses = await _db.getExpenses();
      _categories = await _db.getCategories();
      _fixedCosts = await _db.getFixedCosts();
      _fixedCostCategories = await _db.getFixedCostCategories();
      _currentBudget = await _db.getCurrentBudget();
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addExpense(Expense expense) async {
    await _db.insertExpense(expense);
    await loadData();
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

    await loadData();
  }

  Future<void> updateExpense(Expense expense) async {
    await _db.updateExpense(expense);
    await loadData();
  }

  Future<void> deleteExpense(int id) async {
    await _db.deleteExpense(id);
    await loadData();
  }

  Future<void> splitExpense(int id, int splitAmount, String newCategory) async {
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

    // 新しい支出を作成
    final newExpense = Expense(
      amount: splitAmount,
      category: newCategory,
      grade: original.grade,
      memo: '${original.category}から切り出し',
      createdAt: original.createdAt,
      parentId: original.id,
    );
    await _db.insertExpense(newExpense);

    await loadData();
  }

  Future<void> addCategory(String name) async {
    final sortOrder = _categories.length;
    final category = Category(
      name: name,
      sortOrder: sortOrder,
      isDefault: false,
    );
    await _db.insertCategory(category);
    await loadData();
  }

  // カテゴリ名を更新
  Future<void> updateCategory(int id, String newName) async {
    await _db.updateCategoryName(id, newName);
    await loadData();
  }

  // カテゴリを削除（関連する支出も削除）
  Future<void> deleteCategory(int id) async {
    await _db.deleteCategoryWithExpenses(id);
    await loadData();
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

  Future<void> setBudget(int amount) async {
    final now = DateTime.now();
    final budget = Budget(
      amount: amount,
      year: now.year,
      month: now.month,
    );
    await _db.insertBudget(budget);
    await loadData();
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

  /// 起動時に当月の使える金額をロード
  Future<void> loadMonthlyAvailableAmount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final key = _monthKey(now);
      final prefKey = '$_keyMonthlyAmountPrefix$key';

      if (prefs.containsKey(prefKey)) {
        _monthlyAvailableAmounts[key] = prefs.getInt(prefKey);
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
  Future<void> addFixedCost(FixedCost fixedCost) async {
    await _db.insertFixedCost(fixedCost);
    await loadData();
  }

  /// 固定費を更新
  Future<void> updateFixedCost(FixedCost fixedCost) async {
    await _db.updateFixedCost(fixedCost);
    await loadData();
  }

  /// 固定費を削除
  Future<void> removeFixedCost(int id) async {
    await _db.deleteFixedCost(id);
    await loadData();
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
    await loadData();
  }

  /// 固定費カテゴリ名を更新
  Future<void> renameFixedCostCategory(int id, String newName) async {
    final category = _fixedCostCategories.firstWhere((c) => c.id == id);
    final updated = category.copyWith(name: newName);
    await _db.updateFixedCostCategory(updated);
    await loadData();
  }

  /// 固定費カテゴリを削除（参照されている場合は削除不可）
  /// 戻り値: 削除成功=true, 参照あり=false
  Future<bool> deleteFixedCostCategory(int id) async {
    final isInUse = await _db.isFixedCostCategoryInUse(id);
    if (isInUse) {
      return false;
    }
    await _db.deleteFixedCostCategory(id);
    await loadData();
    return true;
  }

  /// カテゴリIDから名前を取得
  String? getFixedCostCategoryName(int? categoryId) {
    if (categoryId == null) return null;
    final category = _fixedCostCategories.where((c) => c.id == categoryId);
    return category.isNotEmpty ? category.first.name : null;
  }
}
