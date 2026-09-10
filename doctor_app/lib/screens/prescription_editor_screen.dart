import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PrescriptionEditorScreen extends StatefulWidget {
  const PrescriptionEditorScreen({super.key});

  @override
  State<PrescriptionEditorScreen> createState() => _PrescriptionEditorScreenState();
}

class _PrescriptionEditorScreenState extends State<PrescriptionEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Prescription Editor'),
      ),
      body: const Center(
        child: Text('Prescription Editor'),
      ),
    );
  }
}
