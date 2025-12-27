import 'package:flutter/foundation.dart' hide Category;
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../config/constants.dart';
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
  Budget? _currentBudget;
  bool _isLoading = true;

  // Getters
  List<Expense> get expenses => _expenses;
  List<Category> get categories => _categories;
  Budget? get currentBudget => _currentBudget;
  bool get isLoading => _isLoading;

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

    // カテゴリごとにグループ化
    final Map<String, List<Expense>> byCategory = {};
    for (final expense in monthExpenses) {
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
      _expenses = await _db.getExpenses();
      _categories = await _db.getCategories();
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
}
