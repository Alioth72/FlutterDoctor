import 'dart:convert';
import 'dart:io';

import '../../domain/models/patient_profile.dart';
import '../../domain/repositories/patient_repository.dart';

/// Real HTTP repository connecting to Azure Functions (local or deployed).
///
/// Local Android Emulator: `http://10.0.2.2:7071/api`
/// Local iOS Simulator / macOS: `http://localhost:7071/api`
/// Deployed Azure: `https://<your-app>.azurewebsites.net/api`
class AzureFunctionPatientRepository implements PatientRepository {
  final String baseUrl;
  final String? authToken;
  final HttpClient _httpClient;

  AzureFunctionPatientRepository({
    this.baseUrl = 'http://10.0.2.2:7071/api',
    this.authToken,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  @override
  Future<PatientProfile?> getActivePatientProfile({String? patientId}) async {
    final id = patientId ?? 'b0843210-91ab-4ef1-bb74-001928475001';
    final uri = Uri.parse('$baseUrl/patients/$id');

    try {
      final request = await _httpClient.getUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $authToken');
      }

      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
        return PatientProfile.fromJson(jsonMap);
      } else {
        // ignore: avoid_print
        print('AzureFunctionPatientRepository: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // ignore: avoid_print
      print('AzureFunctionPatientRepository: Error fetching patient: $e');
      return null;
    }
  }

  @override
  Future<bool> updatePatientVitals({
    required String patientId,
    required Map<String, dynamic> vitals,
  }) async {
    final uri = Uri.parse('$baseUrl/patients/$patientId/vitals');

    try {
      final request = await _httpClient.postUrl(uri);
      request.headers.set('Content-Type', 'application/json');
      if (authToken != null && authToken!.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer $authToken');
      }
      request.write(jsonEncode(vitals));

      final response = await request.close();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      // ignore: avoid_print
      print('AzureFunctionPatientRepository: Error updating vitals: $e');
      return false;
    }
  }
}
