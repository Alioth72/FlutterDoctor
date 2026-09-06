import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_assets.dart';
import '../models/user_role.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'admin_dashboard_screen.dart';
import 'worker_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _showForm = false;
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    if (!_showForm) {
      setState(() {
        _showForm = true;
      });
      return;
    }

    if (_formKey.currentState?.validate() ?? false) {
      _performLogin();
    }
  }

  void _performLogin() {
    setState(() {
      _isLoading = true;
    });

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    
    final userProfile = AuthService.authenticateUser(phone, password);
    final role = userProfile?.role ?? AuthService.getRoleFromPhoneNumber(phone);

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      Widget destinationScreen;
      switch (role) {
        case UserRole.doctor:
          destinationScreen = DashboardScreen(userProfile: userProfile);
          break;
        case UserRole.worker:
          destinationScreen = WorkerDashboardScreen(userProfile: userProfile);
          break;
        case UserRole.admin:
          destinationScreen = AdminDashboardScreen(userProfile: userProfile);
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destinationScreen),
      );
    });
  }

  void _fillTestCredentials(String phone, String pass) {
    setState(() {
      _phoneController.text = phone;
      _passwordController.text = pass;
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
                // Logo Container matching wireframe
                Container(
                  width: 140,
                  height: 140,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(28),
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
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      AppAssets.logo,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.local_hospital, size: 70, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ASHWINI Title matching wireframe
                const Text(
                  'ASHWINI',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.5,
                    color: AppColors.headingText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Healthcare Intelligence System',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 40),

                // Animated Form / Login Button Transition
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 350),
                  crossFadeState: _showForm
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: _buildInitialLoginButton(),
                  secondChild: _buildLoginForm(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Initial Landing state matching right side of wireframe
  Widget _buildInitialLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.40),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _onLoginPressed,
          child: const Center(
            child: Text(
              'Login',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Expanded Form state matching left side of wireframe (Phone no. & Password)
  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Phone Field
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: 'Enter phone number',
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
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Password Field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter password',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.muted),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
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
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter password';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Submit Button (3D Pop-Out Gradient Button)
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.40),
                  blurRadius: 16,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _isLoading ? null : _performLogin,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Demo quick login helpers
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ActionChip(
                avatar: const Icon(Icons.medical_services_outlined, size: 14, color: AppColors.primary),
                label: const Text('Doctor: 1234567890', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('1234567890', '1'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
              ActionChip(
                avatar: const Icon(Icons.admin_panel_settings_outlined, size: 14, color: Color(0xFF4338CA)),
                label: const Text('Admin: 2345678901', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('2345678901', '1'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
              ActionChip(
                avatar: const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF0D9488)),
                label: const Text('Worker: 3456789012', style: TextStyle(fontSize: 11)),
                onPressed: () => _fillTestCredentials('3456789012', '1'),
                backgroundColor: AppColors.surface,
                side: const BorderSide(color: AppColors.border),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Big Pop-Out Back Button Box
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  setState(() {
                    _showForm = false;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
