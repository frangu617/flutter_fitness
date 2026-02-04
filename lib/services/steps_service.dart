import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

class StepsService {
  final Health _health = Health();
  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }
    try {
      await _health.configure();
      _configured = true;
    } catch (_) {
      return;
    }
  }

  Future<bool> _ensureAuthorized({required bool requestHistory}) async {
    if (kIsWeb) {
      return false;
    }
    await _ensureConfigured();
    if (!_configured) {
      return false;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final activityStatus = await Permission.activityRecognition.request();
        if (!activityStatus.isGranted) {
          return false;
        }
      }

      final types = [HealthDataType.STEPS];
      final permissions = [HealthDataAccess.READ];
      var hasPermissions =
          await _health.hasPermissions(types, permissions: permissions);
      if (hasPermissions != true) {
        hasPermissions =
            await _health.requestAuthorization(types, permissions: permissions);
      }
      if (hasPermissions != true) {
        return false;
      }

      if (requestHistory && defaultTargetPlatform == TargetPlatform.android) {
        final historyAuthorized = await _health.isHealthDataHistoryAuthorized();
        if (!historyAuthorized) {
          final granted = await _health.requestHealthDataHistoryAuthorization();
          if (!granted) {
            return false;
          }
        }
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  bool _needsHistoryPermission(DateTime start) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return start.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day));
  }

  Future<StepsReadResult> readStepsForDay(DateTime day) async {
    if (kIsWeb) {
      return const StepsReadResult(authorized: false);
    }
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final authorized =
        await _ensureAuthorized(requestHistory: _needsHistoryPermission(start));
    if (!authorized) {
      return const StepsReadResult(authorized: false);
    }
    try {
      final steps = await _health.getTotalStepsInInterval(start, end);
      return StepsReadResult(authorized: true, steps: steps);
    } catch (_) {
      return const StepsReadResult(authorized: true);
    }
  }

  Future<StepsHistoryResult> readStepsForRange(
    DateTime start,
    DateTime end,
  ) async {
    if (kIsWeb) {
      return const StepsHistoryResult(authorized: false, days: []);
    }
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);
    final authorized = await _ensureAuthorized(
      requestHistory: _needsHistoryPermission(startDate),
    );
    if (!authorized) {
      return const StepsHistoryResult(authorized: false, days: []);
    }

    final days = endDate.difference(startDate).inDays;
    final results = <StepsDay>[];
    for (var i = 0; i <= days; i += 1) {
      final day = startDate.add(Duration(days: i));
      try {
        final steps = await _health.getTotalStepsInInterval(
          day,
          day.add(const Duration(days: 1)),
        );
        results.add(StepsDay(date: day, steps: steps));
      } catch (_) {
        results.add(StepsDay(date: day, steps: null));
      }
    }

    return StepsHistoryResult(authorized: true, days: results);
  }
}

class StepsReadResult {
  final bool authorized;
  final int? steps;

  const StepsReadResult({required this.authorized, this.steps});
}

class StepsHistoryResult {
  final bool authorized;
  final List<StepsDay> days;

  const StepsHistoryResult({required this.authorized, required this.days});
}

class StepsDay {
  final DateTime date;
  final int? steps;

  const StepsDay({required this.date, required this.steps});
}
