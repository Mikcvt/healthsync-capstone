import 'package:flutter/material.dart';

class DeleteMedicineScreen extends StatelessWidget {
  const DeleteMedicineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delete medicine')),
      body: const Center(child: Text('Delete medicine screen')),
    );
  }
}
