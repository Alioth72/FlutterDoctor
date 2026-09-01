import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/health_profile_provider.dart';
import '../screens/signup_screen.dart';
import '../screens/tabs/profile_tab.dart';
import '../screens/tabs/schemes_tab.dart';

class PatientDrawer extends StatelessWidget {
  const PatientDrawer({super.key});

  Future<void> _handleResetProfile(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Profile?'),
        content: const Text(
          'This will clear your saved profile and allow you to re-test the signup flow.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset & Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final provider = Provider.of<HealthProfileProvider>(context, listen: false);
      await provider.clearProfile();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SignupScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showInfoModal(BuildContext context, {required String title, required String description, required IconData icon}) {
    Navigator.of(context).pop(); // Close drawer
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
              child: Icon(icon, size: 32, color: Theme.of(ctx).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final profileProvider = Provider.of<HealthProfileProvider>(context);
    final profile = profileProvider.profile;

    return Drawer(
      backgroundColor: const Color(0xFFE8F5E9), // Light soothing healthcare green as shown in wireframe
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  // 1. PROFILE Header Card
                  InkWell(
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Patient Profile')),
                            body: const ProfileTab(),
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF81C784), // Vivid pastel green card
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            offset: const Offset(2, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 1.5),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'PROFILE',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  profile?.name ?? 'Patient',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  profile != null ? '+91 ${profile.phoneNumber}' : '',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. FAMILY DATA Card
                  _buildDrawerButton(
                    context,
                    title: 'FAMILY DATA',
                    onTap: () => _showInfoModal(
                      context,
                      title: 'Family Members Health Data',
                      description: 'Manage health records of parents, spouse, and children. Track hereditary conditions and predictive health risks.',
                      icon: Icons.family_restroom_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 3. GOVT SCHEMES Card
                  _buildDrawerButton(
                    context,
                    title: 'GOVT SCHEMES',
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(title: const Text('Government Schemes')),
                            body: const SchemesTab(),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // 4. VACCINATION Card
                  _buildDrawerButton(
                    context,
                    title: 'VACCINATION',
                    onTap: () => _showInfoModal(
                      context,
                      title: 'Vaccination Services & Tracking',
                      description: 'Track immunization schedules for infants, children, and adult boosters (COVID, Hepatitis, Flu, HPV).',
                      icon: Icons.vaccines_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 5. CHRONIC REMINDER Card (Dialysis, Medicine Tracking, Diabetes etc)
                  InkWell(
                    onTap: () => _showInfoModal(
                      context,
                      title: 'Chronic Patient Care',
                      description: 'Specialized tracking & alarms for Dialysis sessions, daily insulin/glucose logs, Hypertension, and chronic prescription refilling.',
                      icon: Icons.monitor_heart_rounded,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF66BB6A), // Deeper distinct green
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            offset: const Offset(2, 3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHRONIC REMINDER',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '(DIALYSIS, MEDICINE TRACKING, DIABETES ETC)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              color: Colors.black.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Logout / Reset Profile
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(color: colorScheme.error.withValues(alpha: 0.7), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _handleResetProfile(context),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text(
                  'Sign Out / Reset Profile',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerButton(
    BuildContext context, {
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF81C784), // Pastel green as in drawing
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              offset: const Offset(2, 3),
              blurRadius: 4,
            ),
          ],
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
