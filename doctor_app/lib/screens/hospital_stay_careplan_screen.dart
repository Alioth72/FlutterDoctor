import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class HospitalStayCareplanScreen extends StatefulWidget {
  const HospitalStayCareplanScreen({super.key});

  @override
  State<HospitalStayCareplanScreen> createState() => _HospitalStayCareplanScreenState();
}

class _HospitalStayCareplanScreenState extends State<HospitalStayCareplanScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Care Plan'),
      ),
      body: const Center(
        child: Text('Care Plan'),
      ),
    );
  }
}
