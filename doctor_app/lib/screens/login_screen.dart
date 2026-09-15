import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_assets.dart';
import '../models/user_role.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'worker_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginFormKey = GlobalKey<FormState>();

  // Login Controllers
  final TextEditingController _loginPhoneController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _navigateToDashboard(UserProfile userProfile) {
    Widget destinationScreen;
    switch (userProfile.role) {
      case UserRole.doctor:
        destinationScreen = DashboardScreen(userProfile: userProfile);
        break;
      case UserRole.worker:
        destinationScreen = WorkerDashboardScreen(userProfile: userProfile);
        break;
      case UserRole.admin:
        destinationScreen = AdminDashboardScreen(userProfile: userProfile);
        break;
      case UserRole.patient:
        destinationScreen = DashboardScreen(userProfile: userProfile);
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destinationScreen),
    );
  }

  Future<void> _performLogin() async {
    if (_isLoading) return;
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final phone = _loginPhoneController.text.trim();
      final password = _loginPasswordController.text;
      final userProfile = await AuthService.login(phone, password);

      if (userProfile != null && mounted) {
        _navigateToDashboard(userProfile);
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _fillTestCredentials(String phone, String password) {
    setState(() {
      _loginPhoneController.text = phone;
      _loginPasswordController.text = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // App Logo
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      AppAssets.logo,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.local_hospital, size: 60, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title & Subtitle
                const Text(
                  'ASHWINI',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.2,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rural Healthcare Intelligence System',
                  style: TextStyle(fontSize: 12, color: AppColors.muted, letterSpacing: 0.5),
                ),
                const SizedBox(height: 32),

                // Login Form
                _buildLoginForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // LOGIN FORM (PHONE NUMBER + PASSWORD)
  // ==========================================================
  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        children: [
          // Phone Field
          TextFormField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g. +91 99887 76655',
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Please enter your phone number';
              final digits = val.replaceAll(RegExp(r'\D'), '');
              if (digits.length < 10) return 'Enter at least 10 valid digits';
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Password Field with Visibility Toggle
          TextFormField(
            controller: _loginPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter your password',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter your password';
              if (val.length < 8) return 'Password must be at least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Login Button
          _buildSubmitButton(
            title: 'Login',
            onTap: _isLoading ? null : _performLogin,
          ),
          const SizedBox(height: 24),

          // Quick Demo Logins
          const Text('Quick Select Demo Account:', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.medical_services_outlined, size: 14, color: AppColors.primary),
                label: const Text('Doctor: 1234567890', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('1234567890', 'Doctor@12345'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
              ActionChip(
                avatar: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFF4338CA)),
                label: const Text('Admin: 2345678901', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('2345678901', 'Admin@12345'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
              ActionChip(
                avatar: const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF0D9488)),
                label: const Text('Worker: 3456789012', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('3456789012', 'Worker@12345'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
              ActionChip(
                avatar: const Icon(Icons.person_outline, size: 14, color: Color(0xFFE11D48)),
                label: const Text('Patient: 9988776655', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('9988776655', 'Patient@12345'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({required String title, required VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                : Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
