import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';
import '../models/quick_entry.dart';

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
      version: 6,
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
        is_default INTEGER NOT NULL DEFAULT 0
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
  }

  // Expense CRUD
  Future<List<Expense>> getExpenses({DateTime? from, DateTime? to}) async {
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

    return maps.map((map) => Expense.fromMap(map)).toList();
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
}
