import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  final TextEditingController _foodController = TextEditingController();
  final TextEditingController _calorieController = TextEditingController();
  final TextEditingController _waterController = TextEditingController();
  final FocusNode _foodFocus = FocusNode();

  late final DateTime _todayDate;
  bool _isLoading = true;
  List<_FoodLogEntry> _foodEntries = [];
  List<_WaterLogEntry> _waterEntries = [];

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String get _foodLogKey => 'food_log_${_dateKey(_todayDate)}';
  String get _waterLogKey => 'water_log_${_dateKey(_todayDate)}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _todayDate = DateTime(now.year, now.month, now.day);
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final prefs = await SharedPreferences.getInstance();
    final foodJson = prefs.getString(_foodLogKey);
    final waterJson = prefs.getString(_waterLogKey);
    final foodEntries = <_FoodLogEntry>[];
    final waterEntries = <_WaterLogEntry>[];

    if (foodJson != null && foodJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(foodJson) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            foodEntries.add(_FoodLogEntry.fromJson(item));
          } else if (item is Map) {
            foodEntries.add(_FoodLogEntry.fromJson(
              Map<String, dynamic>.from(item),
            ));
          }
        }
      } catch (_) {}
    }

    if (waterJson != null && waterJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(waterJson) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            waterEntries.add(_WaterLogEntry.fromJson(item));
          } else if (item is Map) {
            waterEntries.add(_WaterLogEntry.fromJson(
              Map<String, dynamic>.from(item),
            ));
          }
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _foodEntries = foodEntries;
      _waterEntries = waterEntries;
      _isLoading = false;
    });
  }

  Future<void> _saveFoodEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _foodEntries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_foodLogKey, encoded);
  }

  Future<void> _saveWaterEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _waterEntries.map((entry) => entry.toJson()).toList(),
    );
    await prefs.setString(_waterLogKey, encoded);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _addFood() {
    final name = _foodController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a food item.');
      return;
    }
    final caloriesText = _calorieController.text.trim();
    final calories =
        caloriesText.isEmpty ? null : int.tryParse(caloriesText);
    if (caloriesText.isNotEmpty && calories == null) {
      _showSnack('Calories must be a whole number.');
      return;
    }

    final entry = _FoodLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      calories: calories,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _foodEntries.add(entry);
    });
    _saveFoodEntries();

    _foodController.clear();
    _calorieController.clear();
    _foodFocus.requestFocus();
  }

  void _deleteFood(String id) {
    setState(() {
      _foodEntries.removeWhere((entry) => entry.id == id);
    });
    _saveFoodEntries();
  }

  void _addWater(int ounces) {
    if (ounces <= 0) {
      _showSnack('Water amount must be greater than 0.');
      return;
    }

    final entry = _WaterLogEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      ounces: ounces,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _waterEntries.add(entry);
    });
    _saveWaterEntries();
  }

  void _addCustomWater() {
    final text = _waterController.text.trim();
    final ounces = int.tryParse(text);
    if (ounces == null) {
      _showSnack('Enter a whole number of ounces.');
      return;
    }
    _addWater(ounces);
    _waterController.clear();
  }

  void _deleteWater(String id) {
    setState(() {
      _waterEntries.removeWhere((entry) => entry.id == id);
    });
    _saveWaterEntries();
  }

  int get _totalCalories {
    return _foodEntries.fold<int>(
      0,
      (sum, entry) => sum + (entry.calories ?? 0),
    );
  }

  int get _totalWater {
    return _waterEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.ounces,
    );
  }

  String _formatTime(int timestamp) {
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final timeOfDay = TimeOfDay.fromDateTime(dateTime);
    return MaterialLocalizations.of(context).formatTimeOfDay(timeOfDay);
  }

  String _formatCups(int ounces) {
    final cups = ounces / 8.0;
    if (cups == cups.roundToDouble()) {
      return cups.toInt().toString();
    }
    return cups.toStringAsFixed(1);
  }

  Widget _buildSectionHeader({required String title, String? trailing}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
      ],
    );
  }

  Widget _buildFoodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Food log',
          trailing: _foodEntries.isEmpty
              ? null
              : '$_totalCalories kcal',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _foodController,
                focusNode: _foodFocus,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'What did you eat?'
                ),
                onSubmitted: (_) => _addFood(),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: TextField(
                controller: _calorieController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                ),
                onSubmitted: (_) => _addFood(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addFood,
              icon: const Icon(Icons.add),
              tooltip: 'Add food',
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_foodEntries.isEmpty)
          Text(
            'No food logged yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            children: _foodEntries
                .map(
                  (entry) => Dismissible(
                    key: ValueKey(entry.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red.shade400,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteFood(entry.id),
                    child: Card(
                      elevation: 0,
                      child: ListTile(
                        title: Text(entry.name),
                        subtitle: Text(_formatTime(entry.timestamp)),
                        trailing: entry.calories == null
                            ? null
                            : Text('${entry.calories} kcal'),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildWaterSection() {
    final totalWater = _totalWater;
    final totalLabel = totalWater == 0
        ? null
        : '$totalWater oz (${_formatCups(totalWater)} cups)';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title: 'Water intake', trailing: totalLabel),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildQuickAddButton(8),
            _buildQuickAddButton(12),
            _buildQuickAddButton(16),
            _buildQuickAddButton(24),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _waterController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Custom ounces',
                ),
                onSubmitted: (_) => _addCustomWater(),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _addCustomWater,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_waterEntries.isEmpty)
          Text(
            'No water logged yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          Column(
            children: _waterEntries
                .map(
                  (entry) => Dismissible(
                    key: ValueKey(entry.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      color: Colors.red.shade400,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteWater(entry.id),
                    child: Card(
                      elevation: 0,
                      child: ListTile(
                        title: Text('${entry.ounces} oz'),
                        subtitle: Text(_formatTime(entry.timestamp)),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildQuickAddButton(int ounces) {
    return OutlinedButton(
      onPressed: () => _addWater(ounces),
      child: Text('$ounces oz'),
    );
  }

  @override
  void dispose() {
    _foodController.dispose();
    _calorieController.dispose();
    _waterController.dispose();
    _foodFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition')),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: Image.asset(
                'assets/broccoli.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0.6, 0.0),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.surface.withAlpha(210),
                      Theme.of(context).colorScheme.surface.withAlpha(150),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          AnimatedPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildFoodSection(),
                      const SizedBox(height: 24),
                      _buildWaterSection(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _FoodLogEntry {
  final String id;
  final String name;
  final int? calories;
  final int timestamp;

  const _FoodLogEntry({
    required this.id,
    required this.name,
    required this.calories,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'calories': calories,
      'timestamp': timestamp,
    };
  }

  factory _FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return _FoodLogEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      calories: (json['calories'] as num?)?.toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
    );
  }
}

class _WaterLogEntry {
  final String id;
  final int ounces;
  final int timestamp;

  const _WaterLogEntry({
    required this.id,
    required this.ounces,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ounces': ounces,
      'timestamp': timestamp,
    };
  }

  factory _WaterLogEntry.fromJson(Map<String, dynamic> json) {
    return _WaterLogEntry(
      id: json['id'] as String,
      ounces: (json['ounces'] as num).toInt(),
      timestamp: (json['timestamp'] as num).toInt(),
    );
  }
}
