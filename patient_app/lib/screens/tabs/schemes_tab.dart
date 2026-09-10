import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/schemes_provider.dart';
import '../schemes/eligibility_form_screen.dart';
import '../schemes/schemes_results_screen.dart';

class SchemesTab extends StatelessWidget {
  const SchemesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SchemesProvider>(context);

    // FIRST TIME: Show eligibility info form
    // SUBSEQUENT VISITS: Directly show personalized schemes results using saved profile
    if (!provider.hasProfile) {
      return const EligibilityFormScreen();
    }

    return const SchemesResultsScreen();
  }
}
