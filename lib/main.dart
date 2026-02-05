import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter_fitness/data/workout_database.dart';
import 'package:flutter_fitness/todays_workout_page.dart';
import 'package:flutter_fitness/past_workouts_page.dart';
import 'package:flutter_fitness/my_data_page.dart';
import 'package:flutter_fitness/nutrition_page.dart';
import 'package:flutter_fitness/steps_page.dart';
import 'package:flutter_fitness/services/steps_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWebNoWebWorker;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await WorkoutDatabase.instance.database;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Fitness',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'My Fitness'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final WorkoutDatabase _db = WorkoutDatabase.instance;
  final StepsService _stepsService = StepsService();
  int _completedToday = 0;
  int _plannedToday = 1;
  int? _todaySteps;
  bool _stepsAuthorized = true;
  bool _isLoadingSteps = true;
  String _greeting = 'Good Morning';
  String? _name;
  String? _todayTitle;
  bool _isLoading = true;

  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  String _formatSteps(int steps) {
    return steps
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');
  }

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoadingSteps = true;
      });
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workouts = await _db.fetchWorkoutsForDate(today);
    final dayTitle = await _db.fetchDayTitle(today);
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('profile_name');
    final completedKey = 'completed_workouts_${_dateKey(today)}';
    final completedIds = prefs.getStringList(completedKey) ?? <String>[];
    final workoutIds = workouts.map((workout) => workout.id).toSet();
    final completedToday =
        completedIds.where(workoutIds.contains).length;
    final plannedToday = workouts.length;

    final greeting = _greetingForHour(now.hour);
    final stepsResult = await _stepsService.readStepsForDay(today);

    if (!mounted) {
      return;
    }
    setState(() {
      _completedToday = completedToday;
      _plannedToday = plannedToday;
      _greeting = greeting;
      _name = name == null || name.trim().isEmpty ? null : name.trim();
      _todayTitle = dayTitle;
      _isLoading = false;
      _todaySteps = stepsResult.steps;
      _stepsAuthorized = stepsResult.authorized;
      _isLoadingSteps = false;
    });
  }

  String _greetingForHour(int hour) {
    if (hour < 12) {
      return 'Good Morning';
    }
    if (hour < 17) {
      return 'Good Afternoon';
    }
    return 'Good Evening';
  }

  Future<void> _openToday({bool addExercise = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TodaysWorkoutPage(autoOpenAdd: addExercise),
      ),
    );
    _loadDashboard();
  }

  Future<void> _openPage(Widget page) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
    _loadDashboard();
  }

  bool _textFits(
    String text,
    TextStyle style,
    double maxWidth,
    TextDirection textDirection,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);
    return !painter.didExceedMaxLines;
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/fitnessLogo.svg',
          width: 44,
          height: 44,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final greetingStyle = Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700) ??
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700);
              final subtitleStyle = Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: colorScheme.onSurfaceVariant) ??
                  TextStyle(color: colorScheme.onSurfaceVariant);
              final textDirection = Directionality.of(context);
              String greetingText = _greeting;
              String secondaryText = widget.title;

              if (_name != null) {
                final inlineGreeting = '$_greeting, $_name';
                final fits = _textFits(
                  inlineGreeting,
                  greetingStyle,
                  constraints.maxWidth,
                  textDirection,
                );
                if (fits) {
                  greetingText = inlineGreeting;
                } else {
                  secondaryText = _name!;
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greetingText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: greetingStyle,
                  ),
                  Text(
                    secondaryText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: subtitleStyle,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProgressRing(ColorScheme colorScheme) {
    final planned = _plannedToday;
    final progress = planned > 0
        ? (_completedToday / planned).clamp(0.0, 1.0)
        : 0.0;
    return SizedBox(
      width: 86,
      height: 86,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$_completedToday/${planned > 0 ? planned : 0}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                'done',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayCard(ColorScheme colorScheme) {
    final stepsLabel = _isLoadingSteps
        ? 'Steps today: ...'
        : _stepsAuthorized
            ? 'Steps today: ${_todaySteps == null ? '--' : _formatSteps(_todaySteps!)}'
            : 'Steps: permission needed';
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _isLoading ? null : () => _openToday(),
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/gymBG.jpg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surface.withAlpha(200),
                      colorScheme.surface.withAlpha(120),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Workout",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      IconButton.filled(
                        onPressed:
                            _isLoading ? null : () => _openToday(addExercise: true),
                        icon: const Icon(Icons.add),
                        tooltip: 'Add exercise',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildProgressRing(colorScheme),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoading
                                  ? "Loading today's plan..."
                                  : 'Workouts completed today',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            if (!_isLoading &&
                                _todayTitle != null &&
                                _todayTitle!.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                _todayTitle!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _isLoading
                                  ? '?'
                                  : '$_completedToday of $_plannedToday planned',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              stepsLabel,
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Tap to view today's list",
                              style:
                                  Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryGrid(ColorScheme colorScheme) {
    final cards = [
      _buildSecondaryCard(
        title: 'Past Workouts',
        icon: Icons.calendar_today,
        colorScheme: colorScheme,
        onTap: () => _openPage(const PastWorkoutsPage()),
      ),
      _buildSecondaryCard(
        title: 'Steps',
        icon: Icons.directions_walk,
        colorScheme: colorScheme,
        onTap: () => _openPage(const StepsPage()),
      ),
      _buildSecondaryCard(
        title: 'My Data',
        icon: Icons.insights,
        colorScheme: colorScheme,
        onTap: () => _openPage(const MyDataPage()),
      ),
      _buildSecondaryCard(
        title: 'Nutrition',
        icon: Icons.restaurant,
        colorScheme: colorScheme,
        onTap: () => _openPage(const NutritionPage()),
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: 0.5,
              widthFactor: 1,
              child: Image.asset(
                'assets/fitnessLogo.png',
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
                      colorScheme.surface.withAlpha(210),
                      colorScheme.surface.withAlpha(150),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(colorScheme),
                const SizedBox(height: 16),
                _buildTodayCard(colorScheme),
                const SizedBox(height: 16),
                _buildSecondaryGrid(colorScheme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
