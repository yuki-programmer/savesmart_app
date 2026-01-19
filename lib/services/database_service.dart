import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
import '../models/quick_entry.dart';
import 'performance_monitor.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    // 起動時にquick_entriesテーブルが存在しない場合は作成（マイグレーション漏れ対策）
    await _ensureQuickEntriesTable(_database!);
    return _database!;
  }

  /// quick_entriesテーブルが存在しない場合に作成（マイグレーション漏れ対策）
  Future<void> _ensureQuickEntriesTable(Database db) async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='quick_entries'"
    );
    if (tables.isEmpty) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quick_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          amount INTEGER NOT NULL,
          grade TEXT NOT NULL,
          memo TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'savesmart.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        category TEXT NOT NULL,
        grade TEXT NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL,
        parent_id INTEGER,
        FOREIGN KEY (parent_id) REFERENCES expenses (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        sort_order INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        icon TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        UNIQUE (year, month)
      )
    ''');

    await db.execute('''
      CREATE TABLE fixed_cost_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE fixed_costs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER,
        category_name_snapshot TEXT,
        amount INTEGER NOT NULL,
        memo TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES fixed_cost_categories (id)
      )
    ''');

    // デフォルト固定費カテゴリを挿入
    await _ensureDefaultFixedCostCategories(db);

    // デフォルトカテゴリを挿入
    final defaultCategories = [
      'コーヒー',
      'ランチ',
      '食料品',
      '交通費',
      '買い物',
      '娯楽',
      '医療',
      'その他',
    ];

    for (var i = 0; i < defaultCategories.length; i++) {
      await db.insert('categories', {
        'name': defaultCategories[i],
        'sort_order': i,
        'is_default': 1,
      });
    }

    // インデックス作成（時系列クエリ高速化）
    await db.execute('''
      CREATE INDEX idx_expenses_created_at ON expenses (created_at)
    ''');
    await db.execute('''
      CREATE INDEX idx_expenses_category_created_at ON expenses (category, created_at)
    ''');

    // クイック登録テーブル
    await db.execute('''
      CREATE TABLE quick_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        grade TEXT NOT NULL,
        memo TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 日別予算テーブル（今日使えるお金の固定値を保存）
    await db.execute('''
      CREATE TABLE daily_budgets (
        date TEXT PRIMARY KEY,
        fixed_amount INTEGER NOT NULL
      )
    ''');

    // サイクル収入テーブル（メイン収入・サブ収入を一元管理）
    await db.execute('''
      CREATE TABLE cycle_incomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cycle_key TEXT NOT NULL,
        is_main INTEGER NOT NULL,
        name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // cycle_key でのクエリ高速化
    await db.execute('''
      CREATE INDEX idx_cycle_incomes_cycle_key ON cycle_incomes (cycle_key)
    ''');
  }

  // Expense CRUD
  Future<List<Expense>> getExpenses({DateTime? from, DateTime? to}) async {
    perfMonitor.startTimer('DB.getExpenses');
    final db = await database;
    String? whereClause;
    List<dynamic>? whereArgs;

    if (from != null && to != null) {
      whereClause = 'created_at >= ? AND created_at <= ?';
      whereArgs = [from.toIso8601String(), to.toIso8601String()];
    } else if (from != null) {
      whereClause = 'created_at >= ?';
      whereArgs = [from.toIso8601String()];
    } else if (to != null) {
      whereClause = 'created_at <= ?';
      whereArgs = [to.toIso8601String()];
    }

    final maps = await db.query(
      'expenses',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC, id DESC',
    );

    final result = maps.map((map) => Expense.fromMap(map)).toList();
    perfMonitor.stopTimer('DB.getExpenses');
    return result;
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    final map = expense.toMap();
    map.remove('id');
    return await db.insert('expenses', map);
  }

  Future<void> updateExpense(Expense expense) async {
    final db = await database;
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Category CRUD
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query(
      'categories',
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    final map = category.toMap();
    map.remove('id');
    return await db.insert('categories', map);
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // カテゴリ名を更新（関連する支出のカテゴリ名も更新）
  Future<void> updateCategoryName(int id, String newName) async {
    final db = await database;

    // 古いカテゴリ名を取得
    final categories = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (categories.isNotEmpty) {
      final oldName = categories.first['name'] as String;

      // 関連する支出のカテゴリ名を更新
      await db.update(
        'expenses',
        {'category': newName},
        where: 'category = ?',
        whereArgs: [oldName],
      );
    }

    // カテゴリ名を更新
    await db.update(
      'categories',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // カテゴリ削除（関連する支出も削除）
  Future<void> deleteCategoryWithExpenses(int id) async {
    final db = await database;

    // カテゴリ名を取得
    final categories = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (categories.isNotEmpty) {
      final categoryName = categories.first['name'] as String;

      // 関連する支出を削除
      await db.delete(
        'expenses',
        where: 'category = ?',
        whereArgs: [categoryName],
      );
    }

    // カテゴリを削除
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Budget CRUD
  Future<Budget?> getCurrentBudget() async {
    final db = await database;
    final now = DateTime.now();
    final maps = await db.query(
      'budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [now.year, now.month],
    );

    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<Budget?> getBudget(int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );

    if (maps.isEmpty) return null;
    return Budget.fromMap(maps.first);
  }

  Future<int> insertBudget(Budget budget) async {
    final db = await database;
    final map = budget.toMap();
    map.remove('id');
    return await db.insert(
      'budgets',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateBudget(Budget budget) async {
    final db = await database;
    await db.update(
      'budgets',
      budget.toMap(),
      where: 'id = ?',
      whereArgs: [budget.id],
    );
  }

  // Daily Budget (今日使えるお金の固定値)

  /// 指定日の固定予算を取得
  Future<int?> getDailyBudget(DateTime date) async {
    final db = await database;
    final dateStr = _formatDateOnly(date);
    final maps = await db.query(
      'daily_budgets',
      where: 'date = ?',
      whereArgs: [dateStr],
    );
    if (maps.isEmpty) return null;
    return maps.first['fixed_amount'] as int;
  }

  /// 指定日の固定予算を保存（存在すれば上書き）
  Future<void> saveDailyBudget(DateTime date, int amount) async {
    final db = await database;
    final dateStr = _formatDateOnly(date);
    await db.insert(
      'daily_budgets',
      {'date': dateStr, 'fixed_amount': amount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 日付を YYYY-MM-DD 形式の文字列に変換
  String _formatDateOnly(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Database migration
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fixed_costs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          amount INTEGER NOT NULL,
          day_of_month INTEGER,
          memo TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 3) {
      // 固定費カテゴリテーブルを作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS fixed_cost_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL
        )
      ''');

      // デフォルト固定費カテゴリを挿入
      await _ensureDefaultFixedCostCategories(db);

      // fixed_costs テーブルに新しいカラムを追加（既存データの互換性維持）
      await db.execute('ALTER TABLE fixed_costs ADD COLUMN category_id INTEGER');
      await db.execute('ALTER TABLE fixed_costs ADD COLUMN category_name_snapshot TEXT');

      // 既存の name を category_name_snapshot にコピー
      await db.execute('UPDATE fixed_costs SET category_name_snapshot = name WHERE name IS NOT NULL');
    }

    if (oldVersion < 4) {
      // expenses.created_at にインデックスを追加（時系列クエリ高速化）
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_expenses_created_at ON expenses (created_at)
      ''');
      // カテゴリ + 日付の複合インデックス（カテゴリ別時系列集計用）
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_expenses_category_created_at ON expenses (category, created_at)
      ''');
    }

    if (oldVersion < 5) {
      // クイック登録テーブルを作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quick_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          category TEXT NOT NULL,
          amount INTEGER NOT NULL,
          grade TEXT NOT NULL,
          memo TEXT,
          sort_order INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }

    if (oldVersion < 6) {
      // 日別予算テーブルを作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_budgets (
          date TEXT PRIMARY KEY,
          fixed_amount INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      // サイクル収入テーブルを作成
      await db.execute('''
        CREATE TABLE IF NOT EXISTS cycle_incomes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          cycle_key TEXT NOT NULL,
          is_main INTEGER NOT NULL,
          name TEXT NOT NULL,
          amount INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      // cycle_key でのクエリ高速化
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_cycle_incomes_cycle_key ON cycle_incomes (cycle_key)
      ''');
    }

    if (oldVersion < 8) {
      // categories テーブルに icon カラムを追加
      await db.execute('ALTER TABLE categories ADD COLUMN icon TEXT');

      // 既存カテゴリにデフォルトアイコンをマッピング
      final defaultIcons = {
        '食費': 'local_grocery_store',
        '食料品': 'local_grocery_store',
        '外食': 'restaurant',
        'ランチ': 'lunch_dining',
        'コーヒー': 'local_cafe',
        'カフェ': 'local_cafe',
        '日用品': 'shopping_bag',
        '買い物': 'shopping_bag',
        '交通費': 'train',
        'ガソリン': 'directions_car',
        '趣味・娯楽': 'sports_esports',
        '娯楽': 'sports_esports',
        '交際費': 'local_bar',
        '衣服・美容': 'content_cut',
        '美容室': 'content_cut',
        '健康': 'medical_services',
        '医療': 'medical_services',
        'その他': 'category',
      };

      for (final entry in defaultIcons.entries) {
        await db.execute(
          'UPDATE categories SET icon = ? WHERE name = ?',
          [entry.value, entry.key],
        );
      }
    }
  }

  /// デフォルト固定費カテゴリが存在しない場合に投入する
  /// 判定条件: isDefault=1 のレコードが1件も無い場合に投入
  /// マイグレーションと初期ロード両方から呼ばれる（二重化で堅牢性確保）
  Future<void> _ensureDefaultFixedCostCategories(Database db) async {
    // isDefault=1 のレコードが存在するかチェック
    final existing = await db.query(
      'fixed_cost_categories',
      where: 'is_default = ?',
      whereArgs: [1],
      limit: 1,
    );

    // 既にデフォルトカテゴリが存在する場合は何もしない
    if (existing.isNotEmpty) return;

    // デフォルト固定費カテゴリを挿入
    final defaultFixedCostCategories = ['家賃', '光熱費', 'スマホ代'];
    for (var i = 0; i < defaultFixedCostCategories.length; i++) {
      await db.insert('fixed_cost_categories', {
        'name': defaultFixedCostCategories[i],
        'is_default': 1,
        'sort_order': i,
      });
    }
  }

  /// 外部から呼び出し可能なデフォルトカテゴリ確保メソッド
  /// AppState.loadData() から呼び出して保険をかける
  Future<void> ensureDefaultFixedCostCategories() async {
    final db = await database;
    await _ensureDefaultFixedCostCategories(db);
  }

  // FixedCostCategory CRUD
  Future<List<FixedCostCategory>> getFixedCostCategories() async {
    final db = await database;
    final maps = await db.query(
      'fixed_cost_categories',
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => FixedCostCategory.fromMap(map)).toList();
  }

  Future<int> insertFixedCostCategory(FixedCostCategory category) async {
    final db = await database;
    final map = category.toMap();
    map.remove('id');
    return await db.insert('fixed_cost_categories', map);
  }

  Future<void> updateFixedCostCategory(FixedCostCategory category) async {
    final db = await database;
    await db.update(
      'fixed_cost_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteFixedCostCategory(int id) async {
    final db = await database;
    await db.delete(
      'fixed_cost_categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// カテゴリが固定費に参照されているかチェック
  Future<bool> isFixedCostCategoryInUse(int categoryId) async {
    final db = await database;
    final result = await db.query(
      'fixed_costs',
      where: 'category_id = ?',
      whereArgs: [categoryId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // FixedCost CRUD
  Future<List<FixedCost>> getFixedCosts() async {
    final db = await database;
    final maps = await db.query(
      'fixed_costs',
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => FixedCost.fromMap(map)).toList();
  }

  Future<int> insertFixedCost(FixedCost fixedCost) async {
    final db = await database;
    final map = fixedCost.toMap();
    map.remove('id');
    return await db.insert('fixed_costs', map);
  }

  Future<void> updateFixedCost(FixedCost fixedCost) async {
    final db = await database;
    await db.update(
      'fixed_costs',
      fixedCost.toMap(),
      where: 'id = ?',
      whereArgs: [fixedCost.id],
    );
  }

  Future<void> deleteFixedCost(int id) async {
    final db = await database;
    await db.delete(
      'fixed_costs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// カテゴリ別・月別・グレード別の支出集計を取得（SQL集計）
  /// 返り値: List<{ 'month': 'YYYY-MM', 'grade': String, 'total': int, 'count': int }>
  Future<List<Map<String, dynamic>>> getMonthlyGradeBreakdown({
    required String categoryName,
    required int months,
  }) async {
    final db = await database;

    // 開始月を計算（months ヶ月前の月初）
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    final startDateStr = startDate.toIso8601String().substring(0, 10);

    final results = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', created_at) as month,
        grade,
        SUM(amount) as total,
        COUNT(*) as count
      FROM expenses
      WHERE category = ?
        AND created_at >= ?
      GROUP BY strftime('%Y-%m', created_at), grade
      ORDER BY month ASC, grade ASC
    ''', [categoryName, startDateStr]);

    return results.map((row) => {
      'month': row['month'] as String,
      'grade': row['grade'] as String,
      'total': row['total'] as int,
      'count': row['count'] as int,
    }).toList();
  }

  /// 全カテゴリの月別グレード集計を取得（月間支出推移用）
  /// 返り値: List<{ 'month': String, 'grade': String, 'total': int, 'count': int }>
  Future<List<Map<String, dynamic>>> getMonthlyGradeBreakdownAll({
    required int months,
  }) async {
    final db = await database;

    // 開始月を計算（months ヶ月前の月初）
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month - months + 1, 1);
    final startDateStr = startDate.toIso8601String().substring(0, 10);

    final results = await db.rawQuery('''
      SELECT
        strftime('%Y-%m', created_at) as month,
        grade,
        SUM(amount) as total,
        COUNT(*) as count
      FROM expenses
      WHERE created_at >= ?
      GROUP BY strftime('%Y-%m', created_at), grade
      ORDER BY month ASC, grade ASC
    ''', [startDateStr]);

    return results.map((row) => {
      'month': row['month'] as String,
      'grade': row['grade'] as String,
      'total': row['total'] as int,
      'count': row['count'] as int,
    }).toList();
  }

  /// スマート・コンボ予測: カテゴリ別に頻出の「金額×支出タイプ」組み合わせを取得
  /// 返り値: List<{ 'amount': int, 'grade': String, 'freq': int, 'lastUsed': String }>
  /// 優先順位: 頻度 DESC → 最終利用日 DESC
  Future<List<Map<String, dynamic>>> getSmartCombos({
    required String categoryName,
    int limit = 3,
  }) async {
    final db = await database;

    final results = await db.rawQuery('''
      SELECT
        amount,
        grade,
        COUNT(*) as freq,
        MAX(created_at) as last_used
      FROM expenses
      WHERE category = ?
      GROUP BY amount, grade
      ORDER BY freq DESC, last_used DESC
      LIMIT ?
    ''', [categoryName, limit]);

    return results.map((row) => {
      'amount': row['amount'] as int,
      'grade': row['grade'] as String,
      'freq': row['freq'] as int,
      'lastUsed': row['last_used'] as String,
    }).toList();
  }

  // QuickEntry CRUD
  Future<List<QuickEntry>> getQuickEntries() async {
    final db = await database;
    final maps = await db.query(
      'quick_entries',
      orderBy: 'sort_order ASC',
    );
    return maps.map((map) => QuickEntry.fromMap(map)).toList();
  }

  Future<int> insertQuickEntry(QuickEntry entry) async {
    final db = await database;
    final map = entry.toMap();
    map.remove('id');
    return await db.insert('quick_entries', map);
  }

  Future<void> updateQuickEntry(QuickEntry entry) async {
    final db = await database;
    await db.update(
      'quick_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<void> deleteQuickEntry(int id) async {
    final db = await database;
    await db.delete(
      'quick_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// クイック登録の並び順を更新
  Future<void> updateQuickEntryOrder(List<QuickEntry> entries) async {
    final db = await database;
    final batch = db.batch();
    for (var i = 0; i < entries.length; i++) {
      batch.update(
        'quick_entries',
        {'sort_order': i},
        where: 'id = ?',
        whereArgs: [entries[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // ========================================
  // CycleIncome CRUD（サイクル収入管理）
  // ========================================

  /// 指定サイクルの全収入を取得
  Future<List<Map<String, dynamic>>> getCycleIncomes(String cycleKey) async {
    final db = await database;
    final maps = await db.query(
      'cycle_incomes',
      where: 'cycle_key = ?',
      whereArgs: [cycleKey],
      orderBy: 'is_main DESC, created_at ASC', // メイン収入を先頭に
    );
    return maps;
  }

  /// 指定サイクルの収入合計を取得
  Future<int> getCycleIncomeTotal(String cycleKey) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM cycle_incomes
      WHERE cycle_key = ?
    ''', [cycleKey]);
    return result.first['total'] as int;
  }

  /// 指定サイクルのメイン収入を取得（1件のみ想定）
  Future<Map<String, dynamic>?> getMainIncome(String cycleKey) async {
    final db = await database;
    final maps = await db.query(
      'cycle_incomes',
      where: 'cycle_key = ? AND is_main = 1',
      whereArgs: [cycleKey],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first;
  }

  /// 指定サイクルのサブ収入一覧を取得
  Future<List<Map<String, dynamic>>> getSubIncomes(String cycleKey) async {
    final db = await database;
    final maps = await db.query(
      'cycle_incomes',
      where: 'cycle_key = ? AND is_main = 0',
      whereArgs: [cycleKey],
      orderBy: 'created_at ASC',
    );
    return maps;
  }

  /// 収入を登録
  Future<int> insertCycleIncome({
    required String cycleKey,
    required bool isMain,
    required String name,
    required int amount,
  }) async {
    final db = await database;
    return await db.insert('cycle_incomes', {
      'cycle_key': cycleKey,
      'is_main': isMain ? 1 : 0,
      'name': name,
      'amount': amount,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// 収入を更新
  Future<void> updateCycleIncome({
    required int id,
    required String name,
    required int amount,
  }) async {
    final db = await database;
    await db.update(
      'cycle_incomes',
      {
        'name': name,
        'amount': amount,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 収入を削除
  Future<void> deleteCycleIncome(int id) async {
    final db = await database;
    await db.delete(
      'cycle_incomes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 指定サイクルにメイン収入が存在するかチェック
  Future<bool> hasMainIncome(String cycleKey) async {
    final db = await database;
    final result = await db.query(
      'cycle_incomes',
      where: 'cycle_key = ? AND is_main = 1',
      whereArgs: [cycleKey],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // ========================================
  // サイクル別支出集計（前サイクル比較用）
  // ========================================

  /// 指定期間内の日ごとの支出合計を取得
  /// 返り値: Map<日付オフセット(0-indexed), 支出合計>
  ///
  /// 例: サイクル開始日から3日目の支出 → { 2: 5000 }
  Future<Map<int, int>> getDailyExpensesByCycle({
    required DateTime cycleStartDate,
    required DateTime cycleEndDate,
  }) async {
    final db = await database;

    // サイクル期間内の支出を取得
    final startStr = cycleStartDate.toIso8601String().substring(0, 10);
    // endDateは23:59:59までを含めるため、翌日の00:00:00未満とする
    final endDate = cycleEndDate.add(const Duration(days: 1));
    final endStr = endDate.toIso8601String().substring(0, 10);

    final results = await db.rawQuery('''
      SELECT
        date(created_at) as expense_date,
        SUM(amount) as total
      FROM expenses
      WHERE date(created_at) >= ? AND date(created_at) < ?
      GROUP BY date(created_at)
      ORDER BY expense_date ASC
    ''', [startStr, endStr]);

    // 結果を日オフセットに変換
    final dailyExpenses = <int, int>{};
    for (final row in results) {
      final dateStr = row['expense_date'] as String;
      final dateParts = dateStr.split('-');
      final expenseDate = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      );
      final dayOffset = expenseDate.difference(cycleStartDate).inDays;
      if (dayOffset >= 0) {
        dailyExpenses[dayOffset] = row['total'] as int;
      }
    }

    return dailyExpenses;
  }

  /// 指定期間内の支出合計を取得
  Future<int> getTotalExpensesByCycle({
    required DateTime cycleStartDate,
    required DateTime cycleEndDate,
  }) async {
    final db = await database;

    final startStr = cycleStartDate.toIso8601String().substring(0, 10);
    final endDate = cycleEndDate.add(const Duration(days: 1));
    final endStr = endDate.toIso8601String().substring(0, 10);

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date(created_at) >= ? AND date(created_at) < ?
    ''', [startStr, endStr]);

    return result.first['total'] as int;
  }

  // ========================================
  // 全履歴取得（ページネーション対応）
  // ========================================

  /// 全支出をページネーションで取得（新しい順）
  ///
  /// - [limit]: 1回の取得件数
  /// - [offset]: スキップする件数
  /// 返り値: List<Expense>
  Future<List<Expense>> getAllExpensesPaged({
    required int limit,
    required int offset,
  }) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  /// 全支出の総件数を取得
  Future<int> getAllExpensesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM expenses');
    return result.first['count'] as int;
  }

  /// 全期間から検索（ページネーション対応）
  ///
  /// カテゴリ名またはメモで部分一致検索
  Future<List<Expense>> searchExpensesPaged({
    required String query,
    required int limit,
    required int offset,
  }) async {
    perfMonitor.startTimer('DB.searchExpensesPaged');
    final db = await database;
    final searchQuery = '%$query%';
    final maps = await db.query(
      'expenses',
      where: 'category LIKE ? OR memo LIKE ?',
      whereArgs: [searchQuery, searchQuery],
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
    final result = maps.map((map) => Expense.fromMap(map)).toList();
    perfMonitor.stopTimer('DB.searchExpensesPaged');
    return result;
  }

  /// 検索結果の総件数を取得
  Future<int> searchExpensesCount(String query) async {
    final db = await database;
    final searchQuery = '%$query%';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM expenses WHERE category LIKE ? OR memo LIKE ?',
      [searchQuery, searchQuery],
    );
    return result.first['count'] as int;
  }

  // ========================================
  // バックアップ/リストア機能
  // ========================================

  /// データベースファイルのパスを取得
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'savesmart.db');
  }

  /// データベースをエクスポート（共有シートを開く）
  ///
  /// 返り値: true=成功, false=失敗
  Future<bool> exportDatabase() async {
    try {
      // 現在のDBを閉じる（書き込み中のデータを確定）
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      final dbPath = await getDatabasePath();
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        return false;
      }

      // ファイル名に日付を付与
      final now = DateTime.now();
      final fileName = 'savesmart_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.db';

      // 共有シートを開く
      await Share.shareXFiles(
        [XFile(dbPath, name: fileName)],
        subject: 'SaveSmart バックアップ',
        text: 'SaveSmartのデータバックアップファイルです。',
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  /// データベースをインポート（ファイル選択→置換）
  ///
  /// 返り値: true=成功, false=失敗/キャンセル
  Future<bool> importDatabase() async {
    try {
      // ファイル選択ダイアログを開く
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return false; // キャンセル
      }

      final pickedFile = result.files.first;
      if (pickedFile.path == null) {
        return false;
      }

      // .db ファイルかチェック（簡易）
      if (!pickedFile.name.endsWith('.db')) {
        return false;
      }

      final importFile = File(pickedFile.path!);
      if (!await importFile.exists()) {
        return false;
      }

      // 現在のDBを閉じる
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // 既存DBを削除して置換
      final dbPath = await getDatabasePath();
      final existingDb = File(dbPath);

      if (await existingDb.exists()) {
        await existingDb.delete();
      }

      // インポートファイルをコピー
      await importFile.copy(dbPath);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// データベースを閉じる（リストア後のリロード用）
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  // ========================================
  // SQL集計メソッド（パフォーマンス最適化）
  // ========================================

  /// 今日の支出合計を取得（SQL集計）
  Future<int> getTodayTotal() async {
    final db = await database;
    final today = _formatDateOnly(DateTime.now());

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date(created_at) = ?
    ''', [today]);

    return result.first['total'] as int;
  }

  /// 今日の支出一覧を取得
  Future<List<Expense>> getTodayExpenses() async {
    final db = await database;
    final today = _formatDateOnly(DateTime.now());

    final maps = await db.query(
      'expenses',
      where: "date(created_at) = ?",
      whereArgs: [today],
      orderBy: 'created_at DESC, id DESC',
    );

    return maps.map((map) => Expense.fromMap(map)).toList();
  }

  /// サイクル内の昨日までの支出合計を取得（SQL集計）
  ///
  /// [cycleStartDate] サイクル開始日
  /// 返り値: サイクル開始日から昨日までの支出合計
  Future<int> getExpenseTotalUntilYesterday({
    required DateTime cycleStartDate,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final today = _formatDateOnly(now);
    final startStr = _formatDateOnly(cycleStartDate);

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date(created_at) >= ? AND date(created_at) < ?
    ''', [startStr, today]);

    return result.first['total'] as int;
  }

  /// サイクル内の支出合計を取得（SQL集計）
  ///
  /// [cycleStartDate] サイクル開始日
  /// [cycleEndDate] サイクル終了日
  Future<int> getCycleTotalExpenses({
    required DateTime cycleStartDate,
    required DateTime cycleEndDate,
  }) async {
    final db = await database;
    final startStr = _formatDateOnly(cycleStartDate);
    // endDateは当日を含むため、翌日未満とする
    final endDate = cycleEndDate.add(const Duration(days: 1));
    final endStr = _formatDateOnly(endDate);

    final result = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total
      FROM expenses
      WHERE date(created_at) >= ? AND date(created_at) < ?
    ''', [startStr, endStr]);

    return result.first['total'] as int;
  }

  /// カテゴリ別統計を取得（SQL集計）
  ///
  /// 「その他」カテゴリは除外
  /// 返り値: List<{
  ///   'category': String,
  ///   'total_amount': int,
  ///   'expense_count': int,
  ///   'saving_amount': int,
  ///   'standard_amount': int,
  ///   'reward_amount': int,
  /// }>
  Future<List<Map<String, dynamic>>> getCategoryStats({
    required DateTime cycleStartDate,
    required DateTime cycleEndDate,
  }) async {
    final db = await database;
    final startStr = _formatDateOnly(cycleStartDate);
    final endDate = cycleEndDate.add(const Duration(days: 1));
    final endStr = _formatDateOnly(endDate);

    final results = await db.rawQuery('''
      SELECT
        category,
        SUM(amount) as total_amount,
        COUNT(*) as expense_count,
        SUM(CASE WHEN grade = 'saving' THEN amount ELSE 0 END) as saving_amount,
        SUM(CASE WHEN grade = 'standard' THEN amount ELSE 0 END) as standard_amount,
        SUM(CASE WHEN grade = 'reward' THEN amount ELSE 0 END) as reward_amount,
        SUM(CASE WHEN grade = 'saving' THEN 1 ELSE 0 END) as saving_count,
        SUM(CASE WHEN grade = 'standard' THEN 1 ELSE 0 END) as standard_count,
        SUM(CASE WHEN grade = 'reward' THEN 1 ELSE 0 END) as reward_count
      FROM expenses
      WHERE date(created_at) >= ? AND date(created_at) < ?
        AND category != 'その他'
      GROUP BY category
      ORDER BY total_amount DESC
    ''', [startStr, endStr]);

    return results.map((row) => {
      'category': row['category'] as String,
      'total_amount': row['total_amount'] as int,
      'expense_count': row['expense_count'] as int,
      'saving_amount': row['saving_amount'] as int,
      'standard_amount': row['standard_amount'] as int,
      'reward_amount': row['reward_amount'] as int,
      'saving_count': row['saving_count'] as int,
      'standard_count': row['standard_count'] as int,
      'reward_count': row['reward_count'] as int,
    }).toList();
  }
}
