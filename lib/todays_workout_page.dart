import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_fitness/data/workout_database.dart';
import 'package:flutter_fitness/models/workout.dart';

class TodaysWorkoutPage extends StatefulWidget {
  const TodaysWorkoutPage({super.key, this.autoOpenAdd = false});

  final bool autoOpenAdd;

  @override
  State<TodaysWorkoutPage> createState() => _TodaysWorkoutPageState();
}

class _TodaysWorkoutPageState extends State<TodaysWorkoutPage> {
  final WorkoutDatabase _db = WorkoutDatabase.instance;
  late final DateTime _todayDate;
  List<Workout> _workouts = [];
  bool _isLoading = true;
  final Set<String> _completedWorkouts = {};

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayDate = DateTime(now.year, now.month, now.day);
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    final workouts = await _db.fetchWorkoutsForDate(_todayDate);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = workouts;
      _isLoading = false;
    });
    await _loadCompletionState();
    if (widget.autoOpenAdd) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showAddWorkoutDialog();
        }
      });
    }
  }

  Future<void> _loadCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'completed_workouts_${_dateKey(_todayDate)}';
    final stored = prefs.getStringList(key) ?? <String>[];
    final workoutIds = _workouts.map((workout) => workout.id).toSet();
    final filtered = stored.where(workoutIds.contains).toSet();
    if (!mounted) {
      return;
    }
    setState(() {
      _completedWorkouts
        ..clear()
        ..addAll(filtered);
    });
  }

  Future<void> _saveCompletionState() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'completed_workouts_${_dateKey(_todayDate)}';
    await prefs.setStringList(key, _completedWorkouts.toList());
  }

  Future<void> _addWorkout(Workout workout) async {
    await _db.insertWorkout(date: _todayDate, workout: workout);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = [..._workouts, workout];
    });
    await _saveCompletionState();
  }

  Future<void> _deleteWorkout(String id) async {
    await _db.deleteWorkout(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts.removeWhere((workout) => workout.id == id);
      _completedWorkouts.remove(id);
    });
    await _saveCompletionState();
  }

  Future<void> _showAddWorkoutDialog() async {
    final newWorkout = await showDialog<Workout>(
      context: context,
      builder: (context) => const _AddWorkoutForm(),
    );
    if (newWorkout != null) {
      _addWorkout(newWorkout);
    }
  }

  void _toggleCompleted(String id, bool isCompleted) {
    setState(() {
      if (isCompleted) {
        _completedWorkouts.add(id);
      } else {
        _completedWorkouts.remove(id);
      }
    });
    _saveCompletionState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Workout")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
          ? const Center(child: Text('No workouts logged yet.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              buildDefaultDragHandles: false,
              itemCount: _workouts.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _workouts.removeAt(oldIndex);
                  _workouts.insert(newIndex, item);
                });
              },
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                final isCompleted = _completedWorkouts.contains(workout.id);
                final dragHandle = ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                );
                if (workout is StrengthWorkout) {
                  return _StrengthWorkoutListItem(
                    key: ValueKey(workout.id),
                    workout: workout,
                    isCompleted: isCompleted,
                    dragHandle: dragHandle,
                    onCompletedChanged: (value) =>
                        _toggleCompleted(workout.id, value),
                    onDelete: () => _deleteWorkout(workout.id),
                    onAddSet: (reps, weight, isBodyweight) async {
                      final newSet = WorkoutSet(
                        reps: reps,
                        weight: weight,
                        isBodyweight: isBodyweight,
                      );
                      await _db.insertSet(workoutId: workout.id, set: newSet);
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        workout.sets.add(newSet);
                      });
                    },
                  );
                }
                if (workout is CardioWorkout) {
                  return _CardioWorkoutListItem(
                    key: ValueKey(workout.id),
                    workout: workout,
                    isCompleted: isCompleted,
                    dragHandle: dragHandle,
                    onCompletedChanged: (value) =>
                        _toggleCompleted(workout.id, value),
                    onDelete: () => _deleteWorkout(workout.id),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkoutDialog,
        tooltip: 'Add exercise',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _AddWorkoutForm extends StatefulWidget {
  const _AddWorkoutForm();

  @override
  State<_AddWorkoutForm> createState() => _AddWorkoutFormState();
}

class _AddWorkoutFormState extends State<_AddWorkoutForm> {
  final _formKey = GlobalKey<FormState>();
  String _name = '';
  WorkoutType _type = WorkoutType.cardio;
  double? _distance;
  int? _time;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Workout'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Workout Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),
              DropdownButtonFormField<WorkoutType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Workout Type'),
                items: WorkoutType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.toString().split('.').last[0].toUpperCase() +
                              type.toString().split('.').last.substring(1),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                    });
                  }
                },
              ),
              if (_type == WorkoutType.cardio) ...[
                TextFormField(
                  key: const Key('distance_field'),
                  decoration: const InputDecoration(
                    labelText: 'Distance (miles)',
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _distance = double.tryParse(value ?? ''),
                ),
                TextFormField(
                  key: const Key('time_field'),
                  decoration: const InputDecoration(
                    labelText: 'Time (minutes)',
                  ),
                  keyboardType: TextInputType.number,
                  onSaved: (value) => _time = int.tryParse(value ?? ''),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              final id = DateTime.now().toString();
              Workout newWorkout;
              if (_type == WorkoutType.cardio) {
                newWorkout = CardioWorkout(
                  id: id,
                  name: _name,
                  distance: _distance,
                  time: _time,
                );
              } else {
                newWorkout = StrengthWorkout(id: id, name: _name);
              }
              Navigator.of(context).pop(newWorkout);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _StrengthWorkoutListItem extends StatefulWidget {
  final StrengthWorkout workout;
  final VoidCallback onDelete;
  final void Function(int reps, double? weight, bool isBodyweight) onAddSet;
  final bool isCompleted;
  final ValueChanged<bool> onCompletedChanged;
  final Widget dragHandle;

  const _StrengthWorkoutListItem({
    required this.workout,
    required this.onDelete,
    required this.onAddSet,
    required this.isCompleted,
    required this.onCompletedChanged,
    required this.dragHandle,
    super.key,
  });

  @override
  State<_StrengthWorkoutListItem> createState() =>
      _StrengthWorkoutListItemState();
}

class _StrengthWorkoutListItemState extends State<_StrengthWorkoutListItem> {
  final _formKey = GlobalKey<FormState>();
  int _reps = 0;
  double? _weight;
  bool _isBodyweight = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = widget.isCompleted
        ? colorScheme.primary.withAlpha(46)
        : colorScheme.surface;
    final contentOpacity = widget.isCompleted ? 0.6 : 1.0;

    return Card(
      elevation: 0,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Opacity(
          opacity: contentOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: widget.isCompleted,
                    onChanged: (value) =>
                        widget.onCompletedChanged(value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      widget.workout.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  widget.dragHandle,
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                'Type: Strength',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8.0),
              ...widget.workout.sets.map((set) {
                if (set.isBodyweight) {
                  return Text('Reps: ${set.reps}, Weight: Body weight');
                }
                return Text('Reps: ${set.reps}, Weight: ${set.weight} lbs');
              }),
              const SizedBox(height: 8.0),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            decoration:
                                const InputDecoration(labelText: 'Reps'),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter reps';
                              }
                              return null;
                            },
                            onSaved: (value) => _reps = int.parse(value!),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              labelText: 'Weight (lbs)',
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !_isBodyweight,
                            validator: (value) {
                              if (!_isBodyweight &&
                                  (value == null || value.isEmpty)) {
                                return 'Enter weight';
                              }
                              return null;
                            },
                            onSaved: (value) => _weight = _isBodyweight
                                ? null
                                : double.parse(value!),
                          ),
                        ),
                        IconButton(
                          key: const Key('add_set_button'),
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              _formKey.currentState!.save();
                              widget.onAddSet(
                                _reps,
                                _weight,
                                _isBodyweight,
                              );
                              _formKey.currentState!.reset();
                              setState(() {
                                _isBodyweight = false;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    CheckboxListTile(
                      title: const Text('Body weight'),
                      value: _isBodyweight,
                      onChanged: (value) {
                        setState(() {
                          _isBodyweight = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardioWorkoutListItem extends StatelessWidget {
  final CardioWorkout workout;
  final VoidCallback onDelete;
  final bool isCompleted;
  final ValueChanged<bool> onCompletedChanged;
  final Widget dragHandle;

  const _CardioWorkoutListItem({
    required this.workout,
    required this.onDelete,
    required this.isCompleted,
    required this.onCompletedChanged,
    required this.dragHandle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardColor = isCompleted
        ? colorScheme.primary.withAlpha(46)
        : colorScheme.surface;
    final contentOpacity = isCompleted ? 0.6 : 1.0;

    final details = <String>[];
    if (workout.distance != null) {
      details.add('Distance: ${workout.distance} miles');
    }
    if (workout.time != null) {
      details.add('Time: ${workout.time} minutes');
    }

    return Card(
      elevation: 0,
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Opacity(
          opacity: contentOpacity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: isCompleted,
                    onChanged: (value) => onCompletedChanged(value ?? false),
                  ),
                  Expanded(
                    child: Text(
                      workout.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  dragHandle,
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                'Type: Cardio',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 8.0),
                ...details.map((detail) => Text(detail)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
