import 'database_service.dart';

class SessionService {
  Future<int> createSession() async {
    final db = await DatabaseService.database;

    return db.insert(
      'sessions',
      {
        'started_at': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> endSession(int sessionId) async {
    final db = await DatabaseService.database;

    await db.update(
      'sessions',
      {
        'ended_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Map<String, dynamic>>> getSessions() async {
    final db = await DatabaseService.database;

    return db.query(
      'sessions',
      orderBy: 'id DESC',
    );
  }
}