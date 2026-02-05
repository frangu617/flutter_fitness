import 'package:flutter/material.dart';
import 'package:flutter_fitness/services/steps_service.dart';

class StepsPage extends StatefulWidget {
  const StepsPage({super.key});

  @override
  State<StepsPage> createState() => _StepsPageState();
}

class _StepsPageState extends State<StepsPage> {
  final StepsService _stepsService = StepsService();
  bool _isLoading = true;
  bool _authorized = true;
  bool _healthConnectAvailable = true;
  bool _needsHealthConnectUpdate = false;
  int? _todaySteps;
  List<StepsDay> _history = [];

  @override
  void initState() {
    super.initState();
    _loadSteps();
  }

  Future<void> _loadSteps() async {
    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(const Duration(days: 6));
    final result = await _stepsService.readStepsForRange(start, today);

    int? todaySteps;
    if (result.authorized) {
      for (final entry in result.days) {
        if (_isSameDay(entry.date, today)) {
          todaySteps = entry.steps;
          break;
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _authorized = result.authorized;
      _history = result.days;
      _todaySteps = todaySteps;
      _healthConnectAvailable = result.healthConnectAvailable;
      _needsHealthConnectUpdate = result.needsHealthConnectUpdate;
      _isLoading = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatSteps(int steps) {
    return steps
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  Widget _buildTodayCard() {
    final label = _todaySteps == null ? '--' : _formatSteps(_todaySteps!);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'steps',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard() {
    if (_history.isEmpty) {
      return Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No step history yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final ordered = _history.reversed.toList();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 days',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            ...ordered.map((entry) {
              final label =
                  entry.steps == null ? '--' : _formatSteps(entry.steps!);
              final dateLabel = '${entry.date.month}/${entry.date.day}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateLabel),
                    Text('$label steps'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permission needed',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to request Health Connect permissions.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadSteps,
              icon: const Icon(Icons.lock_open),
              label: const Text('Request permission'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthConnectCard() {
    final title = _needsHealthConnectUpdate
        ? 'Update Health Connect'
        : 'Install Health Connect';
    final message = _needsHealthConnectUpdate
        ? 'Health Connect needs an update before step data can load.'
        : 'Health Connect is required to read steps on Android.';
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await _stepsService.openHealthConnectInstall();
              },
              icon: const Icon(Icons.open_in_new),
              label: Text(title),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadSteps,
              child: const Text('I already installed it'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Steps')),
      body: RefreshIndicator(
        onRefresh: _loadSteps,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_healthConnectAvailable && !_isLoading)
              _buildHealthConnectCard(),
            if (_healthConnectAvailable && !_authorized && !_isLoading)
              _buildPermissionCard(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildTodayCard(),
              const SizedBox(height: 16),
              _buildHistoryCard(),
            ],
          ],
        ),
      ),
    );
  }
}
