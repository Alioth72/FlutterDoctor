import 'package:flutter/material.dart';
import '../appointments/book_appointment_screen.dart';
import '../../widgets/patient_action_sheets.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 6.0, 16.0, 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. NEWS FLASH & REMINDER Top Banners (as in sketch)
                  Row(
                    children: [
                      // NEWS FLASH Banner
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCDD2), // Soft pink/coral as in drawing
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                offset: const Offset(1, 2),
                                blurRadius: 3,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.campaign_rounded, size: 24, color: Colors.black87),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'NEWS FLASH',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.1,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      'Free health camp this Sunday...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.black.withValues(alpha: 0.7),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // REMINDER Pill
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Next Reminder: Blood Pressure check at 06:00 PM'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 56,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFCDD2), // Soft pink/coral
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.black.withValues(alpha: 0.8), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.06),
                                  offset: const Offset(1, 2),
                                  blurRadius: 3,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_active_outlined, size: 18, color: Colors.black87),
                                SizedBox(width: 6),
                                Text(
                                  'REMINDER',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 2. 2x2 Grid of Big Service Cards (Spacious & Vertically Balanced)
                  Column(
                    children: [
                      // Row 1: Book Appointment + Buy Medicines
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: _buildBigServiceCard(
                                context,
                                title: 'BOOK\nAPPOINTMENT',
                                icon: Icons.calendar_month_rounded,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const BookAppointmentScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: _buildBigServiceCard(
                                context,
                                title: 'BUY MEDICINES',
                                icon: Icons.shopping_bag_outlined,
                                onTap: () => PatientActionSheets.showBuyMedicines(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Row 2: AI Assistant + Emergency
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: _buildBigServiceCard(
                                context,
                                title: 'AI ASSISTANT',
                                icon: Icons.smart_toy_outlined,
                                onTap: () => PatientActionSheets.showAiAssistant(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SizedBox(
                              height: 160,
                              child: _buildBigServiceCard(
                                context,
                                title: 'EMERGENCY',
                                icon: Icons.emergency_rounded,
                                isEmergency: true,
                                onTap: () => PatientActionSheets.showEmergency(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // 3. Bottom 3 Circular Quick-Action Buttons (Lang, contact doctor, voice)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Lang Circle
                      _buildCircleActionButton(
                        context,
                        label: 'LAng',
                        icon: Icons.translate_rounded,
                        onTap: () => PatientActionSheets.showLanguageSelector(context),
                      ),

                      // Contact Doctor Circle (Center prominent)
                      _buildCircleActionButton(
                        context,
                        label: 'contact\ndoctor',
                        icon: Icons.support_agent_rounded,
                        isCenter: true,
                        onTap: () => PatientActionSheets.showContactDoctorSheet(context),
                      ),

                      // Voice Circle
                      _buildCircleActionButton(
                        context,
                        label: 'voice',
                        icon: Icons.mic_rounded,
                        onTap: () => PatientActionSheets.showVoiceAssistant(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Big 2x2 Service Card (Hand-drawn look with clean border & subtle shadow)
  Widget _buildBigServiceCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isEmergency = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isEmergency ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isEmergency ? Colors.red.shade700 : Colors.black.withValues(alpha: 0.85),
            width: isEmergency ? 2.0 : 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              offset: const Offset(2, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 44,
              color: isEmergency ? Colors.red.shade700 : const Color(0xFF00796B),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: isEmergency ? Colors.red.shade900 : Colors.black87,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Circular Action Buttons
  Widget _buildCircleActionButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool isCenter = false,
  }) {
    final size = isCenter ? 88.0 : 78.0;

    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFCDD2), // Soft coral/pink matching the wireframe
          border: Border.all(color: Colors.black.withValues(alpha: 0.85), width: 1.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(2, 3),
              blurRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isCenter ? 26 : 22, color: Colors.black87),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isCenter ? 11 : 11,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
