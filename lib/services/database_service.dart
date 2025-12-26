import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../models/budget.dart';

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
      version: 1,
      onCreate: _onCreate,
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
      orderBy: 'created_at DESC',
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

  Future<void> deleteCategory(int id) async {
    final db = await database;
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
}
