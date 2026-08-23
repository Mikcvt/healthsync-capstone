import 'package:flutter/material.dart';

class MedicineDetailScreen extends StatelessWidget {
  const MedicineDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine details')),
      body: const Center(child: Text('Medicine detail screen')),
    );
  }
}
