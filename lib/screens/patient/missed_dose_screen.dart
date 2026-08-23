import 'package:flutter/material.dart';

class MissedDoseScreen extends StatelessWidget {
  const MissedDoseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missed dose')),
      body: const Center(child: Text('Missed dose screen')),
    );
  }
}
