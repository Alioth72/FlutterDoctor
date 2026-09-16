import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/family_member.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/health_profile.dart';
import 'storage_service.dart';

/// Database integration service for patient authentication,
/// registration, and read-only medical data fetching.
///
/// Connects to Azure Functions backend (https://fn-rural-healthcare-3357.azurewebsites.net/api)
/// and falls back gracefully to deterministic local models when offline.
class PatientDatabaseService {
  /// Base URL for backend database API.
  final String apiBaseUrl;
  final http.Client _httpClient;
  final StorageService _storageService;

  PatientDatabaseService({
    String? baseUrl,
    http.Client? httpClient,
    StorageService? storageService,
  })  : apiBaseUrl = baseUrl ??
            const String.fromEnvironment(
              'PATIENT_API_BASE_URL',
              defaultValue: 'https://fn-rural-healthcare-3357.azurewebsites.net/api',
            ),
        _httpClient = httpClient ?? http.Client(),
        _storageService = storageService ?? StorageService();

  /// Global timeout for Azure Functions / network calls (cold starts take up to 15s)
  static const Duration requestTimeout = Duration(seconds: 25);

  /// Available locations in India
  static const List<String> availableLocations = [
    'New Delhi, Delhi',
    'Noida, Uttar Pradesh',
    'Gurugram, Haryana',
    'Mumbai, Maharashtra',
    'Bengaluru, Karnataka',
    'Kolkata, West Bengal',
    'Chennai, Tamil Nadu',
    'Hyderabad, Telangana',
    'Lucknow, Uttar Pradesh',
    'Jaipur, Rajasthan',
    'Pune, Maharashtra',
    'Ahmedabad, Gujarat',
    'Chandigarh, Punjab',
    'Patna, Bihar',
    'Bhopal, Madhya Pradesh',
    'Indore, Madhya Pradesh',
    'Kochi, Kerala',
    'Guwahati, Assam',
    'Bhubaneswar, Odisha',
    'Dehradun, Uttarakhand',
    'Ranchi, Jharkhand',
    'Varanasi, Uttar Pradesh',
  ];

  /// Authenticate Patient against Azure Functions: POST /auth/login
  /// Stores JWT token & patient ID, fetches profile via GET /me, and returns HealthProfile.
  Future<HealthProfile> loginUser({
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final payload = {
      'phone': cleanPhone.isNotEmpty ? cleanPhone : phoneNumber.trim(),
      'password': password.trim().isNotEmpty ? password : 'Patient@12345',
      'role': 'patient',
    };

    debugPrint('[PatientDatabaseService] POST /auth/login -> phone: $cleanPhone');

    try {
      final url = Uri.parse('$apiBaseUrl/auth/login');
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      debugPrint('[PatientDatabaseService] Login status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        final userData = (data['data'] is Map) ? data['data'] as Map<String, dynamic> : <String, dynamic>{};

        if (token != null && token.isNotEmpty) {
          await _storageService.saveAuthToken(token);
        }

        String? patientId = userData['patient_id'] as String?;
        if ((patientId == null || patientId.isEmpty) && token != null) {
          patientId = _extractPatientIdFromToken(token);
        }
        if (patientId != null && patientId.isNotEmpty) {
          await _storageService.savePatientId(patientId);
        }

        // Fetch rich live patient profile from /me
        if (token != null && token.isNotEmpty) {
          try {
            final meProfile = await fetchMyProfile();
            if (meProfile != null) {
              return meProfile;
            }
          } catch (meError) {
            debugPrint('[PatientDatabaseService] Error fetching live /me profile: $meError');
          }
        }

        // Build profile from login response data
        final fullName = (userData['full_name'] as String?)?.trim() ?? (name.trim().isNotEmpty ? name.trim() : 'Patient');
        final mrn = userData['medical_record_number'] as String?;
        final bloodGroup = userData['blood_group'] as String?;

        return HealthProfile(
          name: fullName,
          age: 28,
          gender: 'Other',
          phoneNumber: phoneNumber.trim(),
          patientId: patientId,
          password: password,
          location: availableLocations.first,
          tier2Data: {
            if (mrn != null) 'medical_record_number': mrn,
            if (bloodGroup != null) 'blood_group': bloodGroup,
          },
        );
      } else {
        String errorMsg = 'Invalid phone number or password.';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['error'] != null) errorMsg = data['error'].toString();
        } catch (_) {}
        debugPrint('[PatientDatabaseService] Login rejected: ${response.body}');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] Live login failed: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server took too long to respond. Please check your internet connection and try again.');
      }
      rethrow;
    }
  }

  /// Register new patient account on Azure Functions backend: POST /auth/signup
  Future<HealthProfile> registerUser(HealthProfile profile) async {
    final cleanPhone = profile.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final birthYear = DateTime.now().year - profile.age;
    final dobStr = '$birthYear-01-01';

    final payload = {
      'phone': cleanPhone.isNotEmpty ? cleanPhone : profile.phoneNumber.trim(),
      'full_name': profile.name.trim(),
      'password': (profile.password != null && profile.password!.trim().isNotEmpty)
          ? profile.password!
          : 'Patient@12345',
      'role': 'patient',
      'date_of_birth': dobStr,
      'sex_at_birth': profile.gender.toLowerCase(),
      'preferred_language': 'en',
    };
    debugPrint('[PatientDatabaseService] POST /auth/signup -> phone: $cleanPhone, name: ${profile.name}');

    try {
      final url = Uri.parse('$apiBaseUrl/auth/signup');
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      debugPrint('[PatientDatabaseService] Signup response status: ${response.statusCode}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final token = data['token'] as String?;
        final userData = (data['data'] is Map) ? data['data'] as Map<String, dynamic> : <String, dynamic>{};

        if (token != null && token.isNotEmpty) {
          await _storageService.saveAuthToken(token);
        }

        String? patientId = userData['patient_id'] as String?;
        if ((patientId == null || patientId.isEmpty) && token != null) {
          patientId = _extractPatientIdFromToken(token);
        }
        if (patientId != null && patientId.isNotEmpty) {
          await _storageService.savePatientId(patientId);
        }

        return profile.copyWith(
          patientId: patientId,
          tier2Data: {
            if (userData['medical_record_number'] != null)
              'medical_record_number': userData['medical_record_number'],
          },
        );
      } else if (response.statusCode == 409) {
        debugPrint('[PatientDatabaseService] User already exists (409), logging in...');
        return await loginUser(
          name: profile.name,
          phoneNumber: profile.phoneNumber,
          password: profile.password ?? 'Patient@12345',
        );
      } else {
        String errorMsg = 'Signup failed (${response.statusCode})';
        try {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['error'] != null) errorMsg = data['error'].toString();
        } catch (_) {}
        debugPrint('[PatientDatabaseService] Signup rejected: ${response.body}');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] Live signup error: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Server took too long to respond. Please try again in a few seconds.');
      }
      rethrow;
    }
  }

  /// Open Database Endpoint: Update User Location
  /// PATCH /patient/location
  /// Payload: { "phoneNumber": phoneNumber, "location": newLocation }
  Future<bool> updateUserLocation({
    required String phoneNumber,
    required String newLocation,
  }) async {
    final payload = {
      'phoneNumber': phoneNumber,
      'location': newLocation,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    debugPrint('[PatientDatabaseService] PATCH /patient/location -> $payload');

    try {
      final url = Uri.parse('$apiBaseUrl/patient/location');
      final response = await _httpClient
          .patch(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[PatientDatabaseService] Location update dispatched (offline fallback): $e');
      return true;
    }
  }

  /// Read-only endpoint: Fetch authenticated patient's live profile
  /// GET /me (requires Bearer token)
  Future<HealthProfile?> fetchMyProfile() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) return null;

    try {
      final url = Uri.parse('$apiBaseUrl/me');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final data = (body['data'] is Map) ? body['data'] as Map<String, dynamic> : body;

        final fullName = (data['full_name'] as String?)?.trim() ?? 'Patient';
        final phone = (data['phone_e164'] as String?) ?? '';
        final patientId = data['patient_id'] as String?;
        final mrn = data['medical_record_number'] as String?;
        final bloodGroup = data['blood_group'] as String?;
        final allergies = (data['allergies'] is List)
            ? List<String>.from(data['allergies'])
            : <String>[];
        final dobStr = data['date_of_birth'] as String?;
        int calculatedAge = 28;
        if (dobStr != null) {
          final dob = DateTime.tryParse(dobStr);
          if (dob != null) {
            calculatedAge = DateTime.now().year - dob.year;
          }
        }
        final sex = (data['sex_at_birth'] as String? ?? 'Other').toLowerCase();
        final gender = sex == 'female' ? 'Female' : (sex == 'male' ? 'Male' : 'Other');

        return HealthProfile(
          name: fullName,
          age: calculatedAge,
          gender: gender,
          phoneNumber: phone,
          patientId: patientId,
          location: availableLocations.first,
          tier2Data: {
            if (mrn != null) 'medical_record_number': mrn,
            if (bloodGroup != null) 'blood_group': bloodGroup,
            if (allergies.isNotEmpty) 'allergies': allergies,
            if (dobStr != null) 'date_of_birth': dobStr,
            if (data['emergency_contact'] != null) 'emergency_contact': data['emergency_contact'],
          },
        );
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] fetchMyProfile error: $e');
    }
    return null;
  }

  /// Read-only endpoint: Fetch authenticated patient's appointments
  /// GET /me/appointments (enforces auth.patient_id ownership on backend)
  Future<List<Appointment>?> fetchMyAppointments() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      debugPrint('[PatientDatabaseService] fetchMyAppointments: No auth token (keeping local appointments)');
      return null;
    }

    try {
      final url = Uri.parse('$apiBaseUrl/me/appointments');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      debugPrint('[PatientDatabaseService] fetchMyAppointments status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['data'] is List
            ? body['data'] as List
            : (body['appointments'] is List ? body['appointments'] as List : []);
        final appointments = <Appointment>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            try {
              appointments.add(Appointment.fromDatabaseJson(item));
            } catch (err, stack) {
              debugPrint('[PatientDatabaseService] Error parsing appointment: $err\nItem: $item\n$stack');
            }
          }
        }
        return appointments;
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] fetchMyAppointments network error: $e');
      return null;
    }
    return null;
  }

  /// Read-only endpoint: Fetch authenticated patient's medical records
  /// GET /me/records
  Future<List<Map<String, dynamic>>> fetchMyRecords() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) return [];

    try {
      final url = Uri.parse('$apiBaseUrl/me/records');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['data'] is List ? body['data'] as List : [];
        return rawList.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] fetchMyRecords error: $e');
    }
    return [];
  }

  /// Read-only endpoint: Fetch authenticated patient's prescriptions
  /// GET /me/prescriptions
  Future<List<Map<String, dynamic>>> fetchMyPrescriptions() async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) return [];

    try {
      final url = Uri.parse('$apiBaseUrl/me/prescriptions');
      final response = await _httpClient.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(requestTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['data'] is List ? body['data'] as List : [];
        return rawList.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] fetchMyPrescriptions error: $e');
    }
    return [];
  }

  /// Open Database Endpoint: Fetch Profile by phone number
  /// GET /patient/profile?phoneNumber={phoneNumber}
  Future<HealthProfile?> fetchUserProfile({required String phoneNumber}) async {
    try {
      final url = Uri.parse('$apiBaseUrl/patient/profile?phoneNumber=$phoneNumber');
      final response = await _httpClient
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return HealthProfile.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Open Database Endpoint: Link & Sync Family Member
  /// POST /patient/family/sync
  /// Payload: { "patientId": currentPatientId, "name": name, "memberPatientId": memberPatientId, "relation": relation }
  Future<FamilyMember?> syncFamilyMember({
    required String currentPatientId,
    required String name,
    required String memberPatientId,
    required String relation,
  }) async {
    final payload = {
      'patientId': currentPatientId,
      'name': name,
      'memberPatientId': memberPatientId,
      'relation': relation,
      'syncedAt': DateTime.now().toIso8601String(),
    };
    debugPrint('[PatientDatabaseService] POST /patient/family/sync -> $payload');

    try {
      final url = Uri.parse('$apiBaseUrl/patient/family/sync');
      final response = await _httpClient
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FamilyMember.fromJson(data);
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] Family sync offline fallback: $e');
    }

    // Deterministic fallback response for offline testing
    return FamilyMember(
      id: 'FAM-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      patientId: memberPatientId.toUpperCase().trim(),
      relation: relation,
      syncedAt: DateTime.now(),
      isSynced: true,
    );
  }

  /// Open Database Endpoint: Fetch Synced Family Members
  /// GET /patient/family?patientId={currentPatientId}
  Future<List<FamilyMember>> fetchFamilyMembers({required String currentPatientId}) async {
    debugPrint('[PatientDatabaseService] GET /patient/family?patientId=$currentPatientId');
    try {
      final url = Uri.parse('$apiBaseUrl/patient/family?patientId=$currentPatientId');
      final response = await _httpClient
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(requestTimeout);

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((e) => FamilyMember.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] Fetch family offline fallback: $e');
    }

    return [];
  }

  /// Open Database Endpoint: Remove/Unlink Family Member
  /// DELETE /patient/family/{memberId}?patientId={currentPatientId}
  Future<bool> removeFamilyMember({
    required String currentPatientId,
    required String memberId,
  }) async {
    debugPrint('[PatientDatabaseService] DELETE /patient/family/$memberId?patientId=$currentPatientId');
    try {
      final url = Uri.parse('$apiBaseUrl/patient/family/$memberId?patientId=$currentPatientId');
      final response = await _httpClient
          .delete(url, headers: {'Content-Type': 'application/json'})
          .timeout(requestTimeout);

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[PatientDatabaseService] Remove family offline fallback: $e');
      return true;
    }
  }


  /// Fetch live available doctors from backend database: GET /staff/doctors
  Future<List<Doctor>> fetchDoctors() async {
    final token = await _storageService.getAuthToken();
    try {
      final url = Uri.parse('$apiBaseUrl/staff/doctors');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _httpClient.get(url, headers: headers).timeout(requestTimeout);
      debugPrint('[PatientDatabaseService] fetchDoctors status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['data'] is List ? body['data'] as List : [];
        final doctors = <Doctor>[];
        for (final item in rawList) {
          if (item is Map<String, dynamic>) {
            doctors.add(Doctor.fromDatabaseJson(item));
          }
        }
        if (doctors.isNotEmpty) return doctors;
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] fetchDoctors error: $e');
    }
    return [];
  }

  /// Fetch live doctor availability slots from backend: GET /doctors/{id}/availability?date={date}
  Future<List<DoctorAvailabilitySlot>> fetchDoctorAvailability(String doctorId, String date) async {
    final token = await _storageService.getAuthToken();
    try {
      final url = Uri.parse('$apiBaseUrl/doctors/$doctorId/availability?date=$date');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _httpClient.get(url, headers: headers).timeout(requestTimeout);
      debugPrint('[PatientDatabaseService] fetchDoctorAvailability status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = body['data'] is List ? body['data'] as List : [];
        return rawList
            .whereType<Map<String, dynamic>>()
            .map((item) => DoctorAvailabilitySlot.fromJson(item))
            .toList();
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] fetchDoctorAvailability error: $e');
    }
    return [];
  }

  /// Request secure telehealth session access & join window authorization
  /// POST /appointments/{id}/telehealth-access
  Future<Map<String, dynamic>> requestTelehealthAccess(String appointmentId) async {
    final token = await _storageService.getAuthToken();
    try {
      final url = Uri.parse('$apiBaseUrl/appointments/$appointmentId/telehealth-access');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _httpClient
          .post(url, headers: headers, body: jsonEncode({}))
          .timeout(requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Consultation join window is not open.',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }

  /// Save Pre-Call rPPG heart rate & waveform to backend linked to appointment
  /// POST /appointments/{id}/pre-call-vitals
  Future<Map<String, dynamic>> savePreCallVitals(
    String appointmentId, {
    required double bpm,
    required List<double> waveform,
    DateTime? measuredAt,
  }) async {
    final token = await _storageService.getAuthToken();
    try {
      final url = Uri.parse('$apiBaseUrl/appointments/$appointmentId/pre-call-vitals');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final body = {
        'heart_rate_bpm': bpm,
        'rppg_waveform': waveform,
        'measured_at': (measuredAt ?? DateTime.now()).toUtc().toIso8601String(),
        'source': 'Camera rPPG',
      };

      final response = await _httpClient
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(requestTimeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'data': data['data']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to save pre-call vitals (${response.statusCode})',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }

  /// Get Pre-Call rPPG vitals for an appointment
  /// GET /appointments/{id}/pre-call-vitals
  Future<Map<String, dynamic>?> getPreCallVitals(String appointmentId) async {
    final token = await _storageService.getAuthToken();
    try {
      final url = Uri.parse('$apiBaseUrl/appointments/$appointmentId/pre-call-vitals');
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await _httpClient.get(url, headers: headers).timeout(requestTimeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['data'] != null) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('[PatientDatabaseService] getPreCallVitals error: $e');
    }
    return null;
  }

  /// Safely extracts patient_id from JWT token payload without network calls
  String? _extractPatientIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final normalized = base64Url.normalize(parts[1]);
        final payloadString = utf8.decode(base64Url.decode(normalized));
        final Map<String, dynamic> payload = jsonDecode(payloadString);
        return payload['patient_id'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// Book Appointment on Azure Functions backend: POST /appointments
  Future<Appointment> bookAppointment(Appointment appointment) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in to book an appointment.');
    }

    String? patientId = await _storageService.getPatientId();

    if (patientId == null || patientId.length < 32) {
      patientId = _extractPatientIdFromToken(token);
      if (patientId != null && patientId.length >= 32) {
        await _storageService.savePatientId(patientId);
      }
    }

    if (patientId == null || patientId.length < 32) {
      try {
        final profile = await fetchMyProfile();
        patientId = profile?.patientId;
        if (patientId != null && patientId.length >= 32) {
          await _storageService.savePatientId(patientId);
        }
      } catch (_) {}
    }

    final apptType = (appointment.isOnline || appointment.appointmentType.toLowerCase() == 'telehealth')
        ? 'telehealth'
        : 'clinic';

    final payload = {
      if (patientId != null && patientId.isNotEmpty) 'patient_id': patientId,
      'provider_user_id': appointment.doctorId,
      'appointment_type': apptType,
      'scheduled_start': appointment.scheduledDateTime.toIso8601String(),
      'time_slot': appointment.timeSlot,
      'appointment_date': appointment.appointmentDate,
      'reason': appointment.reason,
      'source': 'online',
      'notes': {
        'appointment_no': appointment.tokenNumber,
        'slot_time': appointment.timeSlot,
        'appointment_date': appointment.appointmentDate,
        'consultation_fee': appointment.consultationFee,
        'doctor_specialty': appointment.doctorSpecialty,
      },
    };

    debugPrint('[PatientDatabaseService] POST /appointments -> $payload');

    final url = Uri.parse('$apiBaseUrl/appointments');
    final response = await _httpClient
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);

    debugPrint('[PatientDatabaseService] Book appointment response: ${response.statusCode}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final apptData = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
      return Appointment.fromDatabaseJson(apptData);
    } else if (response.statusCode == 409) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final errorMsg = data['error']?.toString() ??
          'Time slot is full (maximum 3 patients per 30-minute slot). Please select another slot.';
      throw SlotFullException(errorMsg);
    } else {
      String errorMsg = 'Failed to book appointment on backend (${response.statusCode})';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) errorMsg = data['error'].toString();
      } catch (_) {}
      debugPrint('[PatientDatabaseService] Booking rejected: ${response.body}');
      throw Exception(errorMsg);
    }
  }

  /// Request an ASHA Worker Home Visit on backend: POST /appointments
  /// appointment_type: 'home_visit', status: 'queued'
  Future<Appointment> requestAshaVisit({
    required String reason,
    required String urgency,
    String? address,
    Map<String, dynamic>? symptomsData,
  }) async {
    final token = await _storageService.getAuthToken();
    if (token == null || token.isEmpty) {
      throw Exception('Authentication required. Please log in to request an ASHA visit.');
    }

    String? patientId = await _storageService.getPatientId();
    if (patientId == null || patientId.length < 32) {
      patientId = _extractPatientIdFromToken(token);
      if (patientId != null && patientId.length >= 32) {
        await _storageService.savePatientId(patientId);
      }
    }

    if (patientId == null || patientId.length < 32) {
      try {
        final profile = await fetchMyProfile();
        patientId = profile?.patientId;
        if (patientId != null && patientId.length >= 32) {
          await _storageService.savePatientId(patientId);
        }
      } catch (_) {}
    }

    final now = DateTime.now();
    final payload = {
      if (patientId != null && patientId.isNotEmpty) 'patient_id': patientId,
      'provider_user_id': null,
      'appointment_type': 'home_visit',
      'scheduled_start': now.toIso8601String(),
      'status': 'queued',
      'reason': reason,
      'source': 'online',
      'notes': {
        'request_type': 'asha_visit',
        'urgency': urgency,
        'patient_address': address ?? '',
        if (symptomsData != null) 'symptoms_data': symptomsData,
        'requested_at': now.toIso8601String(),
      },
    };

    debugPrint('[PatientDatabaseService] POST /appointments (ASHA visit request) -> $payload');

    final url = Uri.parse('$apiBaseUrl/appointments');
    final response = await _httpClient
        .post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(requestTimeout);

    debugPrint('[PatientDatabaseService] ASHA visit request response: ${response.statusCode}');

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final apptData = data['data'] is Map ? data['data'] as Map<String, dynamic> : data;
      return Appointment.fromDatabaseJson(apptData);
    } else {
      String errorMsg = 'Failed to request ASHA visit (${response.statusCode})';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] != null) errorMsg = data['error'].toString();
      } catch (_) {}
      throw Exception(errorMsg);
    }
  }
}

class SlotFullException implements Exception {
  final String message;
  SlotFullException(this.message);
  @override
  String toString() => message;
}

