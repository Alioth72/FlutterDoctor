import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PatientDetailScreen extends StatefulWidget {
  const PatientDetailScreen({super.key});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Patient Detail'),
      ),
      body: const Center(
        child: Text('Patient Detail'),
      ),
    );
  }
}
