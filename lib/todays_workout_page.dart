import 'package:flutter/material.dart';
import 'package:flutter_fitness/data/workout_database.dart';
import 'package:flutter_fitness/models/workout.dart';

class TodaysWorkoutPage extends StatefulWidget {
  const TodaysWorkoutPage({super.key});

  @override
  State<TodaysWorkoutPage> createState() => _TodaysWorkoutPageState();
}

class _TodaysWorkoutPageState extends State<TodaysWorkoutPage> {
  final WorkoutDatabase _db = WorkoutDatabase.instance;
  late final DateTime _todayDate;
  List<Workout> _workouts = [];
  bool _isLoading = true;

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
  }

  Future<void> _addWorkout(Workout workout) async {
    await _db.insertWorkout(date: _todayDate, workout: workout);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts = [..._workouts, workout];
    });
  }

  Future<void> _deleteWorkout(String id) async {
    await _db.deleteWorkout(id);
    if (!mounted) {
      return;
    }
    setState(() {
      _workouts.removeWhere((workout) => workout.id == id);
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today\'s Workout')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
          ? const Center(child: Text('No workouts logged yet.'))
          : ListView.builder(
              itemCount: _workouts.length,
              itemBuilder: (context, index) {
                final workout = _workouts[index];
                if (workout is StrengthWorkout) {
                  return _StrengthWorkoutListItem(
                    workout: workout,
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
                } else if (workout is CardioWorkout) {
                  String subtitle = 'Type: Cardio\n';
                  if (workout.distance != null) {
                    subtitle += 'Distance: ${workout.distance} miles ';
                  }
                  if (workout.time != null) {
                    subtitle += 'Time: ${workout.time} minutes';
                  }
                  return ListTile(
                    title: Text(workout.name),
                    subtitle: Text(subtitle),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteWorkout(workout.id),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddWorkoutDialog,
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
                value: _type,
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

  const _StrengthWorkoutListItem({
    required this.workout,
    required this.onDelete,
    required this.onAddSet,
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
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.workout.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 8.0),
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
                          decoration: const InputDecoration(labelText: 'Reps'),
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
                            widget.onAddSet(_reps, _weight, _isBodyweight);
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
                        _isBodyweight = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
