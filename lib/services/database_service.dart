import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';
import '../models/fixed_cost.dart';
import '../models/fixed_cost_category.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'savesmart.db');

    return await openDatabase(
      path,
      version: 3,
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
}
