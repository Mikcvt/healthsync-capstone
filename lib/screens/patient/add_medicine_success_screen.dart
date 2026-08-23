import 'package:flutter/material.dart';

class AddMedicineSuccessScreen extends StatelessWidget {
  const AddMedicineSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine added')),
      body: const Center(child: Text('Medicine added successfully')),
    );
  }
}
