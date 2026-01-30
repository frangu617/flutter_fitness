import 'package:flutter/material.dart';
import 'package:flutter_fitness/data/workout_database.dart';
import 'package:flutter_fitness/models/workout.dart';

class PastWorkoutsPage extends StatefulWidget {
  const PastWorkoutsPage({super.key});

  @override
  State<PastWorkoutsPage> createState() => _PastWorkoutsPageState();
}

class _PastWorkoutsPageState extends State<PastWorkoutsPage> {
  final WorkoutDatabase _db = WorkoutDatabase.instance;
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  List<Workout> _selectedWorkouts = [];
  Set<String> _markedDateKeys = {};
  bool _isLoadingWorkouts = true;
  bool _isLoadingMarks = true;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const List<String> _weekdayNames = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadMonthMarks();
    _loadSelectedWorkouts();
  }

  void _shiftMonth(int offset) {
    final newMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    final daysInMonth = DateUtils.getDaysInMonth(newMonth.year, newMonth.month);
    final clampedDay = _selectedDate.day.clamp(1, daysInMonth);
    setState(() {
      _focusedMonth = DateTime(newMonth.year, newMonth.month);
      _selectedDate = DateTime(newMonth.year, newMonth.month, clampedDay);
    });
    _loadMonthMarks();
    _loadSelectedWorkouts();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMonthYear(DateTime date) {
    return '${_monthNames[date.month - 1]} ${date.year}';
  }

  String _formatFullDate(DateTime date) {
    return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
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
    final marks = await _db.fetchDateKeysForMonth(
      year: _focusedMonth.year,
      month: _focusedMonth.month,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _markedDateKeys = marks;
      _isLoadingMarks = false;
    });
  }

  Future<void> _loadSelectedWorkouts() async {
    setState(() {
      _isLoadingWorkouts = true;
    });
    final workouts = await _db.fetchWorkoutsForDate(_selectedDate);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedWorkouts = workouts;
      _isLoadingWorkouts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Past Workouts')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  _formatMonthYear(_focusedMonth),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => _shiftMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _weekdayNames
                  .map(
                    (label) => Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _CalendarGrid(
              focusedMonth: _focusedMonth,
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
                _loadSelectedWorkouts();
              },
              isSameDay: _isSameDay,
              hasWorkouts: (date) =>
                  !_isLoadingMarks && _markedDateKeys.contains(_dateKey(date)),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatFullDate(_selectedDate),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${_selectedWorkouts.length} workout${_selectedWorkouts.length == 1 ? '' : 's'}',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoadingWorkouts
                ? const Center(child: CircularProgressIndicator())
                : _selectedWorkouts.isEmpty
                ? const Center(child: Text('No workouts logged for this day.'))
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

class _CalendarGrid extends StatelessWidget {
  final DateTime focusedMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final bool Function(DateTime a, DateTime b) isSameDay;
  final bool Function(DateTime date) hasWorkouts;

  const _CalendarGrid({
    required this.focusedMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isSameDay,
    required this.hasWorkouts,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedMonth.year,
      focusedMonth.month,
    );
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final totalCells = ((startingWeekday + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.1,
      ),
      itemBuilder: (context, index) {
        final dayIndex = index - startingWeekday;
        if (dayIndex < 0 || dayIndex >= daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(
          focusedMonth.year,
          focusedMonth.month,
          dayIndex + 1,
        );
        final isSelected = isSameDay(date, selectedDate);
        final isToday = isSameDay(date, today);
        final marked = hasWorkouts(date);
        final backgroundColor = isSelected
            ? colorScheme.primary
            : Colors.transparent;
        final textColor = isSelected
            ? colorScheme.onPrimary
            : colorScheme.onSurface;
        final indicatorColor = isSelected
            ? colorScheme.onPrimary
            : colorScheme.secondary;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onDateSelected(date),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: isToday
                    ? Border.all(color: colorScheme.secondary, width: 1.5)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${dayIndex + 1}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (marked)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
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
