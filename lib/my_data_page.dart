import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_fitness/data/workout_database.dart';
import 'package:flutter_fitness/models/workout.dart';
import 'package:flutter_fitness/services/steps_service.dart';

enum WeightUnit { kg, lb }
enum HeightUnit { cm, ftIn }

class MyDataPage extends StatefulWidget {
  const MyDataPage({super.key});

  @override
  State<MyDataPage> createState() => _MyDataPageState();
}

class _WeightEntry {
  final DateTime date;
  final double weightKg;

  const _WeightEntry({required this.date, required this.weightKg});
}

class _MyDataPageState extends State<MyDataPage> {
  final WorkoutDatabase _db = WorkoutDatabase.instance;
  final StepsService _stepsService = StepsService();
  final _nameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightCmController = TextEditingController();
  final _heightFtController = TextEditingController();
  final _heightInController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _restingHrController = TextEditingController();
  final _trainingDaysController = TextEditingController();
  final _plannedWeeklyController = TextEditingController();

  DateTime? _birthDate;
  String? _sex;
  String? _goal;
  String? _activityLevel;
  WeightUnit _weightUnit = WeightUnit.kg;
  HeightUnit _heightUnit = HeightUnit.cm;

  bool _isLoading = true;
  bool _isLoadingStats = true;
  bool _isLoadingSteps = true;
  bool _stepsAuthorized = true;
  bool _isOnboarding = false;
  int _currentStep = 0;

  double _hoursThisWeek = 0;
  int _currentStreak = 0;
  double _totalWeightLifted = 0;
  List<_WeightEntry> _weightHistory = [];
  List<StepsDay> _stepsHistory = [];

  static const double _lbPerKg = 2.2046226218;
  static const double _cmPerInch = 2.54;

  static const List<String> _sexOptions = <String>[
    'Female',
    'Male',
    'Prefer not to say',
  ];

  static const List<String> _goalOptions = <String>[
    'Lose fat',
    'Maintain weight',
    'Build muscle',
    'Improve endurance',
  ];

  static const List<String> _activityOptions = <String>[
    'Sedentary',
    'Lightly active',
    'Moderately active',
    'Very active',
    'Athlete',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _birthDateController.dispose();
    _weightController.dispose();
    _heightCmController.dispose();
    _heightFtController.dispose();
    _heightInController.dispose();
    _bodyFatController.dispose();
    _restingHrController.dispose();
    _trainingDaysController.dispose();
    _plannedWeeklyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('profile_completed') ?? false;

    _nameController.text = prefs.getString('profile_name') ?? '';

    final birthValue = prefs.getString('profile_birth');
    if (birthValue != null && birthValue.isNotEmpty) {
      final parsed = DateTime.tryParse(birthValue);
      if (parsed != null) {
        _birthDate = parsed;
        _birthDateController.text = _formatDate(parsed);
      }
    }

    _sex = prefs.getString('profile_sex');
    _goal = prefs.getString('profile_goal');
    _activityLevel = prefs.getString('profile_activity_level');

    final storedWeightUnit = prefs.getString('profile_weight_unit');
    _weightUnit = WeightUnit.values.firstWhere(
      (unit) => unit.name == storedWeightUnit,
      orElse: () => WeightUnit.kg,
    );

    final storedHeightUnit = prefs.getString('profile_height_unit');
    _heightUnit = HeightUnit.values.firstWhere(
      (unit) => unit.name == storedHeightUnit,
      orElse: () => HeightUnit.cm,
    );

    final weightKg = prefs.getDouble('profile_weight_kg');
    if (weightKg != null) {
      _setWeightFromKg(weightKg);
    }

    final heightCm = prefs.getDouble('profile_height_cm');
    if (heightCm != null) {
      _setHeightFromCm(heightCm);
    }

    final bodyFat = prefs.getDouble('profile_body_fat');
    if (bodyFat != null) {
      _bodyFatController.text = _formatNumber(bodyFat);
    }

    final restingHr = prefs.getInt('profile_resting_hr');
    if (restingHr != null) {
      _restingHrController.text = restingHr.toString();
    }

    final trainingDays = prefs.getInt('profile_training_days');
    if (trainingDays != null) {
      _trainingDaysController.text = trainingDays.toString();
    }

    final plannedWeekly = prefs.getInt('profile_planned_weekly');
    if (plannedWeekly != null) {
      _plannedWeeklyController.text = plannedWeekly.toString();
    }

    await _loadWeightHistory(prefs);

    if (mounted) {
      setState(() {
        _isOnboarding = !completed;
        _isLoading = false;
      });
    }
    _loadStats();
    _loadStepsHistory();
  }

  Future<void> _loadWeightHistory(SharedPreferences prefs) async {
    final raw = prefs.getString('profile_weight_history');
    if (raw == null || raw.isEmpty) {
      _weightHistory = [];
      return;
    }
    try {
      final data = jsonDecode(raw);
      if (data is! List) {
        _weightHistory = [];
        return;
      }
      final entries = <_WeightEntry>[];
      for (final item in data) {
        if (item is Map) {
          final dateValue = item['date'];
          final weightValue = item['weightKg'];
          if (dateValue is String && weightValue is num) {
            final parsedDate = DateTime.tryParse(dateValue);
            if (parsedDate != null) {
              entries.add(
                _WeightEntry(
                  date: parsedDate,
                  weightKg: weightValue.toDouble(),
                ),
              );
            }
          }
        }
      }
      entries.sort((a, b) => a.date.compareTo(b.date));
      _weightHistory = entries;
    } catch (_) {
      _weightHistory = [];
    }
  }

  Future<void> _updateWeightHistory(double weightKg) async {
    final prefs = await SharedPreferences.getInstance();
    await _loadWeightHistory(prefs);

    final todayKey = _formatDate(DateTime.now());
    final updated = _weightHistory
        .where((entry) => _formatDate(entry.date) != todayKey)
        .toList();

    updated.add(_WeightEntry(date: DateTime.now(), weightKg: weightKg));
    updated.sort((a, b) => a.date.compareTo(b.date));
    _weightHistory = updated;

    final data = updated
        .map(
          (entry) => {
            'date': _formatDate(entry.date),
            'weightKg': entry.weightKg,
          },
        )
        .toList();
    await prefs.setString('profile_weight_history', jsonEncode(data));
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    double totalMinutes = 0;
    for (var i = 0; i < 7; i += 1) {
      final date = startOfWeek.add(Duration(days: i));
      final workouts = await _db.fetchWorkoutsForDate(date);
      for (final workout in workouts) {
        if (workout is CardioWorkout && workout.time != null) {
          totalMinutes += workout.time!.toDouble();
        }
      }
    }

    final dateKeys = await _db.fetchAllWorkoutDateKeys();
    var streak = 0;
    var cursor = DateTime(now.year, now.month, now.day);
    while (dateKeys.contains(_dateKey(cursor))) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    final totalWeight = await _db.fetchTotalWeightLifted();

    if (!mounted) {
      return;
    }

    setState(() {
      _hoursThisWeek = totalMinutes / 60.0;
      _currentStreak = streak;
      _totalWeightLifted = totalWeight;
      _isLoadingStats = false;
    });
  }

  Future<void> _saveProfile({required bool completed}) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('profile_completed', completed);
    await prefs.setString('profile_name', _nameController.text.trim());
    await prefs.setString('profile_weight_unit', _weightUnit.name);
    await prefs.setString('profile_height_unit', _heightUnit.name);

    if (_birthDate != null) {
      await prefs.setString('profile_birth', _formatDate(_birthDate!));
    } else {
      await prefs.remove('profile_birth');
    }

    if (_sex != null) {
      await prefs.setString('profile_sex', _sex!);
    } else {
      await prefs.remove('profile_sex');
    }

    if (_goal != null) {
      await prefs.setString('profile_goal', _goal!);
    } else {
      await prefs.remove('profile_goal');
    }

    if (_activityLevel != null) {
      await prefs.setString('profile_activity_level', _activityLevel!);
    } else {
      await prefs.remove('profile_activity_level');
    }

    final weightKg = _weightKg;
    if (weightKg != null) {
      await prefs.setDouble('profile_weight_kg', weightKg);
      await _updateWeightHistory(weightKg);
    } else {
      await prefs.remove('profile_weight_kg');
    }

    final heightCm = _heightCm;
    if (heightCm != null) {
      await prefs.setDouble('profile_height_cm', heightCm);
    } else {
      await prefs.remove('profile_height_cm');
    }

    final bodyFat = _parseDouble(_bodyFatController.text);
    if (bodyFat != null) {
      await prefs.setDouble('profile_body_fat', bodyFat);
    } else {
      await prefs.remove('profile_body_fat');
    }

    final restingHr = _parseInt(_restingHrController.text);
    if (restingHr != null) {
      await prefs.setInt('profile_resting_hr', restingHr);
    } else {
      await prefs.remove('profile_resting_hr');
    }

    final trainingDays = _parseInt(_trainingDaysController.text);
    if (trainingDays != null) {
      await prefs.setInt('profile_training_days', trainingDays);
    } else {
      await prefs.remove('profile_training_days');
    }

    final plannedWeekly = _parseInt(_plannedWeeklyController.text);
    if (plannedWeekly != null) {
      await prefs.setInt('profile_planned_weekly', plannedWeekly);
    } else {
      await prefs.remove('profile_planned_weekly');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 120, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatDate(picked);
    });
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  double _kgToLb(double kg) => kg * _lbPerKg;

  double _lbToKg(double lb) => lb / _lbPerKg;

  double _cmToInches(double cm) => cm / _cmPerInch;

  double _inchesToCm(double inches) => inches * _cmPerInch;

  String _formatNumber(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded % 1 == 0) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(1);
  }

  String _formatSteps(int steps) {
    return steps
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  double? _parseDouble(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) {
      return null;
    }
    return double.tryParse(normalized);
  }

  int? _parseInt(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  Future<void> _loadStepsHistory() async {
    setState(() {
      _isLoadingSteps = true;
    });
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final result = await _stepsService.readStepsForRange(start, now);
    if (!mounted) {
      return;
    }
    setState(() {
      _stepsHistory = result.days;
      _stepsAuthorized = result.authorized;
      _isLoadingSteps = false;
    });
  }

  int? get _trainingDays => _parseInt(_trainingDaysController.text);

  int? get _plannedWeekly => _parseInt(_plannedWeeklyController.text);

  int? get _plannedDailyTarget {
    final weekly = _plannedWeekly;
    if (weekly == null || weekly <= 0) {
      return null;
    }
    final days = _trainingDays;
    final divisor = (days != null && days > 0) ? days : 7;
    return (weekly / divisor).ceil();
  }

  void _setWeightFromKg(double kg) {
    if (_weightUnit == WeightUnit.kg) {
      _weightController.text = _formatNumber(kg);
    } else {
      _weightController.text = _formatNumber(_kgToLb(kg));
    }
  }

  void _setHeightFromCm(double cm) {
    if (_heightUnit == HeightUnit.cm) {
      _heightCmController.text = _formatNumber(cm);
    } else {
      final totalInches = _cmToInches(cm);
      final feet = totalInches ~/ 12;
      final inches = totalInches - (feet * 12);
      _heightFtController.text = feet.toString();
      _heightInController.text = _formatNumber(inches);
    }
  }

  void _onWeightUnitChanged(WeightUnit unit) {
    if (_weightUnit == unit) {
      return;
    }
    final kg = _weightKg;
    setState(() {
      _weightUnit = unit;
    });
    if (kg != null) {
      _setWeightFromKg(kg);
    } else {
      _weightController.clear();
    }
  }

  void _onHeightUnitChanged(HeightUnit unit) {
    if (_heightUnit == unit) {
      return;
    }
    final cm = _heightCm;
    setState(() {
      _heightUnit = unit;
    });
    if (cm != null) {
      _setHeightFromCm(cm);
    } else {
      _heightCmController.clear();
      _heightFtController.clear();
      _heightInController.clear();
    }
  }

  double? get _weightKg {
    final value = _parseDouble(_weightController.text);
    if (value == null) {
      return null;
    }
    return _weightUnit == WeightUnit.kg ? value : _lbToKg(value);
  }

  double? get _heightCm {
    if (_heightUnit == HeightUnit.cm) {
      return _parseDouble(_heightCmController.text);
    }
    final feet = _parseDouble(_heightFtController.text);
    final inches = _parseDouble(_heightInController.text);
    if (feet == null && inches == null) {
      return null;
    }
    final totalInches = (feet ?? 0) * 12 + (inches ?? 0);
    if (totalInches <= 0) {
      return null;
    }
    return _inchesToCm(totalInches);
  }

  int? get _age {
    final birthDate = _birthDate;
    if (birthDate == null) {
      return null;
    }
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age -= 1;
    }
    return age;
  }

  double? get _bmi {
    final weight = _weightKg;
    final heightCm = _heightCm;
    if (weight == null || heightCm == null || heightCm <= 0) {
      return null;
    }
    final heightM = heightCm / 100.0;
    return weight / pow(heightM, 2);
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }

  Widget _buildWeightUnitToggle() {
    return SegmentedButton<WeightUnit>(
      segments: const [
        ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
        ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
      ],
      selected: <WeightUnit>{_weightUnit},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        _onWeightUnitChanged(selection.first);
      },
    );
  }

  Widget _buildHeightUnitToggle() {
    return SegmentedButton<HeightUnit>(
      segments: const [
        ButtonSegment(value: HeightUnit.cm, label: Text('cm')),
        ButtonSegment(value: HeightUnit.ftIn, label: Text('ft/in')),
      ],
      selected: <HeightUnit>{_heightUnit},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) {
          return;
        }
        _onHeightUnitChanged(selection.first);
      },
    );
  }

  Widget _buildBasicsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _birthDateController,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Birth date',
            hintText: 'YYYY-MM-DD',
            suffixIcon: Icon(Icons.calendar_today),
          ),
          onTap: _pickBirthDate,
        ),
        const SizedBox(height: 12),
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Age',
          ),
          child: Text(_age == null ? '--' : '${_age!}'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _sex,
          decoration: const InputDecoration(
            labelText: 'Sex (optional)',
          ),
          items: _sexOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _sex = value),
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    final label = _weightUnit == WeightUnit.kg ? 'Weight (kg)' : 'Weight (lb)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        _buildWeightUnitToggle(),
      ],
    );
  }

  Widget _buildHeightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_heightUnit == HeightUnit.cm)
          TextFormField(
            controller: _heightCmController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Height (cm)'),
            onChanged: (_) => setState(() {}),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _heightFtController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Feet'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _heightInController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Inches'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        _buildHeightUnitToggle(),
      ],
    );
  }

  Widget _buildBodyMetricsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeightField(),
        const SizedBox(height: 12),
        _buildHeightField(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _bodyFatController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Body fat % (optional)',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _restingHrController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Resting heart rate (bpm, optional)',
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _goal,
          decoration: const InputDecoration(
            labelText: 'Primary goal',
          ),
          items: _goalOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _goal = value),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _activityLevel,
          decoration: const InputDecoration(
            labelText: 'Activity level',
          ),
          items: _activityOptions
              .map(
                (option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _activityLevel = value),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _trainingDaysController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Training days per week (0-7)',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _plannedWeeklyController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Planned workouts per week',
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (_plannedDailyTarget != null) ...[
          const SizedBox(height: 12),
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Daily target',
            ),
            child: Text(
              '${_plannedDailyTarget!} workout${_plannedDailyTarget == 1 ? '' : 's'} per day',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeightChart() {
    if (_weightHistory.isEmpty) {
      return Text(
        'No weight history yet. Save your weight to start a trend line.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < _weightHistory.length; i += 1) {
      final entry = _weightHistory[i];
      final value = _weightUnit == WeightUnit.kg
          ? entry.weightKg
          : _kgToLb(entry.weightKg);
      spots.add(FlSpot(i.toDouble(), value));
    }

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: spots.isEmpty ? 0 : spots.length - 1,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Theme.of(context).colorScheme.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
            ),
          ],
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: spots.length <= 2 ? 1.0 : (spots.length / 2).floorToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= _weightHistory.length) {
                    return const SizedBox.shrink();
                  }
                  final date = _weightHistory[index].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalWeightDisplay = _weightUnit == WeightUnit.kg
        ? _totalWeightLifted / _lbPerKg
        : _totalWeightLifted;
    final weightUnitLabel = _weightUnit == WeightUnit.kg ? 'kg' : 'lb';

    final items = [
      _StatCard(
        label: 'Hours moved\nthis week',
        value: _hoursThisWeek.toStringAsFixed(1),
        unit: 'hrs',
      ),
      _StatCard(
        label: 'Current streak',
        value: '$_currentStreak',
        unit: 'days',
      ),
      _StatCard(
        label: 'Total weight\nlifted',
        value: totalWeightDisplay.toStringAsFixed(0),
        unit: weightUnitLabel,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: items,
    );
  }

  Widget _buildStepsHistory() {
    if (_isLoadingSteps) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_stepsAuthorized) {
      return Text(
        'Steps unavailable. Enable Health Connect permissions to see step history.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    if (_stepsHistory.isEmpty) {
      return Text(
        'No step history yet.',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    final days = _stepsHistory.reversed.toList();
    return Column(
      children: days.map((entry) {
        final dateLabel = '${entry.date.month}/${entry.date.day}';
        final stepsLabel =
            entry.steps == null ? '--' : _formatSteps(entry.steps!);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(dateLabel, style: Theme.of(context).textTheme.bodyMedium),
              Text(
                '$stepsLabel steps',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCard(String title, Widget child) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(title),
            child,
          ],
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    await _saveProfile(completed: true);
    if (!mounted) {
      return;
    }
    setState(() {
      _isOnboarding = false;
    });
  }

  Widget _buildOnboarding() {
    final steps = <Step>[
      Step(
        title: const Text('Basics'),
        content: _buildBasicsFields(),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Body Metrics'),
        content: _buildBodyMetricsFields(),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
      ),
      Step(
        title: const Text('Goals'),
        content: _buildGoalsFields(),
        isActive: _currentStep >= 2,
        state: _currentStep > 2 ? StepState.complete : StepState.indexed,
      ),
    ];

    return Stepper(
      currentStep: _currentStep,
      onStepContinue: () {
        final isLast = _currentStep == steps.length - 1;
        if (isLast) {
          _finishOnboarding();
        } else {
          setState(() {
            _currentStep += 1;
          });
        }
      },
      onStepCancel: _currentStep == 0
          ? null
          : () {
              setState(() {
                _currentStep -= 1;
              });
            },
      controlsBuilder: (context, details) {
        final isLast = _currentStep == steps.length - 1;
        return Row(
          children: [
            ElevatedButton(
              onPressed: details.onStepContinue,
              child: Text(isLast ? 'Finish' : 'Next'),
            ),
            const SizedBox(width: 8),
            if (_currentStep > 0)
              TextButton(
                onPressed: details.onStepCancel,
                child: const Text('Back'),
              ),
          ],
        );
      },
      steps: steps,
    );
  }

  Future<void> _saveAndNotify() async {
    await _saveProfile(completed: true);
    await _loadStats();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Data'),
        actions: _isOnboarding
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.checklist),
                  tooltip: 'Run questionnaire',
                  onPressed: () {
                    setState(() {
                      _isOnboarding = true;
                      _currentStep = 0;
                    });
                  },
                ),
              ],
      ),
      body: _isOnboarding
          ? _buildOnboarding()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildCard('Basics', _buildBasicsFields()),
                const SizedBox(height: 16),
                _buildCard('Body Metrics', _buildBodyMetricsFields()),
                const SizedBox(height: 16),
                _buildCard('Goals', _buildGoalsFields()),
                const SizedBox(height: 16),
                _buildCard('Trends', _buildWeightChart()),
                const SizedBox(height: 16),
                _buildCard('Stats', _buildStatsGrid()),
                const SizedBox(height: 16),
                _buildCard('Steps (Last 7 days)', _buildStepsHistory()),
                if (_bmi != null) ...[
                  const SizedBox(height: 16),
                  _buildCard(
                    'BMI',
                    Text(
                      _bmi!.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _saveAndNotify,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
