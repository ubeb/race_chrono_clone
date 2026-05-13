import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();

    return openDatabase(
      join(dbPath, 'telemetry.db'),
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started_at INTEGER,
            ended_at INTEGER
          )
        ''');

        await db.execute('''
          CREATE TABLE telemetry(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id INTEGER,
            timestamp INTEGER,
            latitude REAL,
            longitude REAL,
            speed REAL
          )
        ''');
      },
    );
  }
}