import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';
import '../models/appointment_model.dart';
import '../models/room_machine_models.dart';
import '../screens/pharmacy_stock_screen.dart';

class ApiClient {
  /// Deployed Azure Function App Base URL for Staging/Demo
  static const String azureStagingBaseUrl = 'https://fn-rural-healthcare-3357.azurewebsites.net/api';

  /// Toggle for local vs Azure backend. Defaults to true (deployed Azure backend).
  /// To use local development backend, pass: --dart-define=USE_AZURE_STAGING=false
  static const bool useAzureStaging = bool.fromEnvironment('USE_AZURE_STAGING', defaultValue: true);

  static String get baseUrl {
    if (useAzureStaging) {
      return azureStagingBaseUrl;
    }
    if (kIsWeb) return 'http://localhost:7071/api';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:7071/api';
    return 'http://localhost:7071/api';
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getStoredToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // ==========================================================
  // APPOINTMENTS
  // ==========================================================
  static Future<List<AppointmentItem>?> getAppointments({
    String? providerUserId,
    String? patientId,
    String? status,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (providerUserId != null && providerUserId.isNotEmpty) {
        queryParams['provider_user_id'] = providerUserId;
      }
      if (patientId != null && patientId.isNotEmpty) {
        queryParams['patient_id'] = patientId;
      }
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final uri = Uri.parse('$baseUrl/appointments').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final list = data['data'] as List;
          return list.map<AppointmentItem>((json) => _mapAppointmentItem(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getAppointments error: $e');
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getAppointmentById(String appointmentId) async {
    try {
      final uri = Uri.parse('$baseUrl/appointments/$appointmentId');
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is Map) {
          return data['data'] as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getAppointmentById error: $e');
    }
    return null;
  }

  static AppointmentItem _mapAppointmentItem(Map<String, dynamic> json) {
    final notes = json['notes'] is Map ? json['notes'] as Map : {};
    final clinicalData = json['clinical_data'] is Map ? json['clinical_data'] as Map : {};

    // Calculate age from DOB if present
    int age = 45;
    if (json['patient_dob'] != null) {
      try {
        final dob = DateTime.parse(json['patient_dob'].toString());
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      } catch (_) {}
    }

    final modeStr = json['appointment_type']?.toString().toLowerCase();
    final mode = (modeStr == 'telehealth') ? AppointmentMode.teleconsultation : AppointmentMode.qr;

    final status = json['status']?.toString().toLowerCase();
    final isCompleted = status == 'completed';

    // Format timing
    String timing = '10:30 AM - Today';
    if (json['scheduled_start'] != null) {
      try {
        final dt = DateTime.parse(json['scheduled_start'].toString()).toLocal();
        final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        final minute = dt.minute.toString().padLeft(2, '0');
        timing = '$hour:$minute $ampm - Today';
      } catch (_) {}
    }

    // Parse height and weight from clinical_data or notes
    double heightCm = 170.0;
    if (clinicalData['height_cm'] != null) {
      heightCm = double.tryParse(clinicalData['height_cm'].toString()) ?? 170.0;
    } else if (notes['height_cm'] != null) {
      heightCm = double.tryParse(notes['height_cm'].toString()) ?? 170.0;
    }

    double weightKg = 70.0;
    if (clinicalData['weight_kg'] != null) {
      weightKg = double.tryParse(clinicalData['weight_kg'].toString()) ?? 70.0;
    } else if (notes['weight_kg'] != null) {
      weightKg = double.tryParse(notes['weight_kg'].toString()) ?? 70.0;
    }

    String familyHistory = clinicalData['family_history']?.toString() ??
        notes['family_history']?.toString() ??
        'No significant hereditary medical conditions reported.';

    String diagnosis = json['mr_diagnosis']?.toString() ??
        json['reason']?.toString() ??
        notes['diagnosis']?.toString() ??
        'Clinical Consultation';

    // Patient History / Allergies from DB
    List<String> patientHistory = [];
    if (json['allergies'] is List && (json['allergies'] as List).isNotEmpty) {
      for (final a in json['allergies']) {
        if (a != null && a.toString().isNotEmpty) {
          patientHistory.add('Allergy: $a');
        }
      }
    }
    if (clinicalData['bp'] != null) {
      patientHistory.add('BP: ${clinicalData['bp']}');
    }
    if (clinicalData['spo2'] != null) {
      patientHistory.add('SpO2: ${clinicalData['spo2']}');
    }
    if (patientHistory.isEmpty) {
      patientHistory = ['General Health Evaluation', 'Routine Checkup'];
    }

    // Medicines from live prescriptions or notes
    List<MedicineItem> medicines = [];
    if (json['prescriptions'] is List && (json['prescriptions'] as List).isNotEmpty) {
      for (final rx in json['prescriptions']) {
        if (rx is Map) {
          medicines.add(MedicineItem(
            name: rx['medication_name']?.toString() ?? rx['name']?.toString() ?? 'Medication',
            dosage: rx['dosage']?.toString() ?? rx['frequency']?.toString() ?? '1-0-1',
            duration: rx['duration_days'] != null ? '${rx['duration_days']} Days' : (rx['duration']?.toString() ?? '5 Days'),
            closestClinic: rx['closest_clinic']?.toString() ?? rx['closestClinic']?.toString() ?? json['facility_name']?.toString() ?? 'Ashwini Central Pharmacy (In-Stock)',
          ));
        }
      }
    } else if (notes['medicines'] is List && (notes['medicines'] as List).isNotEmpty) {
      for (final rx in notes['medicines']) {
        if (rx is Map) {
          medicines.add(MedicineItem(
            name: rx['name']?.toString() ?? rx['medication_name']?.toString() ?? 'Medication',
            dosage: rx['dosage']?.toString() ?? rx['frequency']?.toString() ?? '1-0-1',
            duration: rx['duration']?.toString() ?? (rx['duration_days'] != null ? '${rx['duration_days']} Days' : '5 Days'),
            closestClinic: rx['closestClinic']?.toString() ?? rx['closest_clinic']?.toString() ?? json['facility_name']?.toString() ?? 'Ashwini Central Pharmacy (In-Stock)',
          ));
        }
      }
    }
    if (medicines.isEmpty && (json['status']?.toString().toLowerCase() != 'completed')) {
      medicines.add(MedicineItem(
        name: 'Paracetamol 650mg (SOS)',
        dosage: '1-0-1 as needed',
        duration: '3 Days',
        closestClinic: json['facility_name']?.toString() ?? 'Ashwini Central Pharmacy (In-Stock)',
      ));
    }

    // Inpatient details from notes
    final bool isAdmitted = notes['is_admitted'] == true;
    final String? roomNo = notes['room_no']?.toString();
    final String? dietarySuggestions = notes['dietary_suggestions']?.toString();

    List<InpatientProcedureItem>? inpatientSchedules;
    if (notes['inpatient_schedules'] is List) {
      inpatientSchedules = (notes['inpatient_schedules'] as List).map((proc) {
        return InpatientProcedureItem(
          title: proc['title']?.toString() ?? 'Clinical Procedure',
          timing: proc['timing']?.toString() ?? '08:00 AM',
          instructions: proc['instructions']?.toString() ?? '',
          category: proc['category']?.toString() ?? 'Nursing Care',
        );
      }).toList();
    }

    // Parse allergies
    List<String>? allergiesList;
    if (json['allergies'] is List) {
      allergiesList = (json['allergies'] as List).map((e) => e.toString()).toList();
    }

    // Parse emergency contact
    Map<String, dynamic>? emergencyContactMap;
    if (json['emergency_contact'] is Map) {
      emergencyContactMap = Map<String, dynamic>.from(json['emergency_contact']);
    }

    return AppointmentItem(
      id: json['appointment_id']?.toString() ?? '',
      appointmentNo: notes['appointment_no']?.toString() ?? 'APT-${json['appointment_id']?.toString().substring(0, 4) ?? '101'}',
      patientName: json['patient_name']?.toString() ?? 'Patient',
      age: age,
      gender: (json['patient_sex']?.toString().toLowerCase() == 'female') ? 'Female' : 'Male',
      timing: timing,
      paymentStatus: notes['payment_status']?.toString() ?? (notes['is_paid'] == true ? 'Paid Online (₹500)' : 'Payment Pending'),
      isPaid: notes['is_paid'] == true || notes['is_paid'] == null,
      mode: mode,
      patientHistory: patientHistory,
      heightCm: heightCm,
      weightKg: weightKg,
      familyHistory: familyHistory,
      diagnosis: diagnosis,
      medicines: medicines,
      isAdmitted: isAdmitted,
      roomNo: roomNo,
      dietarySuggestions: dietarySuggestions,
      inpatientSchedules: inpatientSchedules,
      isCompleted: isCompleted,
      status: json['status']?.toString() ?? (isCompleted ? 'completed' : 'confirmed'),
      patientId: json['patient_id']?.toString(),
      medicalRecordNumber: json['medical_record_number']?.toString(),
      bloodGroup: json['blood_group']?.toString(),
      patientPhone: json['patient_phone']?.toString(),
      doctorName: json['doctor_name']?.toString(),
      clinicalData: clinicalData.isNotEmpty ? Map<String, dynamic>.from(clinicalData) : null,
      allergies: allergiesList,
      emergencyContact: emergencyContactMap,
    );
  }

  // ==========================================================
  // CREATE APPOINTMENT (POST /api/appointments)
  // ==========================================================
  static Future<Map<String, dynamic>> createAppointment({
    required String patientId,
    required String doctorUserId,
    String? facilityId,
    String appointmentType = 'clinic',
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String status = 'confirmed',
    String? reason,
    Map<String, dynamic>? notes,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/appointments');
      final headers = await _headers();
      final bodyMap = <String, dynamic>{
        'patient_id': patientId,
        'provider_user_id': doctorUserId,
        if (facilityId != null && facilityId.isNotEmpty) 'facility_id': facilityId,
        'appointment_type': appointmentType,
        if (scheduledStart != null) 'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        if (scheduledEnd != null) 'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        'status': status,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        if (notes != null) 'notes': notes,
      };

      final response = await http.post(uri, headers: headers, body: jsonEncode(bodyMap));
      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'statusCode': response.statusCode,
          'data': data['data'],
          'message': data['message'] ?? 'Appointment created successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to create appointment (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.createAppointment error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // UPDATE APPOINTMENT (PATCH /api/appointments/{id})
  // ==========================================================
  static Future<Map<String, dynamic>> updateAppointment({
    required String appointmentId,
    String? status,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    String? reason,
    Map<String, dynamic>? notes,
    List<Map<String, dynamic>>? prescriptions,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/appointments/$appointmentId');
      final headers = await _headers();
      final bodyMap = <String, dynamic>{
        if (status != null) 'status': status,
        if (scheduledStart != null) 'scheduled_start': scheduledStart.toUtc().toIso8601String(),
        if (scheduledEnd != null) 'scheduled_end': scheduledEnd.toUtc().toIso8601String(),
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
        if (prescriptions != null) 'prescriptions': prescriptions,
      };

      final response = await http.patch(uri, headers: headers, body: jsonEncode(bodyMap));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'statusCode': 200,
          'data': data['data'],
          'message': data['message'] ?? 'Appointment updated successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to update appointment (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.updateAppointment error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // INVENTORY / PHARMACY
  // ==========================================================
  static Future<List<PharmacyItem>> getInventory({String? facilityId, String? category}) async {
    try {
      final queryParams = <String, String>{};
      if (facilityId != null && facilityId.isNotEmpty) queryParams['facility_id'] = facilityId;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;

      final uri = Uri.parse('$baseUrl/inventory').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final list = data['data'] as List;
          return list.map<PharmacyItem>((json) => _mapPharmacyItem(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getInventory error: $e');
    }
    return [];
  }

  static PharmacyItem _mapPharmacyItem(Map<String, dynamic> json) {
    final metadata = json['metadata'] is Map ? json['metadata'] as Map : {};
    final qty = num.tryParse(json['quantity']?.toString() ?? '0')?.toInt() ?? 0;
    final minThreshold = num.tryParse(json['reorder_level']?.toString() ?? '20')?.toInt() ?? 20;
    final price = num.tryParse(metadata['price_per_unit']?.toString() ?? '45')?.toDouble() ?? 45.0;

    return PharmacyItem(
      id: json['inventory_id']?.toString() ?? '',
      name: json['item_name']?.toString() ?? 'Medicine',
      composition: json['item_code']?.toString() ?? 'Standard Composition',
      category: json['category']?.toString() ?? 'General',
      form: json['unit']?.toString() ?? 'Tablets',
      stockQuantity: qty,
      minThreshold: minThreshold,
      location: metadata['shelf']?.toString() ?? json['facility_name']?.toString() ?? 'Main Dispensary',
      pricePerUnit: price,
      manufacturer: 'Ashwini Healthcare Formulations',
      expiryDate: json['expiry_date']?.toString().split('T')[0] ?? '2027-12-31',
    );
  }

  // ==========================================================
  // MACHINES / EQUIPMENT
  // ==========================================================
  static Future<List<EquipmentInfo>> getMachines({String? facilityId, String? status}) async {
    try {
      final queryParams = <String, String>{};
      if (facilityId != null && facilityId.isNotEmpty) queryParams['facility_id'] = facilityId;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/machines').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          final list = data['data'] as List;
          return list.map<EquipmentInfo>((json) => _mapEquipmentInfo(json)).toList();
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getMachines error: $e');
    }
    return [];
  }

  static EquipmentInfo _mapEquipmentInfo(Map<String, dynamic> json) {
    final telemetry = json['telemetry'] is Map ? json['telemetry'] as Map : {};
    final statusRaw = json['status']?.toString().toLowerCase();

    String status = 'Operational';
    if (statusRaw == 'in_use') status = 'In Use';
    if (statusRaw == 'maintenance') status = 'Under Maintenance';
    if (statusRaw == 'retired') status = 'Standby';

    return EquipmentInfo(
      id: json['machine_record_id']?.toString() ?? '',
      name: json['machine_type']?.toString() ?? 'Medical Machine',
      model: telemetry['model']?.toString() ?? 'Pro Series 2026',
      category: telemetry['department']?.toString() ?? 'Critical Care',
      status: status,
      serialNumber: json['serial_number']?.toString() ?? 'SN-UNKNOWN',
      lastMaintenance: json['last_service_at']?.toString().split('T')[0] ?? 'Recently Certified',
    );
  }

  // ==========================================================
  // PATIENTS
  // ==========================================================
  static Future<List<Map<String, dynamic>>> getPatients({String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;

      final uri = Uri.parse('$baseUrl/patients').replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getPatients error: $e');
    }
    return [];
  }

  static Future<Map<String, dynamic>> createPatient({
    required String fullName,
    required String phone,
    String? dateOfBirth,
    String? sexAtBirth,
    String? bloodGroup,
    String? medicalRecordNumber,
    List<String>? allergies,
    Map<String, dynamic>? emergencyContact,
    Map<String, dynamic>? profileData,
    String? initialDoctorUserId,
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/staff/patients');
      final headers = await _headers();
      final body = jsonEncode({
        'full_name': fullName,
        'phone': phone,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (sexAtBirth != null) 'sex_at_birth': sexAtBirth,
        if (bloodGroup != null) 'blood_group': bloodGroup,
        if (medicalRecordNumber != null) 'medical_record_number': medicalRecordNumber,
        if (allergies != null) 'allergies': allergies,
        if (emergencyContact != null) 'emergency_contact': emergencyContact,
        if (profileData != null) 'profile_data': profileData,
        if (initialDoctorUserId != null) 'doctor_user_id': initialDoctorUserId,
        if (reason != null) 'reason': reason,
      });

      final response = await http.post(uri, headers: headers, body: body);
      final json = jsonDecode(response.body);

      return {
        'success': response.statusCode == 201,
        'statusCode': response.statusCode,
        'data': json['data'],
        'error': json['error'] ?? json['message'],
      };
    } catch (e) {
      debugPrint('ApiClient.createPatient error: $e');
      return {'success': false, 'statusCode': 500, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deletePatient(String patientId) async {
    try {
      final uri = Uri.parse('$baseUrl/staff/patients/$patientId');
      final headers = await _headers();
      final response = await http.delete(uri, headers: headers);
      final json = jsonDecode(response.body);

      return {
        'success': response.statusCode == 200,
        'statusCode': response.statusCode,
        'data': json['data'],
        'error': json['error'] ?? json['message'],
      };
    } catch (e) {
      debugPrint('ApiClient.deletePatient error: $e');
      return {'success': false, 'statusCode': 500, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>?> getPatientById(String patientId) async {
    try {
      final uri = Uri.parse('$baseUrl/patients/$patientId');
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is Map) {
          return Map<String, dynamic>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getPatientById error: $e');
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getPatientRecords(String patientId) async {
    try {
      final uri = Uri.parse('$baseUrl/patients/$patientId/records');
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getPatientRecords error: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getPatientPrescriptions(String patientId) async {
    try {
      final uri = Uri.parse('$baseUrl/patients/$patientId/prescriptions');
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getPatientPrescriptions error: $e');
    }
    return [];
  }

  // ==========================================================
  // ADMIN: DOCTORS
  // ==========================================================
  static Future<Map<String, dynamic>> createDoctor({
    required String fullName,
    required String phone,
    required String password,
    String? licenseNumber,
    List<String>? specialties,
    Map<String, dynamic>? availability,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/staff/doctors');
      final headers = await _headers();
      final body = jsonEncode({
        'full_name': fullName,
        'phone': phone,
        'password': password,
        if (licenseNumber != null && licenseNumber.isNotEmpty) 'license_number': licenseNumber,
        if (specialties != null && specialties.isNotEmpty) 'specialties': specialties,
        if (availability != null && availability.isNotEmpty) 'availability': availability,
      });

      final response = await http.post(uri, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return {
          'success': true,
          'statusCode': 201,
          'data': data['data'],
          'message': data['message'] ?? 'Doctor created successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to create doctor (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.createDoctor error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // GET DOCTORS (DATABASE REFLECTION)
  // ==========================================================
  static Future<List<Map<String, dynamic>>> getDoctors() async {
    try {
      final uri = Uri.parse('$baseUrl/staff/doctors');
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getDoctors error: $e');
    }
    return [];
  }

  // ==========================================================
  // UPDATE DOCTOR
  // ==========================================================
  static Future<Map<String, dynamic>> updateDoctor({
    required String userId,
    String? fullName,
    String? licenseNumber,
    List<String>? specialties,
    Map<String, dynamic>? availability,
    bool? isActive,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/staff/doctors/$userId');
      final headers = await _headers();
      final body = jsonEncode({
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
        if (licenseNumber != null) 'license_number': licenseNumber,
        if (specialties != null) 'specialties': specialties,
        if (availability != null) 'availability': availability,
        if (isActive != null) 'is_active': isActive,
      });

      final response = await http.put(uri, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'statusCode': 200,
          'data': data['data'],
          'message': data['message'] ?? 'Doctor profile updated successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to update doctor (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.updateDoctor error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // DELETE DOCTOR
  // ==========================================================
  static Future<Map<String, dynamic>> deleteDoctor(String userId) async {
    try {
      final uri = Uri.parse('$baseUrl/staff/doctors/$userId');
      final headers = await _headers();
      final response = await http.delete(uri, headers: headers);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'statusCode': 200,
          'data': data['data'],
          'message': data['message'] ?? 'Doctor removed successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to delete doctor (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.deleteDoctor error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // ASSIGN PATIENT TO DOCTOR (ADMIN ONLY)
  // ==========================================================
  static Future<Map<String, dynamic>> assignPatientDoctor({
    required String patientId,
    required String doctorUserId,
    String? reason,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/staff/assign-patient');
      final headers = await _headers();
      final body = jsonEncode({
        'patient_id': patientId,
        'doctor_user_id': doctorUserId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      });

      final response = await http.post(uri, headers: headers, body: body);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'statusCode': 200,
          'data': data['data'],
          'message': data['message'] ?? 'Patient assigned to doctor successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to assign patient (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.assignPatientDoctor error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // DELETE APPOINTMENT / CONSULTATION (ADMIN ONLY)
  // ==========================================================
  static Future<Map<String, dynamic>> deleteAppointment(String appointmentId) async {
    try {
      final uri = Uri.parse('$baseUrl/appointments/$appointmentId');
      final headers = await _headers();

      final response = await http.delete(uri, headers: headers);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'statusCode': 200,
          'data': data['data'],
          'message': data['message'] ?? 'Consultation deleted from database successfully.',
        };
      } else {
        return {
          'success': false,
          'statusCode': response.statusCode,
          'error': data['error'] ?? 'Failed to delete consultation (${response.statusCode})',
        };
      }
    } catch (e) {
      debugPrint('ApiClient.deleteAppointment error: $e');
      return {
        'success': false,
        'statusCode': 500,
        'error': 'Network or client error: $e',
      };
    }
  }

  // ==========================================================
  // FACILITIES (GET /api/facilities)
  // ==========================================================
  static Future<List<Map<String, dynamic>>> getFacilities() async {
    try {
      final uri = Uri.parse('$baseUrl/facilities');
      final headers = await _headers();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.getFacilities error: $e');
    }
    return [];
  }
}

