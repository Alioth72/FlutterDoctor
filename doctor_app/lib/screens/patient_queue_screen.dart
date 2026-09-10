import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PatientQueueScreen extends StatefulWidget {
  const PatientQueueScreen({super.key});

  @override
  State<PatientQueueScreen> createState() => _PatientQueueScreenState();
}

class _PatientQueueScreenState extends State<PatientQueueScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Patient Queue'),
      ),
      body: const Center(
        child: Text('Patient Queue'),
      ),
    );
  }
}
