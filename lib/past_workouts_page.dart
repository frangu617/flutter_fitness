import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_fitness/data/workout_database.dart';
import 'package:flutter_fitness/models/workout.dart';

class PastWorkoutsPage extends StatefulWidget {
  const PastWorkoutsPage({super.key});

  @override
  State<PastWorkoutsPage> createState() => _PastWorkoutsPageState();
}

class _PastWorkoutsPageState extends State<PastWorkoutsPage> {
  final WorkoutDatabase _db = WorkoutDatabase.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<String, int> _workoutCounts = {};
  Map<String, String> _dayTitles = {};
  String? _selectedTitle;
  List<Workout> _selectedWorkouts = [];
  bool _isLoadingMarks = true;
  bool _isLoadingWorkouts = true;

  @override
  void initState() {
    super.initState();
    _loadMonthMarks();
    _loadSelectedWorkouts();
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<void> _loadMonthMarks() async {
    setState(() {
      _isLoadingMarks = true;
    });
    final marks = await _db.fetchWorkoutCountsForMonth(
      year: _focusedDay.year,
      month: _focusedDay.month,
    );
    final titles = await _db.fetchDayTitlesForMonth(
      year: _focusedDay.year,
      month: _focusedDay.month,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _workoutCounts = marks;
      _dayTitles = titles;
      _isLoadingMarks = false;
    });
  }

  Future<void> _loadSelectedWorkouts() async {
    setState(() {
      _isLoadingWorkouts = true;
    });
    final workouts = await _db.fetchWorkoutsForDate(_selectedDay);
    final title = await _db.fetchDayTitle(_selectedDay);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedWorkouts = workouts;
      _selectedTitle = title;
      _isLoadingWorkouts = false;
    });
  }

  int _intensityFor(DateTime day) {
    final count = _workoutCounts[_dateKey(day)] ?? 0;
    if (count == 0) {
      return 0;
    }
    if (count == 1) {
      return 1;
    }
    if (count == 2) {
      return 2;
    }
    return 3;
  }

  Color _heatColor(Color base, int intensity) {
    if (intensity == 0) {
      return Colors.transparent;
    }
    if (intensity == 1) {
      return base.withAlpha(46);
    }
    if (intensity == 2) {
      return base.withAlpha(92);
    }
    return base.withAlpha(140);
  }

  String? _shortTitleFor(DateTime day) {
    final title = _dayTitles[_dateKey(day)];
    if (title == null) {
      return null;
    }
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length <= 10) {
      return trimmed;
    }
    return '${trimmed.substring(0, 10)}…';
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime day, {
    bool isOutside = false,
    bool isSelected = false,
    bool isToday = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final intensity = _isLoadingMarks ? 0 : _intensityFor(day);
    Color background = _heatColor(colorScheme.primary, intensity);
    if (isSelected) {
      background = colorScheme.primary;
    }
    if (isOutside && background != Colors.transparent) {
      background = background.withAlpha(30);
    }

    final textColor = isSelected
        ? colorScheme.onPrimary
        : isOutside
            ? colorScheme.onSurfaceVariant
            : colorScheme.onSurface;
    final shortTitle = _isLoadingMarks ? null : _shortTitleFor(day);

    return Container(
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: colorScheme.secondary, width: 1.4)
            : null,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${day.day}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
          ),
          if (shortTitle != null)
            Text(
              shortTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: textColor.withAlpha(200),
                    fontSize: 8,
                  ),
            ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Past Workouts')),
      body: Column(
        children: [
          TableCalendar(
            focusedDay: _focusedDay,
            firstDay: DateTime.now().subtract(const Duration(days: 365 * 5)),
            lastDay: DateTime.now().add(const Duration(days: 365 * 5)),
            selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
              _loadSelectedWorkouts();
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
              _loadMonthMarks();
            },
            calendarStyle: CalendarStyle(
              outsideTextStyle:
                  TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            headerStyle: const HeaderStyle(
              titleCentered: true,
              formatButtonVisible: false,
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day),
              outsideBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isOutside: true),
              todayBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isToday: true),
              selectedBuilder: (context, day, focusedDay) =>
                  _buildDayCell(context, day, isSelected: true),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatFullDate(_selectedDay),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_selectedWorkouts.length} workout${_selectedWorkouts.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          if (_selectedTitle != null && _selectedTitle!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _selectedTitle!,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          Expanded(
            child: _isLoadingWorkouts
                ? const Center(child: CircularProgressIndicator())
                : _selectedWorkouts.isEmpty
                    ? const Center(
                        child: Text('No workouts logged for this day.'),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _selectedWorkouts.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final workout = _selectedWorkouts[index];
                          return _WorkoutLogCard(workout: workout);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutLogCard extends StatelessWidget {
  final Workout workout;

  const _WorkoutLogCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    if (workout is StrengthWorkout) {
      return _StrengthWorkoutLogCard(workout: workout as StrengthWorkout);
    }
    if (workout is CardioWorkout) {
      return _CardioWorkoutLogCard(workout: workout as CardioWorkout);
    }
    return const SizedBox.shrink();
  }
}

class _StrengthWorkoutLogCard extends StatelessWidget {
  final StrengthWorkout workout;

  const _StrengthWorkoutLogCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Type: Strength',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            if (workout.sets.isEmpty)
              Text(
                'No sets logged yet.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...workout.sets.asMap().entries.map((entry) {
                final setIndex = entry.key + 1;
                final set = entry.value;
                final weightLabel = set.isBodyweight
                    ? 'Body weight'
                    : (set.weight == null
                        ? 'Weight not logged'
                        : '${set.weight} lbs');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('Set $setIndex: ${set.reps} reps - $weightLabel'),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CardioWorkoutLogCard extends StatelessWidget {
  final CardioWorkout workout;

  const _CardioWorkoutLogCard({required this.workout});

  @override
  Widget build(BuildContext context) {
    final details = <String>[];
    if (workout.distance != null) {
      details.add('${workout.distance} miles');
    }
    if (workout.time != null) {
      details.add('${workout.time} minutes');
    }
    if (workout.calories != null) {
      details.add('${workout.calories} cal');
    }

    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(workout.name),
        subtitle: Text(
          details.isEmpty
              ? 'No cardio details logged yet.'
              : details.join(' - '),
        ),
        leading: const Icon(Icons.directions_run),
      ),
    );
  }
}
