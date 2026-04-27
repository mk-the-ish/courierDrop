import "package:path/path.dart" as p;
import "package:sqflite/sqflite.dart";

class TrackingOutbox {
  static const _dbName = "dropcity_tracking.db";
  static const table = "tracking_outbox";
  static const deadLetterTable = "tracking_dead_letter";
  static const maxRows = 4000;

  Database? _db;

  Future<Database> _database() async {
    if (_db != null) {
      return _db!;
    }
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $table ADD COLUMN next_attempt_at TEXT DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE $table ADD COLUMN last_error TEXT DEFAULT ''",
          );
          await db.execute("""
            CREATE TABLE IF NOT EXISTS $deadLetterTable(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              parcel_id TEXT NOT NULL,
              lat REAL NOT NULL,
              lng REAL NOT NULL,
              accuracy REAL,
              timestamp TEXT NOT NULL,
              retry_count INTEGER NOT NULL,
              reason TEXT,
              created_at TEXT NOT NULL
            );
          """);
        }
      },
    );
    return _db!;
  }

  Future<void> _createSchema(Database db) async {
    await db.execute("""
      CREATE TABLE $table(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parcel_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy REAL,
        timestamp TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT NOT NULL,
        last_error TEXT,
        created_at TEXT NOT NULL
      );
    """);
    await db.execute(
      "CREATE INDEX idx_tracking_outbox_created_at ON $table(created_at);",
    );
    await db.execute(
      "CREATE INDEX idx_tracking_outbox_next_attempt ON $table(next_attempt_at);",
    );
    await db.execute("""
      CREATE TABLE $deadLetterTable(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        parcel_id TEXT NOT NULL,
        lat REAL NOT NULL,
        lng REAL NOT NULL,
        accuracy REAL,
        timestamp TEXT NOT NULL,
        retry_count INTEGER NOT NULL,
        reason TEXT,
        created_at TEXT NOT NULL
      );
    """);
  }

  Future<void> enqueue({
    required String parcelId,
    required double lat,
    required double lng,
    double? accuracy,
    required String timestampIso,
  }) async {
    final db = await _database();
    await db.insert(table, {
      "parcel_id": parcelId,
      "lat": lat,
      "lng": lng,
      "accuracy": accuracy,
      "timestamp": timestampIso,
      "retry_count": 0,
      "next_attempt_at": DateTime.now().toUtc().toIso8601String(),
      "created_at": DateTime.now().toUtc().toIso8601String(),
    });
    print("[TrackingOutbox.enqueue] QUEUED: parcelId=$parcelId, lat=$lat, lng=$lng");
    await _trimToLimit(db);
  }

  Future<List<Map<String, dynamic>>> fetchBatch({int limit = 100}) async {
    final db = await _database();
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await db.query(
      table,
      where: "next_attempt_at <= ? OR next_attempt_at = ''",
      whereArgs: [now],
      orderBy: "id ASC",
      limit: limit,
    );
    print("[TrackingOutbox.fetchBatch] FETCHED: ${rows.length} rows (limit=$limit)");
    return rows
        .map((row) => row.map((key, value) => MapEntry(key, value)))
        .toList();
  }

  Future<void> deleteByIds(List<int> ids) async {
    if (ids.isEmpty) {
      print("[TrackingOutbox.deleteByIds] SKIP: empty list");
      return;
    }
    final db = await _database();
    final placeholders = List.filled(ids.length, "?").join(",");
    await db.delete(table, where: "id IN ($placeholders)", whereArgs: ids);
    print("[TrackingOutbox.deleteByIds] DELETED: ${ids.length} rows");
  }

  Future<void> scheduleRetry(List<int> ids, {required String error}) async {
    if (ids.isEmpty) {
      print("[TrackingOutbox.scheduleRetry] SKIP: empty list");
      return;
    }
    print("[TrackingOutbox.scheduleRetry] START: ${ids.length} rows, error=$error");
    final db = await _database();
    int updatedCount = 0;
    for (final id in ids) {
      final rows = await db.query(
        table,
        columns: ["retry_count"],
        where: "id = ?",
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        continue;
      }
      final currentRetry = (rows.first["retry_count"] as int?) ?? 0;
      final nextRetry = currentRetry + 1;
      final delaySeconds = _delayForRetry(nextRetry);
      final nextAttemptAt = DateTime.now()
          .toUtc()
          .add(Duration(seconds: delaySeconds))
          .toIso8601String();
      await db.update(
        table,
        {
          "retry_count": nextRetry,
          "next_attempt_at": nextAttemptAt,
          "last_error": error,
        },
        where: "id = ?",
        whereArgs: [id],
      );
      updatedCount++;
    }
    print("[TrackingOutbox.scheduleRetry] COMPLETE: $updatedCount scheduled for retry");
  }

  int _delayForRetry(int retryCount) {
    // 5s, 10s, 20s, ... capped at 15 minutes.
    final base = 5 * (1 << (retryCount > 10 ? 10 : retryCount));
    return base.clamp(5, 900);
  }

  Future<void> moveToDeadLetter(List<int> ids, {required String reason}) async {
    if (ids.isEmpty) {
      print("[TrackingOutbox.moveToDeadLetter] SKIP: empty list");
      return;
    }
    print("[TrackingOutbox.moveToDeadLetter] START: ${ids.length} rows, reason=$reason");
    final db = await _database();
    final placeholders = List.filled(ids.length, "?").join(",");
    final rows = await db.query(
      table,
      where: "id IN ($placeholders)",
      whereArgs: ids,
    );
    if (rows.isNotEmpty) {
      final batch = db.batch();
      for (final row in rows) {
        batch.insert(deadLetterTable, {
          "parcel_id": row["parcel_id"],
          "lat": row["lat"],
          "lng": row["lng"],
          "accuracy": row["accuracy"],
          "timestamp": row["timestamp"],
          "retry_count": row["retry_count"] ?? 0,
          "reason": reason,
          "created_at": DateTime.now().toUtc().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
      print("[TrackingOutbox.moveToDeadLetter] MOVED: ${rows.length} rows to dead letter");
    }
    await deleteByIds(ids);
  }

  Future<void> removeOlderThan(Duration age) async {
    final db = await _database();
    final cutoff = DateTime.now().toUtc().subtract(age).toIso8601String();
    final count = await db.rawDelete("DELETE FROM $table WHERE timestamp < ?", [cutoff]);
    if (count > 0) {
      print("[TrackingOutbox.removeOlderThan] REMOVED: $count rows older than ${age.inHours}h");
    }
  }

  Future<int> count() async {
    final db = await _database();
    final result = await db.rawQuery("SELECT COUNT(*) AS c FROM $table");
    final c = (result.first["c"] as int?) ?? 0;
    print("[TrackingOutbox.count] Total=$c rows in queue");
    return c;
  }

  Future<int> deadLetterCount() async {
    final db = await _database();
    final result = await db.rawQuery(
      "SELECT COUNT(*) AS c FROM $deadLetterTable",
    );
    final c = (result.first["c"] as int?) ?? 0;
    print("[TrackingOutbox.deadLetterCount] Total=$c rows in dead letter");
    return c;
  }

  Future<void> _trimToLimit(Database db) async {
    final rows = await db.rawQuery("SELECT COUNT(*) AS c FROM $table");
    final count = (rows.first["c"] as int?) ?? 0;
    if (count <= maxRows) {
      return;
    }
    final toDelete = count - maxRows;
    print("[TrackingOutbox._trimToLimit] TRIMMING: removing $toDelete rows (count=$count, limit=$maxRows)");
    await db.execute("""
      DELETE FROM $table
      WHERE id IN (
        SELECT id FROM $table
        ORDER BY id ASC
        LIMIT $toDelete
      );
    """);
  }

  Future<void> close() async {
    print("[TrackingOutbox.close] Closing database");
    await _db?.close();
    _db = null;
  }
}
