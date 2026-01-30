import 'package:flutter/material.dart';

class MyDataPage extends StatelessWidget {
  const MyDataPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Data'),
      ),
      body: const Center(
        child: Text('My Data Page'),
      ),
    );
  }
}
