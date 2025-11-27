import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/test_result.dart';

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
      version: 1,
      onCreate: _createDB,
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
  }

  // Insertar resultado
  Future<TestResult> insertTestResult(TestResult result) async {
    final db = await database;
    final id = await db.insert('test_results', result.toMap());
    return result.copyWith(id: id);
  }

  // Obtener resultado por ID
  Future<TestResult?> getTestResult(int id) async {
    final db = await database;
    final maps = await db.query(
      'test_results',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return TestResult.fromMap(maps.first);
    }
    return null;
  }

  // Obtener todos los resultados
  Future<List<TestResult>> getAllTestResults() async {
    final db = await database;
    const orderBy = 'timestamp DESC';
    final result = await db.query('test_results', orderBy: orderBy);
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  // Obtener resultados por tipo de test
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

  // Obtener últimos N resultados
  Future<List<TestResult>> getRecentTestResults(int limit) async {
    final db = await database;
    final result = await db.query(
      'test_results',
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  // Obtener resultados por rango de fechas
  Future<List<TestResult>> getTestResultsByDateRange(
      DateTime startDate,
      DateTime endDate,
      ) async {
    final db = await database;
    final result = await db.query(
      'test_results',
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
      ],
      orderBy: 'timestamp DESC',
    );
    return result.map((json) => TestResult.fromMap(json)).toList();
  }

  // Obtener estadísticas por tipo de test
  Future<Map<String, dynamic>> getTestStatistics(String testType) async {
    final db = await database;
    final results = await getTestResultsByType(testType);

    if (results.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'best': 0.0,
        'worst': 0.0,
        'lastScore': 0.0,
      };
    }

    final scores = results.map((r) => r.overallScore).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final best = scores.reduce((a, b) => a > b ? a : b);
    final worst = scores.reduce((a, b) => a < b ? a : b);

    return {
      'count': results.length,
      'average': average,
      'best': best,
      'worst': worst,
      'lastScore': results.first.overallScore,
    };
  }

  // Actualizar resultado
  Future<int> updateTestResult(TestResult result) async {
    final db = await database;
    return db.update(
      'test_results',
      result.toMap(),
      where: 'id = ?',
      whereArgs: [result.id],
    );
  }

  // Eliminar resultado
  Future<int> deleteTestResult(int id) async {
    final db = await database;
    return await db.delete(
      'test_results',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Eliminar todos los resultados
  Future<int> deleteAllTestResults() async {
    final db = await database;
    return await db.delete('test_results');
  }

  // Obtener conteo total
  Future<int> getTotalTestCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM test_results');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Obtener conteo por tipo
  Future<Map<String, int>> getTestCountByType() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT testType, COUNT(*) as count
      FROM test_results
      GROUP BY testType
    ''');

    return Map.fromEntries(
      result.map((row) => MapEntry(
        row['testType'] as String,
        row['count'] as int,
      )),
    );
  }

  // Cerrar base de datos
  Future<void> close() async {
    final db = await database;
    db.close();
  }
}

// Extensión para copiar TestResult con nuevos valores
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
