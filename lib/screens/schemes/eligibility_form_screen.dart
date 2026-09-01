import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/scheme_eligibility_profile.dart';
import '../../providers/schemes_provider.dart';

class EligibilityFormScreen extends StatefulWidget {
  final SchemeEligibilityProfile? initialProfile;

  const EligibilityFormScreen({super.key, this.initialProfile});

  @override
  State<EligibilityFormScreen> createState() => _EligibilityFormScreenState();
}

class _EligibilityFormScreenState extends State<EligibilityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageController;

  String _selectedState = 'Delhi';
  String _selectedIncome = '1 - 2.5 Lakh';

  // Optional Fields
  String? _selectedGender;
  String? _selectedOccupation;
  String? _selectedCategory;
  String? _selectedDisability = 'None';
  String? _selectedMaritalStatus;
  String? _selectedRuralUrban;

  bool _showOptionalFields = false;

  final List<String> _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh', 'Goa',
    'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka', 'Kerala',
    'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram', 'Nagaland',
    'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu', 'Telangana', 'Tripura',
    'Uttar Pradesh', 'Uttarakhand', 'West Bengal', 'Delhi', 'Jammu and Kashmir',
    'Ladakh', 'Puducherry', 'Chandigarh'
  ];

  final List<String> _incomeRanges = [
    '< 1 Lakh',
    '1 - 2.5 Lakh',
    '2.5 - 5 Lakh',
    '5 - 8 Lakh',
    '> 8 Lakh',
    'BPL / EWS',
  ];

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _occupations = [
    'Farmer / Agriculture',
    'Daily Wage / Laborer',
    'Salaried / Formal Worker',
    'Self-Employed / Trader',
    'Student',
    'Homemaker / Unemployed',
    'Retired / Senior Citizen',
  ];
  final List<String> _categories = ['General', 'OBC', 'SC', 'ST'];
  final List<String> _disabilities = ['None', 'Locomotor', 'Visual', 'Hearing', 'Mental / Intellectual', 'Multiple'];
  final List<String> _maritalStatuses = ['Single', 'Married', 'Widowed', 'Divorced / Separated'];
  final List<String> _ruralUrbanTypes = ['Rural', 'Urban', 'Semi-Urban'];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    _ageController = TextEditingController(text: p != null ? p.age.toString() : '');
    if (p != null) {
      if (_states.contains(p.state)) _selectedState = p.state;
      if (_incomeRanges.contains(p.incomeRange)) _selectedIncome = p.incomeRange;
      _selectedGender = p.gender;
      _selectedOccupation = p.occupation;
      _selectedCategory = p.socialCategory;
      _selectedDisability = p.disability ?? 'None';
      _selectedMaritalStatus = p.maritalStatus;
      _selectedRuralUrban = p.ruralUrban;
      _showOptionalFields = true;
    }
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final age = int.tryParse(_ageController.text.trim()) ?? 25;

    final profile = SchemeEligibilityProfile(
      age: age,
      state: _selectedState,
      incomeRange: _selectedIncome,
      gender: _selectedGender,
      occupation: _selectedOccupation,
      socialCategory: _selectedCategory,
      disability: _selectedDisability,
      maritalStatus: _selectedMaritalStatus,
      ruralUrban: _selectedRuralUrban,
    );

    final provider = Provider.of<SchemesProvider>(context, listen: false);
    await provider.saveProfileAndEvaluate(profile);

    if (mounted && widget.initialProfile != null) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final provider = Provider.of<SchemesProvider>(context);

    return Scaffold(
      appBar: widget.initialProfile != null
          ? AppBar(
              title: const Text('Update Eligibility Info'),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF81C784), width: 2),
                    ),
                    child: const Icon(
                      Icons.health_and_safety_rounded,
                      size: 40,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title & Subtitle (as specified in requirements)
                Text(
                  'Find Government Health Benefits',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us a little about yourself so we can find schemes you may be eligible for.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 28),

                // Section Label: Required Information
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 16, color: Colors.redAccent),
                    const SizedBox(width: 4),
                    Text(
                      'REQUIRED INFORMATION',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Age Field (Required)
                TextFormField(
                  controller: _ageController,
                  stylusHandwritingEnabled: false,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Your Age *',
                    hintText: 'e.g. 32',
                    prefixIcon: const Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your age';
                    }
                    final age = int.tryParse(value.trim());
                    if (age == null || age <= 0 || age > 120) {
                      return 'Please enter a valid age between 1 and 120';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 2. State Dropdown (Required)
                DropdownButtonFormField<String>(
                  initialValue: _selectedState,
                  decoration: InputDecoration(
                    labelText: 'State / Union Territory *',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  items: _states.map((st) {
                    return DropdownMenuItem(value: st, child: Text(st));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedState = val);
                  },
                ),
                const SizedBox(height: 16),

                // 3. Annual Family Income (Required)
                DropdownButtonFormField<String>(
                  initialValue: _selectedIncome,
                  decoration: InputDecoration(
                    labelText: 'Annual Family Income *',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ),
                  items: _incomeRanges.map((inc) {
                    return DropdownMenuItem(value: inc, child: Text('₹ $inc / year'));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedIncome = val);
                  },
                ),
                const SizedBox(height: 20),

                // Optional Information Toggle Accordion
                InkWell(
                  onTap: () {
                    setState(() => _showOptionalFields = !_showOptionalFields);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _showOptionalFields ? Icons.tune_rounded : Icons.add_circle_outline_rounded,
                              size: 18,
                              color: const Color(0xFF00796B),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _showOptionalFields ? 'Hide Optional Details' : 'Add Optional Details (Better Matching)',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00796B)),
                            ),
                          ],
                        ),
                        Icon(
                          _showOptionalFields ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                  ),
                ),

                if (_showOptionalFields) ...[
                  const SizedBox(height: 16),

                  // Gender
                  DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: InputDecoration(
                      labelText: 'Gender (Optional)',
                      prefixIcon: const Icon(Icons.wc_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    hint: const Text('Select Gender'),
                    items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                  ),
                  const SizedBox(height: 14),

                  // Occupation
                  DropdownButtonFormField<String>(
                    initialValue: _selectedOccupation,
                    decoration: InputDecoration(
                      labelText: 'Occupation (Optional)',
                      prefixIcon: const Icon(Icons.work_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    hint: const Text('Select Occupation'),
                    items: _occupations.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (val) => setState(() => _selectedOccupation = val),
                  ),
                  const SizedBox(height: 14),

                  // Social Category
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: InputDecoration(
                      labelText: 'Social Category (Optional)',
                      prefixIcon: const Icon(Icons.people_outline_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    hint: const Text('Select Category'),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _selectedCategory = val),
                  ),
                  const SizedBox(height: 14),

                  // Disability
                  DropdownButtonFormField<String>(
                    initialValue: _selectedDisability,
                    decoration: InputDecoration(
                      labelText: 'Disability / Divyang (Optional)',
                      prefixIcon: const Icon(Icons.accessible_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: _disabilities.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                    onChanged: (val) => setState(() => _selectedDisability = val),
                  ),
                  const SizedBox(height: 14),

                  // Marital Status
                  DropdownButtonFormField<String>(
                    initialValue: _selectedMaritalStatus,
                    decoration: InputDecoration(
                      labelText: 'Marital Status (Optional)',
                      prefixIcon: const Icon(Icons.favorite_border_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    hint: const Text('Select Status'),
                    items: _maritalStatuses.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (val) => setState(() => _selectedMaritalStatus = val),
                  ),
                  const SizedBox(height: 14),

                  // Rural / Urban
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRuralUrban,
                    decoration: InputDecoration(
                      labelText: 'Area / Residence (Optional)',
                      prefixIcon: const Icon(Icons.location_city_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    hint: const Text('Select Residence Type'),
                    items: _ruralUrbanTypes.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) => setState(() => _selectedRuralUrban = val),
                  ),
                ],

                const SizedBox(height: 28),

                // Submit Button
                FilledButton(
                  onPressed: provider.isLoading ? null : _submitForm,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00796B),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded),
                            SizedBox(width: 8),
                            Text(
                              'Find My Schemes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),

                // Privacy Note
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Your information is used to find relevant government health benefits.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
