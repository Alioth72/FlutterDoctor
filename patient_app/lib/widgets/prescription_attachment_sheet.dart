import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../screens/prescription/prescription_camera_screen.dart';

/// Bottom sheet allowing user to attach a prescription via:
/// 1. Open Camera to click a photo
/// 2. Attach a file from device
/// 3. Choose from preloaded clinical OPD samples
class PrescriptionAttachmentSheet extends StatelessWidget {
  final Function(Map<String, dynamic> result) onPrescriptionSelected;

  const PrescriptionAttachmentSheet({
    super.key,
    required this.onPrescriptionSelected,
  });

  static void show(BuildContext context, {required Function(Map<String, dynamic> result) onSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PrescriptionAttachmentSheet(onPrescriptionSelected: onSelected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 42,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE9FE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF7C3AED), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attach Doctor Prescription',
                      style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                    ),
                    Text(
                      'Scan will detect medicines & dosage timing',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Option 1: Open Camera (and click a photo)
          _buildOptionCard(
            context,
            icon: Icons.camera_alt_rounded,
            iconGradient: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            title: 'Open Camera & Click Photo',
            subtitle: 'Align prescription within camera viewfinder & tap shutter',
            badge: 'RECOMMENDED',
            badgeColor: const Color(0xFF16A34A),
            onTap: () async {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
              final result = await Navigator.push<Map<String, dynamic>>(
                context,
                MaterialPageRoute(builder: (_) => const PrescriptionCameraScreen()),
              );
              if (result != null) {
                onPrescriptionSelected(result);
              }
            },
          ),
          const SizedBox(height: 12),

          // Option 2: Attach File / Choose Image
          _buildOptionCard(
            context,
            icon: Icons.attach_file_rounded,
            iconGradient: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            title: 'Attach File / Device Image',
            subtitle: 'Select prescription slip (JPG, PNG, PDF) from your phone',
            badge: 'INSTANT FILE',
            badgeColor: const Color(0xFF0284C7),
            onTap: () => _handlePickImage(context),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePickImage(BuildContext context) async {
    HapticFeedback.lightImpact();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 90,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (context.mounted) Navigator.pop(context);
        onPrescriptionSelected({
          'source': 'file_attached',
          'imageBytes': bytes,
          'title': 'Attached Prescription (File)',
        });
      }
    } on PlatformException catch (e) {
      debugPrint('Image picker PlatformException: ${e.code} - ${e.message}');
      if (!context.mounted) return;
      _showRestartRequiredDialog(context, e.message ?? e.toString());
    } catch (e) {
      debugPrint('Image picker error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open image picker: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showRestartRequiredDialog(BuildContext context, String detail) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: Color(0xFF2563EB), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Full App Restart Needed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new native plugin (image_picker) was added. Flutter Hot Reload and Hot Restart cannot connect new native Android plugins while the existing app process is running.\n\n'
              'Please perform a full restart:\n'
              '1. Stop the running app (click the red Stop ⏹ button in your IDE or Ctrl+C in terminal)\n'
              '2. Start the app afresh (flutter run)',
              style: TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF334155)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK, I understand'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: iconGradient),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 16),
          ],
        ),
      ),
    );
  }
}
