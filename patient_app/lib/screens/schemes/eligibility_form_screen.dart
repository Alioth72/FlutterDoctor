import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/scheme_eligibility_profile.dart';
import '../../providers/schemes_provider.dart';
import '../../providers/health_profile_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/dynamic_translated_text.dart';

/// Multi-step guided questionnaire for finding government health schemes & benefits.
/// Features a 6-step progress stepper, visual option cards, and Ashwini Royal Purple theme.
class EligibilityFormScreen extends StatefulWidget {
  final SchemeEligibilityProfile? initialProfile;

  const EligibilityFormScreen({super.key, this.initialProfile});

  @override
  State<EligibilityFormScreen> createState() => _EligibilityFormScreenState();
}

class _EligibilityFormScreenState extends State<EligibilityFormScreen> {
  int _currentStep = 0; // 0 to 5 (6 steps)

  // Step 1: Demographics
  String _gender = 'Male';
  int _age = 60;
  late final TextEditingController _ageController;

  // Step 2: Location & Residence
  String _state = 'Delhi';
  String _residenceArea = 'Rural'; // Urban / Rural

  // Step 3: Social Category / Community
  String _socialCategory = 'General';

  // Step 4: Disability & Minority
  bool _hasDisability = false;
  bool _isMinority = true;

  // Step 5: Student & Employment
  bool _isStudent = false;
  String _employmentStatus = 'Unemployed'; // Employed, Unemployed, Self-Employed/ Entrepreneur

  // Step 6: Economic Status & Hardship
  bool _isBpl = true;
  bool _isHardship = false;
  String _incomeRange = '1 - 2.5 Lakh';

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

  final List<String> _socialCategories = [
    'General',
    'Other Backward Class (OBC)',
    'Particularly Vulnerable Tribal Group (PVTG)',
    'Scheduled Caste (SC)',
    'Scheduled Tribe (ST)',
    'De-Notified, Nomadic, and Semi-Nomadic (DNT) communities',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProfile;
    if (p != null) {
      _age = p.age;
      if (_states.contains(p.state)) _state = p.state;
      if (_incomeRanges.contains(p.incomeRange)) _incomeRange = p.incomeRange;
      if (p.gender != null) _gender = p.gender!;
      if (p.socialCategory != null) _socialCategory = p.socialCategory!;
      _hasDisability = p.disability != null && p.disability != 'None';
      if (p.ruralUrban != null) _residenceArea = p.ruralUrban!;
      if (p.isMinority != null) _isMinority = p.isMinority!;
      if (p.isStudent != null) _isStudent = p.isStudent!;
      if (p.employmentStatus != null) _employmentStatus = p.employmentStatus!;
      if (p.isBpl != null) _isBpl = p.isBpl!;
      if (p.isHardshipDistress != null) _isHardship = p.isHardshipDistress!;
    }
    _ageController = TextEditingController(text: _age.toString());

    // Fetch gender and area of residence directly from registered patient profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final healthProfile = Provider.of<HealthProfileProvider>(context, listen: false).profile;
          if (healthProfile != null) {
            setState(() {
              if (healthProfile.gender.isNotEmpty) {
                _gender = healthProfile.gender;
              }
              _residenceArea = healthProfile.residenceType;
              if (widget.initialProfile == null && healthProfile.age > 0) {
                _age = healthProfile.age;
                _ageController.text = healthProfile.age.toString();
              }
            });
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _ageController.dispose();
    super.dispose();
  }

  void _resetForm() {
    HapticFeedback.lightImpact();
    final healthProfile = Provider.of<HealthProfileProvider>(context, listen: false).profile;
    setState(() {
      _currentStep = 0;
      _gender = healthProfile?.gender ?? 'Male';
      _age = healthProfile?.age ?? 60;
      _ageController.text = _age.toString();
      _state = 'Delhi';
      _residenceArea = healthProfile?.residenceType ?? 'Rural';
      _socialCategory = 'General';
      _hasDisability = false;
      _isMinority = false;
      _isStudent = false;
      _employmentStatus = 'Employed';
      _isBpl = false;
      _isHardship = false;
      _incomeRange = '1 - 2.5 Lakh';
    });
  }

  void _nextStep() {
    HapticFeedback.selectionClick();
    if (_currentStep == 0) {
      final parsedAge = int.tryParse(_ageController.text.trim());
      if (parsedAge != null && parsedAge > 0 && parsedAge <= 120) {
        _age = parsedAge;
      }
    }
    if (_currentStep < 5) {
      setState(() => _currentStep++);
    } else {
      _submitForm();
    }
  }

  void _prevStep() {
    HapticFeedback.selectionClick();
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitForm() async {
    HapticFeedback.heavyImpact();
    final parsedAge = int.tryParse(_ageController.text.trim()) ?? _age;

    final profile = SchemeEligibilityProfile(
      age: parsedAge,
      state: _state,
      incomeRange: _isBpl ? 'BPL / EWS' : _incomeRange,
      gender: _gender,
      occupation: _isStudent ? 'Student' : _employmentStatus,
      socialCategory: _socialCategory,
      disability: _hasDisability ? 'Locomotor / Other' : 'None',
      ruralUrban: _residenceArea,
      isMinority: _isMinority,
      isStudent: _isStudent,
      employmentStatus: _employmentStatus,
      isBpl: _isBpl,
      isHardshipDistress: _isHardship,
    );

    final provider = Provider.of<SchemesProvider>(context, listen: false);
    await provider.saveProfileAndEvaluate(profile);

    if (mounted && widget.initialProfile != null) {
      Navigator.of(context).pop();
    }
  }

  void _showInfoDialog(String title, String description) {
    final langProvider = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFF7C3AED), size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: DynamicTranslatedText(
                text: title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: DynamicTranslatedText(
          text: description,
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(langProvider.tr('got_it_btn'), style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.initialProfile != null
          ? AppBar(
              title: Text(langProvider.tr('update_eligibility_title')),
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              elevation: 0,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Badges (myScheme Health Matcher & DB Count)
              _buildTopHeaderBadges(),
              const SizedBox(height: 16),

              // Main Questionnaire Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 20.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 6-Step Stepper Progress Bar
                    _buildStepper(),
                    const SizedBox(height: 18),

                    // Back Button (on steps 2 to 6)
                    if (_currentStep > 0) ...[
                      InkWell(
                        onTap: _prevStep,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                langProvider.tr('back_btn'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Step Title
                    Text(
                      langProvider.tr('help_find_schemes'),
                      style: const TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic Step Content
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _buildCurrentStepWidget(),
                    ),
                    const SizedBox(height: 24),

                    // Navigation Action Buttons (Skip to Results / Next / Submit)
                    _buildActionButtons(),
                    const SizedBox(height: 14),

                    // Reset Form Footer Link
                    Center(
                      child: TextButton.icon(
                        onPressed: _resetForm,
                        icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF64748B)),
                        label: Text(
                          langProvider.tr('reset_form'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Top Header Badges: myScheme Health Matcher
  // =========================================================================
  Widget _buildTopHeaderBadges() {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'myScheme',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            langProvider.tr('health_matcher_title'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 6-Step Stepper Component
  // =========================================================================
  Widget _buildStepper() {
    const totalSteps = 6;
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex < _currentStep;
          final isCurrent = stepIndex == _currentStep;

          if (isCompleted) {
            return Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF7C3AED),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 16,
                color: Colors.white,
              ),
            );
          } else if (isCurrent) {
            return Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFF7C3AED), width: 2.5),
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
            );
          } else {
            return Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.8),
              ),
            );
          }
        } else {
          final completedLine = (index ~/ 2) < _currentStep;
          return Expanded(
            child: Container(
              height: 2.5,
              color: completedLine ? const Color(0xFF7C3AED) : const Color(0xFFE2E8F0),
            ),
          );
        }
      }),
    );
  }

  // =========================================================================
  // Dynamic Step Widgets (1 to 6)
  // =========================================================================
  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Age();
      case 1:
        return _buildStep2State();
      case 2:
        return _buildStep3SocialCategory();
      case 3:
        return _buildStep4DisabilityMinority();
      case 4:
        return _buildStep5StudentEmployment();
      case 5:
        return _buildStep6EconomicStatus();
      default:
        return const SizedBox.shrink();
    }
  }

  // --- STEP 1: AGE (Gender auto-fetched from patient profile) ---
  Widget _buildStep1Age() {
    final langProvider = Provider.of<LanguageProvider>(context);
    return Column(
      key: const ValueKey('step_1'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel('Tell us about yourself, what is your age?'),
        const SizedBox(height: 14),

        // Age Input Box
        Row(
          children: [
            Container(
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF7C3AED), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextFormField(
                controller: _ageController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: Icon(Icons.cake_outlined, size: 22, color: Color(0xFF7C3AED)),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val.trim());
                  if (parsed != null) _age = parsed;
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                langProvider.tr('years_old'),
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // Auto-Fetched Gender from Patient Profile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF7C3AED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DynamicTranslatedText(
                      text: 'GENDER IDENTIFIER',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(height: 2),
                    DynamicTranslatedText(
                      text: '$_gender (auto-fetched from your registered profile)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- STEP 2: STATE (Area of residence auto-fetched from patient profile) ---
  Widget _buildStep2State() {
    return Column(
      key: const ValueKey('step_2'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DynamicTranslatedText(
          text: 'Please select your state',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),

        // State Dropdown
        DropdownButtonFormField<String>(
          initialValue: _state,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _states.map((st) => DropdownMenuItem(value: st, child: DynamicTranslatedText(text: st))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _state = val);
          },
        ),
        const SizedBox(height: 22),

        // Auto-Fetched Area of Residence from Patient Profile
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFF7C3AED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.home_work_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DynamicTranslatedText(
                      text: 'AREA OF RESIDENCE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: Color(0xFF7C3AED),
                      ),
                    ),
                    const SizedBox(height: 2),
                    DynamicTranslatedText(
                      text: '$_residenceArea (auto-fetched from your registered profile)',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- STEP 3: SOCIAL CATEGORY / CASTE ---
  Widget _buildStep3SocialCategory() {
    return Column(
      key: const ValueKey('step_3'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel('You belong to...'),
        const SizedBox(height: 12),

        ..._socialCategories.map((category) {
          final isSelected = _socialCategory == category;
          final hasInfo = category != 'General' && category != 'De-Notified, Nomadic, and Semi-Nomadic (DNT) communities';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _socialCategory = category);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: DynamicTranslatedText(
                        text: category,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    if (hasInfo || category.contains('DNT') || category.contains('PVTG'))
                      IconButton(
                        icon: const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          _showInfoDialog(
                            category,
                            'Government health benefits, premium exemptions, and tribal welfare subsidies are customized for citizens belonging to $category.',
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- STEP 4: DISABILITY & MINORITY ---
  Widget _buildStep4DisabilityMinority() {
    return Column(
      key: const ValueKey('step_4'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildRequiredLabel('Do you identify as a person with a disability?'),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _showInfoDialog(
                  'Person with Disability (PwD)',
                  'Covers locomotor, visual, hearing, intellectual, and multiple disabilities for specialized assistive equipment & healthcare insurance schemes.',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectableCard(
                title: 'Yes',
                isSelected: _hasDisability,
                onTap: () => setState(() => _hasDisability = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectableCard(
                title: 'No',
                isSelected: !_hasDisability,
                onTap: () => setState(() => _hasDisability = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        Row(
          children: [
            Expanded(
              child: _buildRequiredLabel('Do you belong to minority?'),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                _showInfoDialog(
                  'Minority Community',
                  'Recognized minority communities under the National Commission for Minorities Act (Muslim, Christian, Sikh, Buddhist, Parsi, Jain).',
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectableCard(
                title: 'Yes',
                isSelected: _isMinority,
                onTap: () => setState(() => _isMinority = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectableCard(
                title: 'No',
                isSelected: !_isMinority,
                onTap: () => setState(() => _isMinority = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- STEP 5: STUDENT & EMPLOYMENT ---
  Widget _buildStep5StudentEmployment() {
    return Column(
      key: const ValueKey('step_5'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel('Are you a student?'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectableCard(
                title: 'Yes',
                isSelected: _isStudent,
                onTap: () => setState(() => _isStudent = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectableCard(
                title: 'No',
                isSelected: !_isStudent,
                onTap: () => setState(() => _isStudent = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        _buildRequiredLabel('What is your current employment status?'),
        const SizedBox(height: 12),

        ...['Employed', 'Unemployed', 'Self-Employed/ Entrepreneur'].map((status) {
          final isSelected = _employmentStatus == status;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _employmentStatus = status);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
                    width: isSelected ? 2.0 : 1.2,
                  ),
                ),
                child: DynamicTranslatedText(
                  text: status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- STEP 6: ECONOMIC STATUS & BPL ---
  Widget _buildStep6EconomicStatus() {
    return Column(
      key: const ValueKey('step_6'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequiredLabel('Do you belong to BPL category?'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectableCard(
                title: 'Yes',
                isSelected: _isBpl,
                onTap: () => setState(() => _isBpl = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectableCard(
                title: 'No',
                isSelected: !_isBpl,
                onTap: () => setState(() => _isBpl = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        _buildRequiredLabel(
          'Are you in any of the following condition – Destitute /Penury /Extreme Hardship /Distress',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildSelectableCard(
                title: 'Yes',
                isSelected: _isHardship,
                onTap: () => setState(() => _isHardship = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSelectableCard(
                title: 'No',
                isSelected: !_isHardship,
                onTap: () => setState(() => _isHardship = false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Approximate Annual Family Income (From existing questions)
        const DynamicTranslatedText(
          text: 'Annual Family Income (approximate)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _incomeRange,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _incomeRanges.map((inc) => DropdownMenuItem(value: inc, child: DynamicTranslatedText(text: inc))).toList(),
          onChanged: (val) {
            if (val != null) setState(() => _incomeRange = val);
          },
        ),
      ],
    );
  }

  // =========================================================================
  // Reusable UI Components
  // =========================================================================
  Widget _buildRequiredLabel(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '* ',
          style: TextStyle(
            color: Color(0xFFDC2626),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        Expanded(
          child: DynamicTranslatedText(
            text: text,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectableCard({
    required String title,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: icon != null ? 85 : 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF5F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFCBD5E1),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 26,
                color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 4),
            ],
            DynamicTranslatedText(
              text: title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isLastStep = _currentStep == 5;
    final langProvider = Provider.of<LanguageProvider>(context);

    return Row(
      children: [
        // Skip to Results (Outlined Button)
        Expanded(
          child: OutlinedButton(
            onPressed: _submitForm,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFF7C3AED), width: 1.6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              langProvider.tr('skip_to_results'),
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF7C3AED),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Next or Submit (Filled Primary Button)
        Expanded(
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 2,
              shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isLastStep ? '${langProvider.tr('submit_btn')} →' : '${langProvider.tr('next_btn')} →',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
