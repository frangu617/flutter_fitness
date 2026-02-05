import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_fitness/models/workout.dart';

class WorkoutDatabase {
  WorkoutDatabase._();

  static final WorkoutDatabase instance = WorkoutDatabase._();
  static bool _factoryInitialized = false;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    _ensureDatabaseFactory();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'workout_log.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  void _ensureDatabaseFactory() {
    if (_factoryInitialized) {
      return;
    }
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
    } else if (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    _factoryInitialized = true;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE workouts ('
      'id TEXT PRIMARY KEY, '
      'name TEXT NOT NULL, '
      'type TEXT NOT NULL, '
      'date_key TEXT NOT NULL, '
      'distance REAL, '
      'time_minutes INTEGER, '
      'calories INTEGER'
      ')',
    );
    await db.execute(
      'CREATE TABLE workout_day_titles ('
      'date_key TEXT PRIMARY KEY, '
      'title TEXT NOT NULL'
      ')',
    );
    await db.execute(
      'CREATE TABLE workout_sets ('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'workout_id TEXT NOT NULL, '
      'reps INTEGER NOT NULL, '
      'weight REAL, '
      'is_bodyweight INTEGER NOT NULL, '
      'FOREIGN KEY(workout_id) REFERENCES workouts(id) ON DELETE CASCADE'
      ')',
    );
    await db.execute(
      'CREATE INDEX idx_workouts_date_key ON workouts(date_key)',
    );
    await db.execute(
      'CREATE INDEX idx_workout_sets_workout_id ON workout_sets(workout_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE workouts ADD COLUMN calories INTEGER',
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        'CREATE TABLE workout_day_titles ('
        'date_key TEXT PRIMARY KEY, '
        'title TEXT NOT NULL'
        ')',
      );
    }
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> insertWorkout({
    required DateTime date,
    required Workout workout,
  }) async {
    final db = await database;
    final values = <String, Object?>{
      'id': workout.id,
      'name': workout.name,
      'type': workout.type.name,
      'date_key': _dateKey(date),
      'distance': workout is CardioWorkout ? workout.distance : null,
      'time_minutes': workout is CardioWorkout ? workout.time : null,
      'calories': workout is CardioWorkout ? workout.calories : null,
    };
    await db.insert(
      'workouts',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    if (workout is StrengthWorkout) {
      for (final set in workout.sets) {
        await insertSet(workoutId: workout.id, set: set);
      }
    }
  }

  Future<int> insertSet({
    required String workoutId,
    required WorkoutSet set,
  }) async {
    final db = await database;
    final id = await db.insert('workout_sets', <String, Object?>{
      'workout_id': workoutId,
      'reps': set.reps,
      'weight': set.weight,
      'is_bodyweight': set.isBodyweight ? 1 : 0,
    });
    return id;
  }

  Future<void> updateSet({required WorkoutSet set}) async {
    final setId = set.id;
    if (setId == null) {
      return;
    }
    final db = await database;
    await db.update(
      'workout_sets',
      <String, Object?>{
        'reps': set.reps,
        'weight': set.weight,
        'is_bodyweight': set.isBodyweight ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [setId],
    );
  }

  Future<void> deleteWorkout(String workoutId) async {
    final db = await database;
    await db.delete(
      'workout_sets',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
    await db.delete('workouts', where: 'id = ?', whereArgs: [workoutId]);
  }

  Future<void> setDayTitle({
    required DateTime date,
    String? title,
  }) async {
    final db = await database;
    final key = _dateKey(date);
    final trimmed = title?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await db.delete(
        'workout_day_titles',
        where: 'date_key = ?',
        whereArgs: [key],
      );
      return;
    }
    await db.insert(
      'workout_day_titles',
      <String, Object?>{
        'date_key': key,
        'title': trimmed,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> fetchDayTitle(DateTime date) async {
    final db = await database;
    final key = _dateKey(date);
    final rows = await db.query(
      'workout_day_titles',
      columns: ['title'],
      where: 'date_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['title'] as String?;
  }

  Future<Map<String, String>> fetchDayTitlesForMonth({
    required int year,
    required int month,
  }) async {
    final db = await database;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startKey = _dateKey(DateTime(year, month, 1));
    final endKey = _dateKey(DateTime(year, month, daysInMonth));
    final rows = await db.query(
      'workout_day_titles',
      columns: ['date_key', 'title'],
      where: 'date_key >= ? AND date_key <= ?',
      whereArgs: [startKey, endKey],
    );
    final titles = <String, String>{};
    for (final row in rows) {
      final key = row['date_key'] as String;
      final title = row['title'] as String? ?? '';
      if (title.trim().isNotEmpty) {
        titles[key] = title;
      }
    }
    return titles;
  }

  Future<void> updateCardioWorkout({
    required String workoutId,
    double? distance,
    int? time,
    int? calories,
  }) async {
    final db = await database;
    await db.update(
      'workouts',
      <String, Object?>{
        'distance': distance,
        'time_minutes': time,
        'calories': calories,
      },
      where: 'id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<List<Workout>> fetchWorkoutsForDate(DateTime date) async {
    final db = await database;
    final dateKey = _dateKey(date);
    final workoutRows = await db.query(
      'workouts',
      where: 'date_key = ?',
      whereArgs: [dateKey],
      orderBy: 'id ASC',
    );

    if (workoutRows.isEmpty) {
      return <Workout>[];
    }

    final strengthIds = <String>[];
    for (final row in workoutRows) {
      if (row['type'] == WorkoutType.strength.name) {
        strengthIds.add(row['id'] as String);
      }
    }

    final setsByWorkoutId = <String, List<WorkoutSet>>{};
    if (strengthIds.isNotEmpty) {
      final placeholders = List.filled(strengthIds.length, '?').join(', ');
      final setRows = await db.query(
        'workout_sets',
        where: 'workout_id IN ($placeholders)',
        whereArgs: strengthIds,
        orderBy: 'id ASC',
      );
      for (final row in setRows) {
        final id = row['id'] as int;
        final workoutId = row['workout_id'] as String;
        final reps = row['reps'] as int;
        final weightValue = row['weight'];
        final weight = weightValue == null ? null : weightValue as num;
        final isBodyweight = (row['is_bodyweight'] as int) == 1;
        setsByWorkoutId
            .putIfAbsent(workoutId, () => <WorkoutSet>[])
            .add(
              WorkoutSet(
                id: id,
                reps: reps,
                weight: weight?.toDouble(),
                isBodyweight: isBodyweight,
              ),
            );
      }
    }

    final workouts = <Workout>[];
    for (final row in workoutRows) {
      final id = row['id'] as String;
      final name = row['name'] as String;
      final type = row['type'] as String;
      if (type == WorkoutType.strength.name) {
        workouts.add(
          StrengthWorkout(
            id: id,
            name: name,
            sets: setsByWorkoutId[id] ?? <WorkoutSet>[],
          ),
        );
      } else {
        final distanceValue = row['distance'];
        final timeValue = row['time_minutes'];
        final caloriesValue = row['calories'];
        workouts.add(
          CardioWorkout(
            id: id,
            name: name,
            distance: distanceValue == null
                ? null
                : (distanceValue as num).toDouble(),
            time: timeValue == null ? null : timeValue as int,
            calories: caloriesValue == null
                ? null
                : (caloriesValue as num).toInt(),
          ),
        );
      }
    }
    return workouts;
  }

  Future<Set<String>> fetchDateKeysForMonth({
    required int year,
    required int month,
  }) async {
    final db = await database;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startKey = _dateKey(DateTime(year, month, 1));
    final endKey = _dateKey(DateTime(year, month, daysInMonth));
    final rows = await db.query(
      'workouts',
      columns: ['date_key'],
      distinct: true,
      where: 'date_key >= ? AND date_key <= ?',
      whereArgs: [startKey, endKey],
    );
    return rows.map((row) => row['date_key'] as String).toSet();
  }

  Future<Map<String, int>> fetchWorkoutCountsForMonth({
    required int year,
    required int month,
  }) async {
    final db = await database;
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startKey = _dateKey(DateTime(year, month, 1));
    final endKey = _dateKey(DateTime(year, month, daysInMonth));
    final rows = await db.rawQuery(
      'SELECT date_key, COUNT(*) AS count '
      'FROM workouts '
      'WHERE date_key >= ? AND date_key <= ? '
      'GROUP BY date_key',
      [startKey, endKey],
    );
    final counts = <String, int>{};
    for (final row in rows) {
      final key = row['date_key'] as String;
      final countValue = row['count'] as int? ?? 0;
      counts[key] = countValue;
    }
    return counts;
  }

  Future<Set<String>> fetchAllWorkoutDateKeys() async {
    final db = await database;
    final rows = await db.query(
      'workouts',
      columns: ['date_key'],
      distinct: true,
    );
    return rows.map((row) => row['date_key'] as String).toSet();
  }

  Future<double> fetchTotalWeightLifted() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT SUM(reps * weight) AS total '
      'FROM workout_sets '
      'WHERE is_bodyweight = 0 AND weight IS NOT NULL',
    );
    final value = rows.first['total'];
    if (value == null) {
      return 0;
    }
    return (value as num).toDouble();
  }

  Future<Map<String, Object?>> exportWorkoutBackup() async {
    final db = await database;
    final workouts = await db.query(
      'workouts',
      orderBy: 'date_key ASC, id ASC',
    );
    final sets = await db.query(
      'workout_sets',
      orderBy: 'id ASC',
    );
    final dayTitles = await db.query(
      'workout_day_titles',
      orderBy: 'date_key ASC',
    );

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'workouts': workouts.map(_sanitizeWorkoutRow).toList(),
      'sets': sets.map(_sanitizeSetRow).toList(),
      'day_titles': dayTitles.map(_sanitizeTitleRow).toList(),
    };
  }

  Future<void> restoreWorkoutBackup(Map<String, Object?> backup) async {
    final version = _parseOptionalInt(backup['version']);
    if (version != 1) {
      throw const FormatException('Unsupported backup version.');
    }

    final workouts = _castListOfMaps(backup['workouts'], 'workouts');
    final sets = _castListOfMaps(backup['sets'], 'sets');
    final dayTitles = _castListOfMaps(backup['day_titles'], 'day_titles');

    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('workout_sets');
      await txn.delete('workout_day_titles');
      await txn.delete('workouts');

      for (final workout in workouts) {
        await txn.insert(
          'workouts',
          _buildWorkoutInsert(workout),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final set in sets) {
        await txn.insert(
          'workout_sets',
          _buildSetInsert(set),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final title in dayTitles) {
        await txn.insert(
          'workout_day_titles',
          _buildDayTitleInsert(title),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Map<String, Object?> _sanitizeWorkoutRow(Map<String, Object?> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'type': row['type'],
      'date_key': row['date_key'],
      'distance': row['distance'],
      'time_minutes': row['time_minutes'],
      'calories': row['calories'],
    };
  }

  Map<String, Object?> _sanitizeSetRow(Map<String, Object?> row) {
    return {
      'id': row['id'],
      'workout_id': row['workout_id'],
      'reps': row['reps'],
      'weight': row['weight'],
      'is_bodyweight': row['is_bodyweight'],
    };
  }

  Map<String, Object?> _sanitizeTitleRow(Map<String, Object?> row) {
    return {
      'date_key': row['date_key'],
      'title': row['title'],
    };
  }

  List<Map<String, Object?>> _castListOfMaps(Object? value, String label) {
    if (value is! List) {
      throw FormatException('Missing or invalid $label section.');
    }
    return value.map((entry) {
      if (entry is! Map) {
        throw FormatException('Invalid entry in $label.');
      }
      return entry.map((key, value) => MapEntry(key.toString(), value));
    }).toList();
  }

  Map<String, Object?> _buildWorkoutInsert(Map<String, Object?> row) {
    final id = _requireString(row['id'], 'workout id');
    final name = _requireString(row['name'], 'workout name');
    final type = _requireString(row['type'], 'workout type');
    final dateKey = _requireString(row['date_key'], 'date key');
    final distance = _parseOptionalDouble(row['distance']);
    final timeMinutes = _parseOptionalInt(row['time_minutes']);
    final calories = _parseOptionalInt(row['calories']);

    return {
      'id': id,
      'name': name,
      'type': type,
      'date_key': dateKey,
      'distance': distance,
      'time_minutes': timeMinutes,
      'calories': calories,
    };
  }

  Map<String, Object?> _buildSetInsert(Map<String, Object?> row) {
    final workoutId = _requireString(row['workout_id'], 'set workout_id');
    final reps = _parseOptionalInt(row['reps']);
    if (reps == null) {
      throw const FormatException('Set reps is required.');
    }
    final weight = _parseOptionalDouble(row['weight']);
    final isBodyweight = _parseBoolToInt(row['is_bodyweight']);
    final id = _parseOptionalInt(row['id']);

    final values = <String, Object?>{
      'workout_id': workoutId,
      'reps': reps,
      'weight': weight,
      'is_bodyweight': isBodyweight,
    };
    if (id != null) {
      values['id'] = id;
    }
    return values;
  }

  Map<String, Object?> _buildDayTitleInsert(Map<String, Object?> row) {
    final dateKey = _requireString(row['date_key'], 'day title date');
    final title = row['title']?.toString() ?? '';
    return {
      'date_key': dateKey,
      'title': title,
    };
  }

  String _requireString(Object? value, String label) {
    final text = value?.toString();
    if (text == null || text.trim().isEmpty) {
      throw FormatException('Missing $label.');
    }
    return text;
  }

  int? _parseOptionalInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return int.tryParse(text);
  }

  double? _parseOptionalDouble(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    final text = value.toString().trim();
    if (text.isEmpty) {
      return null;
    }
    return double.tryParse(text);
  }

  int _parseBoolToInt(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is num) {
      return value == 0 ? 0 : 1;
    }
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') {
      return 1;
    }
    if (text == 'false' || text == '0' || text == 'no') {
      return 0;
    }
    throw const FormatException('Invalid bodyweight flag.');
  }
}
