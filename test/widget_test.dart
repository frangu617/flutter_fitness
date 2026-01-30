// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_fitness/main.dart';

void main() {
  testWidgets('Landing page shows title and navigation links', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title is 'My Fitness'.
    expect(find.text('My Fitness'), findsOneWidget);

    // Verify that the navigation links are present.
    expect(find.text('Today\'s workout'), findsOneWidget);
    expect(find.text('Past Workouts'), findsOneWidget);
    expect(find.text('My Data'), findsOneWidget);
    expect(find.text('My Goals'), findsOneWidget);
  });

  group('Navigation tests', () {
    testWidgets('Navigate to Today\'s workout page', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Today\'s workout'));
      await tester.pumpAndSettle();
      expect(find.text('Today\'s Workout'), findsOneWidget);
    });

    testWidgets('Navigate to Past Workouts page', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('Past Workouts'));
      await tester.pumpAndSettle();
      expect(find.text('Past Workouts'), findsOneWidget);
    });

    testWidgets('Navigate to My Data page', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('My Data'));
      await tester.pumpAndSettle();
      expect(find.text('My Data'), findsOneWidget);
    });

    testWidgets('Navigate to My Goals page', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.tap(find.text('My Goals'));
      await tester.pumpAndSettle();
      expect(find.text('My Goals'), findsOneWidget);
    });
  });
}
