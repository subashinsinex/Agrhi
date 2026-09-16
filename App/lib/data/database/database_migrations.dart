import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  static const version = 2;

  /// sqflite runs upgrades transactionally. Never reset user data to migrate.
  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var next = oldVersion + 1; next <= newVersion; next++) {
      switch (next) {
        case 2:
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_dar_user_date '
            'ON disease_analysis_results(user_id, created_at DESC)',
          );
        default:
          throw StateError('Missing database migration for version $next');
      }
    }
  }
}
