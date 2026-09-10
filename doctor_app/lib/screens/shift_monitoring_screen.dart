import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ShiftMonitoringScreen extends StatefulWidget {
  const ShiftMonitoringScreen({super.key});

  @override
  State<ShiftMonitoringScreen> createState() => _ShiftMonitoringScreenState();
}

class _ShiftMonitoringScreenState extends State<ShiftMonitoringScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Shift Monitoring'),
      ),
      body: const Center(
        child: Text('Shift Monitoring'),
      ),
    );
  }
}
