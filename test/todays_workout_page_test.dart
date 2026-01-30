import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_fitness/todays_workout_page.dart';
import 'package:flutter_fitness/models/workout.dart';

void main() {
  testWidgets('TodaysWorkoutPage can add and display a cardio workout', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TodaysWorkoutPage()));

    // Tap the add button to open the dialog
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter workout details
    await tester.enterText(find.byType(TextFormField).first, 'Morning Run');
    await tester.tap(find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<WorkoutType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardio').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('distance_field')), '5.0');
    await tester.enterText(find.byKey(const Key('time_field')), '30');

    // Tap the add button in the dialog
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Verify the workout is displayed
    expect(find.text('Morning Run'), findsOneWidget);
    expect(find.text('Type: Cardio\nDistance: 5.0 miles Time: 30 minutes'), findsOneWidget);
  });

  testWidgets('TodaysWorkoutPage can add and display a strength workout', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TodaysWorkoutPage()));

    // Tap the add button to open the dialog
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // Enter workout details
    await tester.enterText(find.byType(TextFormField).first, 'Bench Press');
    await tester.tap(find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<WorkoutType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength').last);
    await tester.pumpAndSettle();

    // Tap the add button in the dialog
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Verify the workout is displayed
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('Type: Strength'), findsOneWidget);
  });

  testWidgets('TodaysWorkoutPage can add a weighted set to a strength workout', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TodaysWorkoutPage()));

    // Add a strength workout
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Squats');
    await tester.tap(find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<WorkoutType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Add a set
    await tester.enterText(find.widgetWithText(TextFormField, 'Reps'), '10');
    await tester.enterText(find.widgetWithText(TextFormField, 'Weight (lbs)'), '225');
    await tester.tap(find.byKey(const Key('add_set_button')));
    await tester.pump();

    // Verify the set is displayed
    expect(find.text('Reps: 10, Weight: 225.0 lbs'), findsOneWidget);
  });

  testWidgets('TodaysWorkoutPage can add a bodyweight set to a strength workout', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TodaysWorkoutPage()));

    // Add a strength workout
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Pull-ups');
    await tester.tap(find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<WorkoutType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Add a bodyweight set
    await tester.enterText(find.widgetWithText(TextFormField, 'Reps'), '15');
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    // Verify that the weight field is disabled
    expect(tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Weight (lbs)')).enabled, isFalse);
    
    await tester.tap(find.byKey(const Key('add_set_button')));
    await tester.pump();

    // Verify the set is displayed
    expect(find.text('Reps: 15, Weight: Body weight'), findsOneWidget);
  });

  testWidgets('TodaysWorkoutPage can delete a workout', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TodaysWorkoutPage()));

    // Add a workout
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Deadlifts');
    await tester.tap(find.byWidgetPredicate((widget) => widget is DropdownButtonFormField<WorkoutType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strength').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Delete the workout
    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    // Verify the workout is removed
    expect(find.text('Deadlifts'), findsNothing);
  });
}
