import 'package:flutter/material.dart';

class DoseAlertScreen extends StatelessWidget {
  const DoseAlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dose alert')),
      body: const Center(child: Text('Dose alert screen')),
    );
  }
}
