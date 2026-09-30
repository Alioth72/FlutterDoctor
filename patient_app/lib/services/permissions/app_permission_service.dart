import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Centralized permission service managing runtime Audio & Camera permissions.
/// Once granted, Android OS and iOS persist permissions until the app's data is cleared.
class AppPermissionService {
  AppPermissionService._();

  /// Requests microphone permission if not already granted.
  /// If permanently denied, shows an informative dialog with an "Open Settings" button.
  static Future<bool> requestMicrophonePermission({
    BuildContext? context,
  }) async {
    try {
      var status = await Permission.microphone.status;

      if (status.isGranted) {
        return true;
      }

      // Request permission from the OS
      status = await Permission.microphone.request();

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied && context != null && context.mounted) {
        await _showPermissionSettingsDialog(
          context: context,
          title: 'Microphone Permission Needed',
          message:
              'ASHWINI requires microphone access so you can speak your health questions to the AI assistant.\n\nPlease enable Microphone access in your device Settings.',
          icon: Icons.mic_off_rounded,
        );
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('[AppPermissionService] Microphone request note: $e');
      return false;
    }
  }

  /// Requests camera permission if not already granted.
  /// Used for Prescription Scanner, Face Vitals (rPPG), and Doctor Video Calls.
  static Future<bool> requestCameraPermission({
    BuildContext? context,
    String featureName = 'this feature',
  }) async {
    try {
      var status = await Permission.camera.status;

      if (status.isGranted) {
        return true;
      }

      // Request permission from the OS
      status = await Permission.camera.request();

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied && context != null && context.mounted) {
        await _showPermissionSettingsDialog(
          context: context,
          title: 'Camera Permission Needed',
          message:
              'ASHWINI requires camera access to use $featureName.\n\nPlease enable Camera access in your device Settings.',
          icon: Icons.camera_alt_outlined,
        );
      }

      return status.isGranted;
    } catch (e) {
      debugPrint('[AppPermissionService] Camera request note: $e');
      return false;
    }
  }

  /// Requests both Camera and Microphone permissions simultaneously (for Video Consultations).
  static Future<bool> requestCameraAndMicPermissions({
    BuildContext? context,
  }) async {
    try {
      final statuses = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
      final micGranted = statuses[Permission.microphone]?.isGranted ?? false;

      if (cameraGranted && micGranted) {
        return true;
      }

      final cameraPermDenied = statuses[Permission.camera]?.isPermanentlyDenied ?? false;
      final micPermDenied = statuses[Permission.microphone]?.isPermanentlyDenied ?? false;

      if ((cameraPermDenied || micPermDenied) && context != null && context.mounted) {
        await _showPermissionSettingsDialog(
          context: context,
          title: 'Camera & Microphone Needed',
          message:
              'Doctor Video Consultations require both Camera and Microphone access.\n\nPlease enable them in device Settings.',
          icon: Icons.video_call_rounded,
        );
      }

      return cameraGranted && micGranted;
    } catch (e) {
      debugPrint('[AppPermissionService] Camera/Mic request note: $e');
      return false;
    }
  }

  /// Checks if microphone is already granted without prompting.
  static Future<bool> hasMicrophonePermission() async {
    try {
      return await Permission.microphone.isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Checks if camera is already granted without prompting.
  static Future<bool> hasCameraPermission() async {
    try {
      return await Permission.camera.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _showPermissionSettingsDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
  }) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.red.shade700, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            icon: const Icon(Icons.settings, size: 16),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006A6A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
