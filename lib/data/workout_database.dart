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
    return openDatabase(path, version: 1, onCreate: _onCreate);
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
      'time_minutes INTEGER'
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

  Future<void> insertSet({
    required String workoutId,
    required WorkoutSet set,
  }) async {
    final db = await database;
    await db.insert('workout_sets', <String, Object?>{
      'workout_id': workoutId,
      'reps': set.reps,
      'weight': set.weight,
      'is_bodyweight': set.isBodyweight ? 1 : 0,
    });
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
        final workoutId = row['workout_id'] as String;
        final reps = row['reps'] as int;
        final weightValue = row['weight'];
        final weight = weightValue == null ? null : weightValue as num;
        final isBodyweight = (row['is_bodyweight'] as int) == 1;
        setsByWorkoutId
            .putIfAbsent(workoutId, () => <WorkoutSet>[])
            .add(
              WorkoutSet(
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
        workouts.add(
          CardioWorkout(
            id: id,
            name: name,
            distance: distanceValue == null
                ? null
                : (distanceValue as num).toDouble(),
            time: timeValue == null ? null : timeValue as int,
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
}
