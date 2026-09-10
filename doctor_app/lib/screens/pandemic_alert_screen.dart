import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PandemicAlertScreen extends StatefulWidget {
  const PandemicAlertScreen({super.key});

  @override
  State<PandemicAlertScreen> createState() => _PandemicAlertScreenState();
}

class _PandemicAlertScreenState extends State<PandemicAlertScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pandemic Alerts'),
      ),
      body: const Center(
        child: Text('Pandemic Alerts'),
      ),
    );
  }
}
