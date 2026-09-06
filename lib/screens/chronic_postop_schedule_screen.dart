import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ChronicPostopScheduleScreen extends StatefulWidget {
  const ChronicPostopScheduleScreen({super.key});

  @override
  State<ChronicPostopScheduleScreen> createState() => _ChronicPostopScheduleScreenState();
}

class _ChronicPostopScheduleScreenState extends State<ChronicPostopScheduleScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Post-Op Schedule'),
      ),
      body: const Center(
        child: Text('Post-Op Schedule'),
      ),
    );
  }
}
