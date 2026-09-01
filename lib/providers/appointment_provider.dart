import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/health_profile.dart';

class AppointmentProvider with ChangeNotifier {
  static const String _storageKey = 'patient_appointments_v1';

  List<Appointment> _appointments = [];
  bool _isLoading = false;
  bool _isInitialized = false;

  /// Comparator that sorts appointments with the latest calendar date & booking at the top
  static int _sortAppointments(Appointment a, Appointment b) {
    // 1. Primary: Sort by scheduled appointment calendar date & time descending (latest date at top, oldest at bottom)
    final dateCompare = b.scheduledDateTime.compareTo(a.scheduledDateTime);
    if (dateCompare != 0) return dateCompare;
    // 2. Secondary fallback: Sort by bookedAt timestamp descending (most recently booked first)
    return b.bookedAt.compareTo(a.bookedAt);
  }

  /// Returns appointments sorted with the most recently booked/scheduled first
  List<Appointment> get appointments {
    final list = List<Appointment>.from(_appointments);
    list.sort(_sortAppointments);
    return List.unmodifiable(list);
  }

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  AppointmentProvider() {
    loadAppointments();
  }

  /// Load appointments from local persistence
  Future<void> loadAppointments() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonListString = prefs.getString(_storageKey);
      if (jsonListString != null && jsonListString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonListString);
        _appointments = decoded.map((item) => Appointment.fromJson(item)).toList();
        _appointments.sort(_sortAppointments);
      }
    } catch (e) {
      _appointments = [];
    }

    _isInitialized = true;
    _isLoading = false;
    notifyListeners();
  }

  /// Clear all stored appointments data completely from disk and memory
  Future<void> clearAllAppointments() async {
    _appointments.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {}
    notifyListeners();
  }

  /// Delete a single appointment
  Future<void> deleteAppointment(String appointmentId) async {
    _appointments.removeWhere((a) => a.id == appointmentId);
    await _persist();
    notifyListeners();
  }

  /// Save appointments list to local storage
  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_appointments.map((a) => a.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (_) {}
  }

  /// Book a new appointment with the selected Doctor, Date, and Time slot
  Future<Appointment> bookAppointment({
    required Doctor doctor,
    required HealthProfile patient,
    required String appointmentDate,
    required String timeSlot,
    String reason = 'General Consultation',
  }) async {
    _isLoading = true;
    notifyListeners();

    // Calculate queue token number for that doctor & date
    final sameDoctorDayCount = _appointments.where((a) =>
        a.doctorId == doctor.id &&
        a.appointmentDate == appointmentDate &&
        a.status == 'Confirmed').length;

    final tokenNumber = 'Token #${(sameDoctorDayCount + 1).toString().padLeft(2, '0')}';
    final randomId = 'APT-${(10000 + Random().nextInt(90000))}';

    final newAppointment = Appointment(
      id: randomId,
      tokenNumber: tokenNumber,
      doctorId: doctor.id,
      doctorName: doctor.name,
      doctorSpecialty: doctor.specialty,
      hospitalName: doctor.hospital,
      patientName: patient.name,
      patientPhone: patient.phoneNumber,
      appointmentDate: appointmentDate,
      timeSlot: timeSlot,
      reason: reason.isEmpty ? 'General Consultation' : reason,
      consultationFee: doctor.consultationFee,
      status: 'Confirmed',
      bookedAt: DateTime.now(),
    );

    // Insert at top and persist
    _appointments.insert(0, newAppointment);
    _appointments.sort(_sortAppointments);
    await _persist();

    _isLoading = false;
    notifyListeners();

    return newAppointment;
  }

  /// Cancel an appointment
  Future<void> cancelAppointment(String appointmentId) async {
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index != -1) {
      final old = _appointments[index];
      _appointments[index] = Appointment(
        id: old.id,
        tokenNumber: old.tokenNumber,
        doctorId: old.doctorId,
        doctorName: old.doctorName,
        doctorSpecialty: old.doctorSpecialty,
        hospitalName: old.hospitalName,
        patientName: old.patientName,
        patientPhone: old.patientPhone,
        appointmentDate: old.appointmentDate,
        timeSlot: old.timeSlot,
        reason: old.reason,
        consultationFee: old.consultationFee,
        status: 'Cancelled',
        bookedAt: old.bookedAt,
      );
      await _persist();
      notifyListeners();
    }
  }
}
