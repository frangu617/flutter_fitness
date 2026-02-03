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
  final ScrollController _workoutsScrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  String? _dayTitle;

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
    await _loadDayTitle();
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

  Future<void> _loadDayTitle() async {
    final title = await _db.fetchDayTitle(_todayDate);
    if (!mounted) {
      return;
    }
    setState(() {
      _dayTitle = title;
      _titleController.text = title ?? '';
    });
  }

  Future<void> _saveDayTitle() async {
    final title = _titleController.text.trim();
    await _db.setDayTitle(
      date: _todayDate,
      title: title.isEmpty ? null : title,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _dayTitle = title.isEmpty ? null : title;
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
    _scrollToLatestWorkout();
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
      await _addWorkout(newWorkout);
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

  void _scrollToLatestWorkout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_workoutsScrollController.hasClients) {
        return;
      }
      final position = _workoutsScrollController.position;
      if (position.maxScrollExtent <= 0) {
        return;
      }
      _workoutsScrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _workoutsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).viewPadding.bottom;
    const fabSize = 56.0;
    final listBottomPadding =
        bottomSafeArea + kFloatingActionButtonMargin + fabSize + 24;
    return Scaffold(
      appBar: AppBar(title: const Text("Today's Workout")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Workout title (optional)',
                      hintText: 'Leg Day, Chest Day, Back Day...',
                      prefixIcon: const Icon(Icons.edit),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.save),
                        tooltip: 'Save title',
                        onPressed: _saveDayTitle,
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _saveDayTitle(),
                  ),
                ),
                if (_dayTitle != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _dayTitle!,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ],
                Expanded(
                  child: _workouts.isEmpty
                      ? const Center(child: Text('No workouts logged yet.'))
                      : ReorderableListView.builder(
                          scrollController: _workoutsScrollController,
                          padding: EdgeInsets.fromLTRB(
                            16,
                            12,
                            16,
                            listBottomPadding,
                          ),
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
                            final isCompleted =
                                _completedWorkouts.contains(workout.id);
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
                                  await _db.insertSet(
                                    workoutId: workout.id,
                                    set: newSet,
                                  );
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
                                onSave: (distance, time, calories) async {
                                  await _db.updateCardioWorkout(
                                    workoutId: workout.id,
                                    distance: distance,
                                    time: time,
                                    calories: calories,
                                  );
                                  if (!mounted) {
                                    return;
                                  }
                                  setState(() {
                                    final index = _workouts.indexWhere(
                                      (item) => item.id == workout.id,
                                    );
                                    if (index != -1) {
                                      _workouts[index] = CardioWorkout(
                                        id: workout.id,
                                        name: workout.name,
                                        distance: distance,
                                        time: time,
                                        calories: calories,
                                      );
                                    }
                                  });
                                },
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                ),
              ],
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
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Workout Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Workout Type',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Cardio'),
                value: _type == WorkoutType.cardio,
                onChanged: (value) {
                  if (value ?? false) {
                    setState(() {
                      _type = WorkoutType.cardio;
                    });
                  }
                },
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Strength'),
                value: _type == WorkoutType.strength,
                onChanged: (value) {
                  if (value ?? false) {
                    setState(() {
                      _type = WorkoutType.strength;
                    });
                  }
                },
              ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseCardColor =
        isDark ? const Color(0xFF0B3D91) : Colors.blue.shade400;
    final completedCardColor =
        isDark ? const Color(0xFF0A337A) : Colors.blue.shade500;
    final cardColor =
        widget.isCompleted ? completedCardColor : baseCardColor;
    final textColor = Colors.yellowAccent.shade400;
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: textColor),
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
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: textColor),
              ),
              const SizedBox(height: 8.0),
              ...widget.workout.sets.map((set) {
                final label = set.isBodyweight
                    ? 'Reps: ${set.reps}, Weight: Body weight'
                    : 'Reps: ${set.reps}, Weight: ${set.weight} lbs';
                return Text(
                  label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: textColor),
                );
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
                            decoration: InputDecoration(
                              labelText: 'Reps',
                              labelStyle: TextStyle(color: textColor),
                              floatingLabelStyle: TextStyle(color: textColor),
                            ),
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
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
                            decoration: InputDecoration(
                              labelText: 'Weight (lbs)',
                              labelStyle: TextStyle(color: textColor),
                              floatingLabelStyle: TextStyle(color: textColor),
                            ),
                            keyboardType: TextInputType.number,
                            enabled: !_isBodyweight,
                            style: TextStyle(color: textColor),
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
                      title: Text(
                        'Body weight',
                        style: TextStyle(color: textColor),
                      ),
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

class _CardioWorkoutListItem extends StatefulWidget {
  final CardioWorkout workout;
  final VoidCallback onDelete;
  final bool isCompleted;
  final ValueChanged<bool> onCompletedChanged;
  final Widget dragHandle;
  final void Function(double? distance, int? time, int? calories) onSave;

  const _CardioWorkoutListItem({
    required this.workout,
    required this.onDelete,
    required this.isCompleted,
    required this.onCompletedChanged,
    required this.dragHandle,
    required this.onSave,
    super.key,
  });

  @override
  State<_CardioWorkoutListItem> createState() => _CardioWorkoutListItemState();
}

class _CardioWorkoutListItemState extends State<_CardioWorkoutListItem> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _distanceController;
  late TextEditingController _durationController;
  late TextEditingController _caloriesController;

  @override
  void initState() {
    super.initState();
    _distanceController = TextEditingController(
      text: widget.workout.distance?.toString() ?? '',
    );
    _durationController = TextEditingController(
      text: widget.workout.time?.toString() ?? '',
    );
    _caloriesController = TextEditingController(
      text: widget.workout.calories?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _CardioWorkoutListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workout.distance != widget.workout.distance) {
      _distanceController.text = widget.workout.distance?.toString() ?? '';
    }
    if (oldWidget.workout.time != widget.workout.time) {
      _durationController.text = widget.workout.time?.toString() ?? '';
    }
    if (oldWidget.workout.calories != widget.workout.calories) {
      _caloriesController.text = widget.workout.calories?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _distanceController.dispose();
    _durationController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  String? _validateDouble(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim()) == null ? 'Enter a number' : null;
  }

  String? _validateInt(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return int.tryParse(value.trim()) == null ? 'Enter a whole number' : null;
  }

  void _saveDetails() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final distanceText = _distanceController.text.trim();
    final durationText = _durationController.text.trim();
    final caloriesText = _caloriesController.text.trim();
    final distance =
        distanceText.isEmpty ? null : double.tryParse(distanceText);
    final duration = durationText.isEmpty ? null : int.tryParse(durationText);
    final calories = caloriesText.isEmpty ? null : int.tryParse(caloriesText);
    widget.onSave(distance, duration, calories);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseCardColor =
        isDark ? const Color(0xFF0B3D91) : Colors.blue.shade400;
    final completedCardColor =
        isDark ? const Color(0xFF0A337A) : Colors.blue.shade500;
    final cardColor =
        widget.isCompleted ? completedCardColor : baseCardColor;
    final textColor = Colors.yellowAccent.shade400;
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
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: textColor),
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
                'Type: Cardio',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: textColor),
              ),
              const SizedBox(height: 8.0),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _distanceController,
                            decoration: InputDecoration(
                              labelText: 'Distance (miles)',
                              labelStyle: TextStyle(color: textColor),
                              floatingLabelStyle: TextStyle(color: textColor),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: TextStyle(color: textColor),
                            validator: _validateDouble,
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: InputDecoration(
                              labelText: 'Duration (min)',
                              labelStyle: TextStyle(color: textColor),
                              floatingLabelStyle: TextStyle(color: textColor),
                            ),
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: textColor),
                            validator: _validateInt,
                          ),
                        ),
                        IconButton(
                          key: const Key('save_cardio_button'),
                          icon: const Icon(Icons.save),
                          tooltip: 'Save cardio details',
                          onPressed: _saveDetails,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    TextFormField(
                      controller: _caloriesController,
                      decoration: InputDecoration(
                        labelText: 'Calories burned (optional)',
                        labelStyle: TextStyle(color: textColor),
                        floatingLabelStyle: TextStyle(color: textColor),
                      ),
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: textColor),
                      validator: _validateInt,
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
