import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/test_result.dart';
import '../models/user_profile.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('parkinson_tests.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // ← incrementado para migración
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    await db.execute('''
      CREATE TABLE test_results (
        id $idType,
        testType $textType,
        timestamp $textType,
        overallScore $realType,
        metrics $textType,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE user_profile (
        id $idType,
        name $textType,
        sex $textType,
        age INTEGER NOT NULL,
        height REAL,
        weight REAL,
        hasFamilyHistory INTEGER NOT NULL DEFAULT 0,
        hasTremor INTEGER NOT NULL DEFAULT 0,
        takingMedication INTEGER NOT NULL DEFAULT 0,
        medicationNotes TEXT,
        createdAt $textType
      )
    ''');
  }

  /// Migración: si el usuario ya tenía la app sin tabla de perfil
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_profile (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          sex TEXT NOT NULL,
          age INTEGER NOT NULL,
          height REAL,
          weight REAL,
          hasFamilyHistory INTEGER NOT NULL DEFAULT 0,
          hasTremor INTEGER NOT NULL DEFAULT 0,
          takingMedication INTEGER NOT NULL DEFAULT 0,
          medicationNotes TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
    }
  }

  // ─────────────────────────────────────────────
  // USER PROFILE
  // ─────────────────────────────────────────────

  Future<UserProfile> insertUserProfile(UserProfile profile) async {
    final db = await database;
    final id = await db.insert('user_profile', profile.toMap());
    return profile.copyWith(id: id);
  }

  /// Retorna el perfil guardado, o null si no existe aún.
  Future<UserProfile?> getUserProfile() async {
    final db = await database;
    final maps = await db.query('user_profile', limit: 1);
    if (maps.isEmpty) return null;
    return UserProfile.fromMap(maps.first);
  }

  Future<int> updateUserProfile(UserProfile profile) async {
    final db = await database;
    return db.update(
      'user_profile',
      profile.toMap(),
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> deleteUserProfile() async {
    final db = await database;
    return db.delete('user_profile');
  }

  // ─────────────────────────────────────────────
  // TEST RESULTS (sin cambios)
  // ─────────────────────────────────────────────

  Future<TestResult> insertTestResult(TestResult result) async {
    final db = await database;
    final id = await db.insert('test_results', result.toMap());
    return result.copyWith(id: id);
  }

  Future<TestResult?> getTestResult(int id) async {
    final db = await database;
    final maps = await db.query(
      'test_results',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) return TestResult.fromMap(maps.first);
    return null;
  }

  Future<List<TestResult>> getAllTestResults() async {
    final db = await database;
    final result = await db.query('test_results', orderBy: 'timestamp DESC');
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  Future<List<TestResult>> getTestResultsByType(String testType) async {
    final db = await database;
    final result = await db.query(
      'test_results',
      where: 'testType = ?',
      whereArgs: [testType],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  Future<List<TestResult>> getRecentTestResults(int limit) async {
    final db = await database;
    final result = await db.query(
      'test_results',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  Future<List<TestResult>> getTestResultsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final result = await db.query(
      'test_results',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  Future<Map<String, dynamic>> getTestStatistics(String testType) async {
    final results = await getTestResultsByType(testType);
    if (results.isEmpty) {
      return {'count': 0, 'average': 0.0, 'best': 0.0, 'worst': 0.0, 'lastScore': 0.0};
    }
    final scores = results.map((r) => r.overallScore).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    return {
      'count': results.length,
      'average': average,
      'best': scores.reduce((a, b) => a > b ? a : b),
      'worst': scores.reduce((a, b) => a < b ? a : b),
      'lastScore': results.first.overallScore,
    };
  }

  Future<int> updateTestResult(TestResult result) async {
    final db = await database;
    return db.update(
      'test_results',
      result.toMap(),
      where: 'id = ?',
      whereArgs: [result.id],
    );
  }

  Future<int> deleteTestResult(int id) async {
    final db = await database;
    return db.delete('test_results', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllTestResults() async {
    final db = await database;
    return db.delete('test_results');
  }

  Future<int> getTotalTestCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM test_results');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<Map<String, int>> getTestCountByType() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT testType, COUNT(*) as count
      FROM test_results
      GROUP BY testType
    ''');
    return Map.fromEntries(
      result.map((row) => MapEntry(row['testType'] as String, row['count'] as int)),
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

extension TestResultCopyWith on TestResult {
  TestResult copyWith({
    int? id,
    String? testType,
    DateTime? timestamp,
    double? overallScore,
    Map<String, dynamic>? metrics,
    String? notes,
  }) {
    return TestResult(
      id: id ?? this.id,
      testType: testType ?? this.testType,
      timestamp: timestamp ?? this.timestamp,
      overallScore: overallScore ?? this.overallScore,
      metrics: metrics ?? this.metrics,
      notes: notes ?? this.notes,
    );
  }
}
