import 'package:flutter_test/flutter_test.dart';
import 'package:sih_project/services/permissions/app_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPermissionService Tests', () {
    test('hasMicrophonePermission returns a boolean without throwing', () async {
      final hasMic = await AppPermissionService.hasMicrophonePermission();
      expect(hasMic, isA<bool>());
    });

    test('hasCameraPermission returns a boolean without throwing', () async {
      final hasCamera = await AppPermissionService.hasCameraPermission();
      expect(hasCamera, isA<bool>());
    });

    test('requestMicrophonePermission completes cleanly in headless environment', () async {
      final result = await AppPermissionService.requestMicrophonePermission();
      expect(result, isA<bool>());
    });

    test('requestCameraPermission completes cleanly in headless environment', () async {
      final result = await AppPermissionService.requestCameraPermission(
        featureName: 'Prescription Scanner',
      );
      expect(result, isA<bool>());
    });

    test('requestCameraAndMicPermissions completes cleanly in headless environment', () async {
      final result = await AppPermissionService.requestCameraAndMicPermissions();
      expect(result, isA<bool>());
    });
  });
}
