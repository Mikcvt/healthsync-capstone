import 'package:flutter/material.dart';

class DoseConfirmedScreen extends StatelessWidget {
  const DoseConfirmedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dose confirmed')),
      body: const Center(child: Text('Dose confirmed screen')),
    );
  }
}
