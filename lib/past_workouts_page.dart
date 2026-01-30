import 'package:flutter/material.dart';

class PastWorkoutsPage extends StatelessWidget {
  const PastWorkoutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Past Workouts'),
      ),
      body: const Center(
        child: Text('Past Workouts Page'),
      ),
    );
  }
}
