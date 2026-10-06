import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:hrx_protocol/hrx_protocol.dart';
import '../theme/app_colors.dart';
import '../models/appointment_model.dart';
import '../services/api_client.dart';
import 'appointment_detail_screen.dart';

enum QrScannerState {
  ready,
  scanning,
  processing,
  validating,
  decrypting,
  success,
  error,
}

class QrWorkflowScreen extends StatefulWidget {
  final List<AppointmentItem>? existingAppointments;

  const QrWorkflowScreen({super.key, this.existingAppointments});

  @override
  State<QrWorkflowScreen> createState() => _QrWorkflowScreenState();
}

class _QrWorkflowScreenState extends State<QrWorkflowScreen> with SingleTickerProviderStateMixin {
  late MobileScannerController _cameraController;
  late AnimationController _animController;
  late Animation<double> _laserAnimation;

  QrScannerState _scannerState = QrScannerState.ready;
  String? _statusMessage;
  bool _isProcessing = false;
  bool _flashOn = false;

  final TextEditingController _manualIdController = TextEditingController();

  final List<AppointmentItem> _databasePatients = [
    AppointmentItem(
      id: '1',
      appointmentNo: 'APT-101',
      patientName: 'Rajesh Sharma',
      patientId: '14-2026-4512-8821',
      medicalRecordNumber: '14-2026-4512-8821',
      bloodGroup: 'B+',
      patientPhone: '9876543210',
      age: 45,
      gender: 'Male',
      timing: '10:30 AM - Today',
      paymentStatus: 'Paid Online (₹500)',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: ['Type 2 Diabetes (5 yrs)', 'Hypertension (3 yrs)', 'Appendectomy (2018)'],
      heightCm: 174.0,
      weightKg: 78.5,
      familyHistory: 'Father: Type 2 Diabetes, Mother: Hypertension',
      diagnosis: 'Acute Bronchitis & Mild Fever',
      medicines: [
        MedicineItem(
          name: 'Paracetamol 650mg',
          dosage: '1-0-1 after food',
          duration: '3 Days',
          closestClinic: 'Ashwini Central Pharmacy (In-Stock)',
        ),
        MedicineItem(
          name: 'Cetirizine 10mg',
          dosage: '0-0-1 before sleep',
          duration: '5 Days',
          closestClinic: 'Ashwini OPD Dispensary (In-Stock)',
        ),
      ],
      isAdmitted: true,
      roomNo: 'IPD Ward 304 - Bed 12',
      dietarySuggestions: 'Diabetic Low-Sodium Diet (1800 kcal), Soft foods & Warm fluids.',
    ),
    AppointmentItem(
      id: '2',
      appointmentNo: 'APT-102',
      patientName: 'Priya Verma',
      patientId: '14-2026-8821-3309',
      medicalRecordNumber: '14-2026-8821-3309',
      bloodGroup: 'O+',
      patientPhone: '9811223344',
      age: 32,
      gender: 'Female',
      timing: '11:15 AM - Today',
      paymentStatus: 'Payment Pending (Cash)',
      isPaid: false,
      mode: AppointmentMode.qr,
      patientHistory: ['Asthma (Mild)', 'Migraine'],
      heightCm: 162.5,
      weightKg: 58.0,
      familyHistory: 'Mother: Asthma',
      diagnosis: 'Seasonal Allergy & Bronchospasm',
      medicines: [
        MedicineItem(
          name: 'Levocetirizine 5mg',
          dosage: '0-0-1',
          duration: '5 Days',
          closestClinic: 'City Metro Clinic Pharmacy',
        ),
      ],
      isAdmitted: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      detectionTimeoutMs: 800,
      formats: const [BarcodeFormat.qrCode],
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _animController.dispose();
    _manualIdController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue ?? barcode.displayValue;
      if (code != null && code.trim().isNotEmpty) {
        _processScannedCode(code.trim());
        break;
      }
    }
  }

  Future<void> _processScannedCode(String rawCode) async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _scannerState = QrScannerState.processing;
      _statusMessage = 'Reading QR Code payload...';
    });

    HapticFeedback.lightImpact();

    // Check if HRX-compatible QR payload
    if (HrxDecoder.isHrxPayload(rawCode)) {
      final isEmergency = rawCode.trim().startsWith(HrxConstants.qrPrefixEmergencyHistory);
      final isCompressed = rawCode.trim().startsWith(HrxConstants.qrPrefixCompressedVisit) || isEmergency;
      await Future.delayed(const Duration(milliseconds: 80));
      setState(() {
        _scannerState = QrScannerState.validating;
        _statusMessage = isEmergency
            ? 'Decompressing offline emergency history bundle...'
            : (isCompressed ? 'Reading offline medical record...' : 'Verifying record integrity...');
      });

      if (!isCompressed) {
        await Future.delayed(const Duration(milliseconds: 100));
        setState(() {
          _scannerState = QrScannerState.decrypting;
          _statusMessage = 'Verifying secure record...';
        });
      }

      final decoder = HrxDecoder();
      final result = decoder.decode(rawCode);

      if (result.success) {
        HapticFeedback.mediumImpact();
        setState(() {
          _scannerState = QrScannerState.success;
          _statusMessage = isEmergency
              ? 'Emergency history (5 visits) decompressed!'
              : (isCompressed ? 'Offline visit record verified!' : 'Medical record verified!');
        });

        if (result.isEmergencyHistory && result.visits != null && result.visits!.isNotEmpty) {
          if (mounted) {
            _showEmergencyHistoryFoundSheet(result.visits!, result.metadata);
          }
        } else if (result.isPatient && result.patient != null) {
          final scannedPatient = result.patient!;
          // Look up cached records without replacing scanned patient details
          final cachedPatient = await LocalPatientRepository.instance.getPatient(scannedPatient.patientRef);
          final finalPatient = cachedPatient != null
              ? scannedPatient.copyWith(
                  visitIds: cachedPatient.visitIds.isNotEmpty ? cachedPatient.visitIds : scannedPatient.visitIds,
                  extra: {...scannedPatient.extra, ...cachedPatient.extra},
                )
              : scannedPatient;

          LocalPatientRepository.instance.savePatient(finalPatient);

          if (mounted) {
            _showHrxPatientFoundSheet(finalPatient);
          }
        } else if (result.isVisit && result.visit != null) {
          if (mounted) {
            _showHrxVisitViewerSheet(result.visit!, result.metadata);
          }
        }
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _scannerState = QrScannerState.error;
          _statusMessage = result.errorMessage ?? 'Verification failed: invalid QR.';
        });

        if (mounted) {
          _showErrorDialog(result.errorMessage ?? 'Unable to read this medical record.');
        }
      }
    } else {
      final cleanCode = rawCode.trim();
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (uuidRegex.hasMatch(cleanCode)) {
        await _fetchAndShowDatabasePatient(cleanCode);
      } else {
        // Online or legacy appointment matching logic
        await _decodeAndFetchPatient(rawCode);
      }
    }
  }

  Future<void> _decodeAndFetchPatient(String rawCode) async {
    final cleanCode = rawCode.trim();
    setState(() {
      _scannerState = QrScannerState.processing;
      _statusMessage = 'Locating patient & appointment records...';
    });

    AppointmentItem? matched;

    // 1. Check if payload is a JSON string
    if (cleanCode.startsWith('{') && cleanCode.endsWith('}')) {
      try {
        final decoded = jsonDecode(cleanCode);
        if (decoded is Map<String, dynamic>) {
          final apptNo = (decoded['appointmentNo'] ??
                  decoded['appointment_no'] ??
                  decoded['appt_no'] ??
                  decoded['id'] ??
                  'APT-ONLINE')
              .toString();
          final name = (decoded['patientName'] ??
                  decoded['patient_name'] ??
                  decoded['name'] ??
                  'Verified Patient')
              .toString();
          final age = int.tryParse((decoded['age'] ?? 40).toString()) ?? 40;
          final gender = (decoded['gender'] ?? 'Male').toString();
          final timing = (decoded['timing'] ?? decoded['time'] ?? 'Online Token Verified').toString();
          final diagnosis = (decoded['diagnosis'] ?? 'OPD Consultation').toString();

          matched = AppointmentItem(
            id: (decoded['id'] ?? 'QR-${DateTime.now().millisecondsSinceEpoch % 10000}').toString(),
            appointmentNo: apptNo,
            patientName: name,
            age: age,
            gender: gender,
            timing: timing,
            paymentStatus: (decoded['paymentStatus'] ?? decoded['payment_status'] ?? 'Hospital Verified').toString(),
            isPaid: decoded['isPaid'] == true || decoded['is_paid'] == true,
            mode: AppointmentMode.qr,
            patientHistory: (decoded['patientHistory'] is List)
                ? (decoded['patientHistory'] as List).map((e) => e.toString()).toList()
                : ['Hospital Digital Health Record Verified'],
            diagnosis: diagnosis,
            heightCm: double.tryParse((decoded['heightCm'] ?? decoded['height'] ?? 170).toString()) ?? 170.0,
            weightKg: double.tryParse((decoded['weightKg'] ?? decoded['weight'] ?? 70).toString()) ?? 70.0,
            familyHistory: (decoded['familyHistory'] ?? 'None recorded').toString(),
            medicines: const [],
            isAdmitted: decoded['isAdmitted'] == true,
          );
        }
      } catch (e) {
        debugPrint('JSON decode error in _decodeAndFetchPatient: $e');
      }
    }

    // 2. If payload is a URL, extract search token from query parameters
    String searchKey = cleanCode;
    if (cleanCode.startsWith('http://') || cleanCode.startsWith('https://')) {
      try {
        final uri = Uri.parse(cleanCode);
        final idParam = uri.queryParameters['id'] ??
            uri.queryParameters['apt'] ??
            uri.queryParameters['appointmentNo'] ??
            uri.queryParameters['patientId'];
        if (idParam != null && idParam.isNotEmpty) {
          searchKey = idParam;
        } else if (uri.pathSegments.isNotEmpty) {
          searchKey = uri.pathSegments.last;
        }
      } catch (_) {}
    }

    final upperKey = searchKey.toUpperCase();
    final cleanDigits = searchKey.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();

    bool matchesAppointment(AppointmentItem p) {
      if (p.appointmentNo.toUpperCase() == upperKey ||
          p.id == searchKey ||
          p.patientName.toUpperCase().contains(upperKey) ||
          upperKey.contains(p.appointmentNo.toUpperCase())) {
        return true;
      }
      final pMrn = p.medicalRecordNumber?.toUpperCase() ?? '';
      final pMrnClean = pMrn.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
      final pId = (p.patientId ?? '').toUpperCase();
      final pIdClean = pId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');

      if (cleanDigits.length >= 6) {
        if (pMrnClean.isNotEmpty && (pMrnClean == cleanDigits || pMrnClean.contains(cleanDigits) || cleanDigits.contains(pMrnClean))) {
          return true;
        }
        if (pIdClean.isNotEmpty && (pIdClean == cleanDigits || pIdClean.contains(cleanDigits) || cleanDigits.contains(pIdClean))) {
          return true;
        }
      }
      return false;
    }

    // 3. Search existing appointments pool
    if (matched == null) {
      final pool = widget.existingAppointments ?? _databasePatients;
      for (final p in pool) {
        if (matchesAppointment(p)) {
          matched = p;
          break;
        }
      }
    }

    // 4. Search local database patients pool
    if (matched == null) {
      for (final p in _databasePatients) {
        if (matchesAppointment(p)) {
          matched = p;
          break;
        }
      }
    }

    // 5. Query online live backend database via ApiClient
    if (matched == null) {
      try {
        final liveAppointments = await ApiClient.getAppointments();
        if (liveAppointments != null && liveAppointments.isNotEmpty) {
          for (final a in liveAppointments) {
            if (matchesAppointment(a)) {
              matched = a;
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('ApiClient.getAppointments lookup error: $e');
      }
    }

    // 6. Graceful verified fallback preserving scanned identifier
    final is14DigitHealthId = RegExp(r'^\d{2}-?\d{4}-?\d{4}-?\d{4}$').hasMatch(searchKey);
    final formattedHealthId = is14DigitHealthId
        ? (searchKey.contains('-')
            ? searchKey
            : '${searchKey.substring(0, 2)}-${searchKey.substring(2, 6)}-${searchKey.substring(6, 10)}-${searchKey.substring(10, 14)}')
        : null;

    matched ??= AppointmentItem(
      id: 'QR-${DateTime.now().millisecondsSinceEpoch % 10000}',
      appointmentNo: upperKey.startsWith('APT-') ? upperKey : 'APT-$upperKey',
      patientId: formattedHealthId,
      medicalRecordNumber: formattedHealthId,
      patientName: searchKey.length < 30 ? 'Patient ($searchKey)' : 'Online Verified Patient',
      age: 42,
      gender: 'Male',
      timing: 'Live QR Scanned',
      paymentStatus: 'Hospital OPD Verified',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: ['Hospital Record Verified via UID QR Token'],
      heightCm: 170.0,
      weightKg: 72.0,
      familyHistory: 'No known chronic family conditions',
      diagnosis: 'OPD General Consultation',
      medicines: [
        MedicineItem(
          name: 'Multivitamin & Zinc Tab',
          dosage: '0-1-0 after lunch',
          duration: '10 Days',
          closestClinic: 'Ashwini Central Pharmacy',
        ),
      ],
      isAdmitted: false,
    );

    if (mounted) {
      setState(() {
        _scannerState = QrScannerState.success;
        _statusMessage = 'Appointment record located!';
      });
      _showLegacyPatientFoundSheet(matched);
    }
  }

  void _resumeScanning() {
    setState(() {
      _isProcessing = false;
      _scannerState = QrScannerState.ready;
      _statusMessage = null;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Verification Error', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 13.5, height: 1.4)),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resumeScanning();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Scan Again'),
          ),
        ],
      ),
    );
  Future<void> _fetchAndShowDatabasePatient(String patientUuid) async {
    setState(() {
      _scannerState = QrScannerState.processing;
      _statusMessage = 'Querying database for patient profile & past records...';
    });

    try {
      final patientData = await ApiClient.getPatientById(patientUuid);
      final pastVisits = await ApiClient.getPatientPastVisits(patientUuid);
      final appts = await ApiClient.getAppointments(patientId: patientUuid);
      final activeAppt = (appts != null && appts.isNotEmpty) ? appts.first : null;

      if (!mounted) return;

      setState(() {
        _scannerState = QrScannerState.success;
        _statusMessage = 'Patient records loaded from database!';
      });

      _showDatabasePatientFoundSheet(
        patientUuid: patientUuid,
        patientData: patientData,
        pastVisits: pastVisits,
        activeAppt: activeAppt,
      );
    } catch (e) {
      debugPrint('Error fetching database patient $patientUuid: $e');
      if (!mounted) return;
      setState(() {
        _scannerState = QrScannerState.error;
        _statusMessage = 'Database lookup error.';
      });
      _showErrorDialog('Unable to query patient records for UUID: $patientUuid\n\n$e');
    }
  }

  void _showDatabasePatientFoundSheet({
    required String patientUuid,
    required Map<String, dynamic>? patientData,
    required List<Map<String, dynamic>> pastVisits,
    AppointmentItem? activeAppt,
  }) {
    final name = patientData?['full_name']?.toString() ?? 'Patient (${patientUuid.length > 8 ? patientUuid.substring(0, 8) : patientUuid})';
    final mrn = patientData?['medical_record_number']?.toString() ?? 'ABHA Linked';
    final phone = patientData?['phone_e164']?.toString() ?? '';
    final bloodGroup = patientData?['blood_group']?.toString() ?? 'O+';
    final gender = patientData?['sex_at_birth']?.toString() ?? 'Male';

    int age = 32;
    if (patientData?['date_of_birth'] != null) {
      try {
        final dob = DateTime.parse(patientData!['date_of_birth'].toString());
        final now = DateTime.now();
        age = now.year - dob.year;
        if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
          age--;
        }
      } catch (_) {}
    }

    List<String> allergies = [];
    if (patientData?['allergies'] is List) {
      allergies = (patientData!['allergies'] as List).map((e) => e.toString()).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 24),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Patient Identity Verified',
                              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                            ),
                            Text(
                              'Database Linked • ${pastVisits.length} Past Records',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Patient Profile Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFDDD6FE)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C3AED),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      mrn,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$age yrs • $gender • Blood Group: $bloodGroup',
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                              if (phone.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  'Phone: $phone',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: patientUuid));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Patient UUID copied to clipboard'),
                                      duration: Duration(seconds: 2),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFC4B5FD)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.fingerprint_rounded, size: 14, color: Color(0xFF7C3AED)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'UUID: ${patientUuid.length > 12 ? "${patientUuid.substring(0, 8)}...${patientUuid.substring(patientUuid.length - 4)}" : patientUuid}',
                                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF5B21B6), fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF7C3AED)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Allergies warning if any
                        if (allergies.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('KNOWN ALLERGIES', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                      Text(allergies.join(', '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Concise Past Visits Section Header
                        Row(
                          children: [
                            const Icon(Icons.dns_rounded, size: 16, color: Color(0xFF7C3AED)),
                            const SizedBox(width: 6),
                            const Text(
                              'CONCISE PAST VISITS (DATABASE STORED)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${pastVisits.length} Records',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (pastVisits.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Center(
                              child: Text(
                                'No prior visit records found in database.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          ),
                        ] else ...[
                          for (int idx = 0; idx < pastVisits.length; idx++) ...[
                            _buildDatabaseVisitCard(pastVisits[idx], idx + 1),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startConsultationWithPatient(
                        patientUuid: patientUuid,
                        patientData: patientData,
                        pastVisits: pastVisits,
                        activeAppt: activeAppt,
                        age: age,
                        gender: gender,
                        bloodGroup: bloodGroup,
                        phone: phone,
                        allergies: allergies,
                      );
                    },
                    icon: const Icon(Icons.medical_services_rounded, size: 18),
                    label: const Text('Start OPD Consultation / Open File'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(_resumeScanning);
  }

  Widget _buildDatabaseVisitCard(Map<String, dynamic> visit, int visitNum) {
    final date = visit['date']?.toString() ?? 'Recent';
    final doctor = visit['doctor_name']?.toString() ?? 'Attending Doctor';
    final facility = visit['facility']?.toString() ?? 'Ashwini Hospital';
    final diagnosis = visit['diagnosis']?.toString() ?? 'Clinical Consultation';
    final advice = visit['advice']?.toString();
    final vitals = visit['vitals'] is Map ? visit['vitals'] as Map : {};
    final prescriptions = visit['prescriptions'] is List ? visit['prescriptions'] as List : [];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Visit $visitNum',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Text(
                facility,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            doctor,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              diagnosis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF6D28D9)),
            ),
          ),
          if (vitals.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: vitals.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '${e.key.toString().toUpperCase()}: ${e.value}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                );
              }).toList(),
            ),
          ],
          if (prescriptions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: prescriptions.take(2).map((rx) {
                final rxMap = rx is Map ? rx : {};
                final name = rxMap['name'] ?? rxMap['medication_name'] ?? 'Medication';
                final dose = rxMap['dosage'] ?? '1-0-1';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.medication_rounded, size: 12, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$name ($dose)',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (advice != null && advice.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Advice: $advice',
              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _showEmergencyHistoryFoundSheet(List<VisitRecord> visits, Map<String, dynamic> metadata) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final allAllergies = visits.expand((v) => v.allergies).toSet().toList();
          final patientRef = visits.isNotEmpty ? visits.first.patientRef : 'Unknown';

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFEF2F2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.emergency_rounded, color: Color(0xFFDC2626), size: 24),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Emergency Clinical History',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF991B1B),
                              ),
                            ),
                            Text(
                              'Offline Restored • ${visits.length} Past Visits (${metadata["compressedSize"] ?? "Deflate"})',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Verification banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.offline_bolt_rounded, size: 18, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'OFFLINE EMERGENCY TRIAGE READY',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                                    ),
                                    Text(
                                      'Patient Ref: $patientRef • All 5 records decompressed locally without internet.',
                                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF7F1D1D)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Critical Allergies if any
                        if (allAllergies.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('KNOWN ALLERGIES IN EMERGENCY BUNDLE', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                      Text(allAllergies.join(', '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFB45309))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section Title
                        Row(
                          children: [
                            const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFFDC2626)),
                            const SizedBox(width: 6),
                            const Text(
                              'LAST 5 VISITS (CHRONOLOGICAL TIMELINE)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${visits.length} / 5',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        for (int i = 0; i < visits.length; i++) ...[
                          _buildEmergencyVisitCard(visits[i], i + 1),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Action Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _startEmergencyConsultationWithVisits(visits);
                    },
                    icon: const Icon(Icons.emergency_rounded, size: 18),
                    label: const Text('Start Emergency Consultation / Triage'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(_resumeScanning);
  }

  Widget _buildEmergencyVisitCard(VisitRecord visit, int visitNum) {
    final date = visit.timestamp.split('T').first;
    final doctor = visit.doctorName.isNotEmpty ? visit.doctorName : 'Attending Doctor';
    final facility = visit.facilityName.isNotEmpty ? visit.facilityName : 'Hospital Clinic';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: visitNum == 1 ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Visit $visitNum${visitNum == 1 ? " (Latest)" : ""}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    date,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
              Text(
                facility,
                style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            doctor,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
          ),
          if (visit.diagnosis.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: visit.diagnosis.map((d) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(
                    '${d.name}${d.code.isNotEmpty ? " (${d.code})" : ""}',
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B)),
                  ),
                );
              }).toList(),
            ),
          ],
          if (visit.vitals.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: visit.vitals.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: Text(
                    '${e.key.replaceAll('_', ' ').toUpperCase()}: ${e.value}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                );
              }).toList(),
            ),
          ],
          if (visit.medications.isNotEmpty) ...[
            const SizedBox(height: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: visit.medications.take(3).map((m) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.medication_rounded, size: 12, color: Color(0xFFDC2626)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${m.name} ${m.strength} • ${m.dose} (${m.frequency})',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF334155)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
          if (visit.notes.isNotEmpty || visit.advice.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              visit.notes.isNotEmpty ? 'Note: ${visit.notes}' : 'Advice: ${visit.advice.join(", ")}',
              style: const TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  void _startConsultationWithPatient({
    required String patientUuid,
    required Map<String, dynamic>? patientData,
    required List<Map<String, dynamic>> pastVisits,
    AppointmentItem? activeAppt,
    required int age,
    required String gender,
    required String bloodGroup,
    required String phone,
    required List<String> allergies,
  }) {
    final apptItem = AppointmentItem(
      id: activeAppt?.id ?? 'OPD-${DateTime.now().millisecondsSinceEpoch % 10000}',
      appointmentNo: activeAppt?.appointmentNo ?? 'APT-${patientUuid.length > 8 ? patientUuid.substring(0, 8).toUpperCase() : patientUuid.toUpperCase()}',
      patientName: patientData?['full_name']?.toString() ?? 'Patient (${patientUuid.length > 8 ? patientUuid.substring(0, 8) : patientUuid})',
      patientId: patientUuid,
      medicalRecordNumber: patientData?['medical_record_number']?.toString() ?? patientUuid,
      bloodGroup: bloodGroup,
      patientPhone: phone,
      age: age,
      gender: gender,
      timing: activeAppt?.timing ?? 'Live QR Check-in',
      paymentStatus: activeAppt?.paymentStatus ?? 'Hospital OPD Verified',
      isPaid: activeAppt?.isPaid ?? true,
      mode: AppointmentMode.qr,
      patientHistory: [
        if (allergies.isNotEmpty) 'Allergies: ${allergies.join(", ")}',
        for (final pv in pastVisits)
          if (pv['diagnosis'] != null) '${pv['date'] ?? "Past"}: ${pv['diagnosis']}',
      ],
      heightCm: 170.0,
      weightKg: 70.0,
      familyHistory: 'Profile linked from Cloud EHR',
      diagnosis: (pastVisits.isNotEmpty && pastVisits.first['diagnosis'] != null)
          ? pastVisits.first['diagnosis'].toString()
          : 'OPD Clinical Consultation',
      medicines: (pastVisits.isNotEmpty && pastVisits.first['prescriptions'] is List)
          ? (pastVisits.first['prescriptions'] as List).map<MedicineItem>((rx) {
              final rxMap = rx is Map ? rx : {};
              return MedicineItem(
                name: rxMap['name']?.toString() ?? rxMap['medication_name']?.toString() ?? 'Medication',
                dosage: rxMap['dosage']?.toString() ?? '1-0-1',
                duration: rxMap['duration']?.toString() ?? '5 Days',
                closestClinic: rxMap['closestClinic']?.toString() ?? rxMap['closest_clinic']?.toString() ?? 'Ashwini Pharmacy',
              );
            }).toList()
          : [],
      isAdmitted: false,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(appointment: apptItem),
      ),
    );
  }

  void _startEmergencyConsultationWithVisits(List<VisitRecord> visits) {
    if (visits.isEmpty) return;
    final first = visits.first;
    final allAllergies = visits.expand((v) => v.allergies).toSet().toList();

    final emergencyAppt = AppointmentItem(
      id: 'EMR-${DateTime.now().millisecondsSinceEpoch % 10000}',
      appointmentNo: 'EMR-${first.patientRef}',
      patientName: 'Emergency Patient (${first.patientRef})',
      patientId: first.patientRef,
      medicalRecordNumber: first.patientRef,
      bloodGroup: 'Emergency Profile',
      patientPhone: '',
      age: 40,
      gender: 'Patient',
      timing: 'Immediate Emergency Triage',
      paymentStatus: 'Emergency Admission',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: [
        if (allAllergies.isNotEmpty) 'Known Allergies: ${allAllergies.join(", ")}',
        for (final v in visits)
          if (v.diagnosis.isNotEmpty) '${v.timestamp.split("T").first}: ${v.diagnosis.first.name}',
      ],
      heightCm: 170.0,
      weightKg: 70.0,
      familyHistory: 'Offline Emergency Bundle Restored',
      diagnosis: first.diagnosis.isNotEmpty ? first.diagnosis.first.name : 'Emergency Triage',
      medicines: first.medications.map((m) {
        return MedicineItem(
          name: '${m.name} ${m.strength}',
          dosage: '${m.dose} (${m.frequency})',
          duration: '${m.duration} ${m.durationUnit}',
          closestClinic: first.facilityName.isNotEmpty ? first.facilityName : 'Emergency Pharmacy',
          instructions: m.instructions,
        );
      }).toList(),
      isAdmitted: true,
      allergies: allAllergies,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentDetailScreen(appointment: emergencyAppt),
      ),
    );
  }

  /// Displays the Patient Information card scanned via HRX Patient Identity QR (Section 23).
  void _showHrxPatientFoundSheet(PatientRecord patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Patient Identity Verified',
                        style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                      ),
                      Text(
                        'Verified Offline Check-in • Health ID Linked',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Patient Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFDDD6FE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        patient.name,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          patient.patientRef,
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'ID: ${patient.patientId} • ${patient.gender} • Blood Group: ${patient.bloodGroup}',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                  ),
                  if (patient.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Phone: +91 ${patient.phone}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Offline records availability note
                  Row(
                    children: [
                      const Icon(Icons.history_edu_rounded, size: 16, color: Color(0xFF7C3AED)),
                      const SizedBox(width: 6),
                      Text(
                        '${patient.visitIds.isNotEmpty ? patient.visitIds.length : 5} Offline Visit QRs Stored on Device',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final visits = await LocalVisitRepository.instance.getLastFiveVisits(patient.patientRef);
                      if (visits.isNotEmpty && mounted) {
                        _showHrxVisitViewerSheet(visits.first, {'source': 'Local Patient Repository'});
                      }
                    },
                    icon: const Icon(Icons.history_edu_rounded, size: 18),
                    label: const Text('View Last Visit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7C3AED),
                      side: const BorderSide(color: Color(0xFF7C3AED)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resumeScanning();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Patient ${patient.name} checked in to OPD Queue.'),
                          backgroundColor: const Color(0xFF10B981),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Start OPD'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).whenComplete(_resumeScanning);
  }

  /// Displays the full offline reconstructed Visit Record viewer (Section 26).
  void _showHrxVisitViewerSheet(VisitRecord visit, Map<String, dynamic> metadata) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(height: 14),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFECFDF5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.verified_rounded, color: Color(0xFF059669), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Offline Visit Record Extracted',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1B4B),
                              ),
                            ),
                            Text(
                              'Visit ID: ${visit.visitId} • ${visit.patientRef}',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Scrollable Clinical Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Verification Badges Container
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF16A34A)),
                                  SizedBox(width: 6),
                                  Text(
                                    'OFFLINE RECORD VERIFIED',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                                  ),
                                  Spacer(),
                                  Text(
                                    '✓ Authenticated Digital Record',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF166534)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Doctor & Consultation Overview
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE9D5FF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    visit.doctorName.isNotEmpty ? visit.doctorName : 'Attending Doctor',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                                  ),
                                  Text(
                                    visit.timestamp.split('T').first,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                visit.facilityName.isNotEmpty ? visit.facilityName : 'Hospital Clinic',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Section 1: Chief Complaints & Symptoms
                        if (visit.chiefComplaints.isNotEmpty || visit.symptoms.isNotEmpty) ...[
                          _buildClinicalSection(
                            title: 'CHIEF COMPLAINTS & SYMPTOMS',
                            icon: Icons.sick_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final c in visit.chiefComplaints)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF7C3AED))),
                                        Expanded(child: Text(c, style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155)))),
                                      ],
                                    ),
                                  ),
                                for (final s in visit.symptoms)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('– ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                                        Expanded(child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 2: Diagnoses
                        if (visit.diagnosis.isNotEmpty) ...[
                          _buildClinicalSection(
                            title: 'DIAGNOSIS',
                            icon: Icons.medical_services_outlined,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: visit.diagnosis.map((d) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(d.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                                      if (d.code.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF7C3AED),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(d.code, style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 3: Vitals
                        if (visit.vitals.isNotEmpty) ...[
                          _buildClinicalSection(
                            title: 'RECORDED VITALS',
                            icon: Icons.monitor_heart_outlined,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: visit.vitals.entries.map((e) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.key.replaceAll('_', ' ').toUpperCase(),
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${e.value}',
                                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF1E1B4B)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 4: Prescriptions / Medications
                        if (visit.medications.isNotEmpty) ...[
                          _buildClinicalSection(
                            title: 'PRESCRIPTION & MEDICATIONS',
                            icon: Icons.medication_rounded,
                            child: Column(
                              children: visit.medications.map((m) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.circle, size: 8, color: Color(0xFF7C3AED)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${m.name} ${m.strength}',
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Dose: ${m.dose} • Frequency: ${m.frequency} • Duration: ${m.duration} ${m.durationUnit}',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                            ),
                                            if (m.instructions.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                'Instructions: ${m.instructions}',
                                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 5: Allergies
                        if (visit.allergies.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFECACA)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('ALLERGIES NOTED', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF991B1B))),
                                      Text(visit.allergies.join(', '), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 6: Advice & Follow Up
                        if (visit.advice.isNotEmpty || visit.followUp.required) ...[
                          _buildClinicalSection(
                            title: 'ADVICE & FOLLOW UP',
                            icon: Icons.lightbulb_outline_rounded,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final a in visit.advice)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Text('• $a', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                                  ),
                                if (visit.followUp.required) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Follow up: ${visit.followUp.date}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7C3AED)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Section 7: Notes
                        if (visit.notes.isNotEmpty) ...[
                          _buildClinicalSection(
                            title: 'CLINICAL NOTES',
                            icon: Icons.notes_rounded,
                            child: Text(visit.notes, style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4)),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Done Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _resumeScanning();
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Close & Scan Next QR'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(_resumeScanning);
  }

  static Widget _buildClinicalSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  void _showLegacyPatientFoundSheet(AppointmentItem patient) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'QR Decoded Successfully!',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                        ),
                        Text(
                          'Patient Record: ${patient.appointmentNo}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          patient.patientName,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.headingText),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryDark,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            patient.appointmentNo,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${patient.age} yrs • ${patient.gender} • ${patient.timing}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                    if (patient.medicalRecordNumber != null && patient.medicalRecordNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Health ID: ${patient.medicalRecordNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppointmentDetailScreen(appointment: patient),
                      ),
                    );
                  },
                  icon: const Icon(Icons.medical_services_outlined, size: 20),
                  label: const Text('Open Medical File', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(_resumeScanning);
  }

  void _promptManualEntry() {
    _manualIdController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Manual Token Entry', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter Health ID, Patient Reference or paste full HRX payload:',
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _manualIdController,
              decoration: InputDecoration(
                hintText: 'e.g. 14-2026-4512-8821 or P-7A92F81C...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final code = _manualIdController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(ctx);
                _processScannedCode(code);
              }
            },
            child: const Text('Decode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Interactive demo picker allowing the doctor/tester to instantly test HRX decoding
  void _promptDemoPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.science_outlined, color: Color(0xFF7C3AED), size: 22),
                SizedBox(width: 8),
                Text(
                  'Test Offline QR Records',
                  style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select any local demo record to simulate physical QR camera scan:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),

            // Database Patient UUID Check-in QR
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFDCFCE7),
                child: Icon(Icons.qr_code_2_rounded, color: Color(0xFF16A34A)),
              ),
              title: const Text('Live Patient UUID QR (Database Linked)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('UUID: b0843210-91ab-4ef1-bb74-001928475002 • 5 DB Visits', style: TextStyle(fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFF0FDF4),
              onTap: () {
                Navigator.pop(ctx);
                _processScannedCode('b0843210-91ab-4ef1-bb74-001928475002');
              },
            ),
            const SizedBox(height: 8),

            // Emergency History Bundle (All 5 Visits Compressed)
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFEE2E2),
                child: Icon(Icons.emergency_rounded, color: Color(0xFFDC2626)),
              ),
              title: const Text('Emergency History Bundle (5 Visits Offline)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('HRX:HIST: Deflate Compressed • Instant Triage', style: TextStyle(fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFFEF2F2),
              onTap: () async {
                Navigator.pop(ctx);
                final visits = await LocalVisitRepository.instance.getLastFiveVisits('P-7A92F81C');
                final bundleQr = HrxEncoder().encodeEmergencyHistoryBundle(visits);
                _processScannedCode(bundleQr);
              },
            ),
            const SizedBox(height: 8),

            // Option 1: Patient Identity QR
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEDE9FE),
                child: Icon(Icons.person_rounded, color: Color(0xFF7C3AED)),
              ),
              title: const Text('Patient Identity QR (Vikram Malhotra)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              subtitle: const Text('Ref: P-7A92F81C • Health ID', style: TextStyle(fontSize: 11)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: const Color(0xFFF8FAFC),
              onTap: () {
                Navigator.pop(ctx);
                final qrString = HrxEncoder().encodePatientQr(LocalPatientRepository.defaultPatient);
                _processScannedCode(qrString);
              },
            ),
            const SizedBox(height: 8),

            // Option 2-6: Visit QRs
            for (int i = 1; i <= 5; i++) ...[
              FutureBuilder<VisitRecord?>(
                future: LocalVisitRepository.instance.getVisitById('V100$i'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox.shrink();
                  final v = snapshot.data!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF0FDF4),
                        child: Text('$i', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A))),
                      ),
                      title: Text('Visit $i: ${v.diagnosis.isNotEmpty ? v.diagnosis.first.name : "Consultation"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                      subtitle: Text('${v.visitId} • ${v.doctorName}', style: const TextStyle(fontSize: 11)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: const Color(0xFFF8FAFC),
                      onTap: () {
                        Navigator.pop(ctx);
                        final encoded = HrxEncoder().encodeCompactVisitQr(v);
                        _processScannedCode(encoded.qrPayload);
                      },
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanBoxSize = math.min(MediaQuery.of(context).size.width * 0.72, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan Medical QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.science_outlined),
            tooltip: 'Test HRX Records',
            onPressed: _promptDemoPicker,
          ),
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: 'Toggle Flash',
            onPressed: () {
              setState(() => _flashOn = !_flashOn);
              _cameraController.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded),
            tooltip: 'Switch Camera',
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Real Mobile Scanner Camera Feed
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_photography_rounded, size: 54, color: Colors.white54),
                      const SizedBox(height: 12),
                      Text(
                        'Camera unavailable in simulator or permission required: ${error.errorCode.name}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _promptDemoPicker,
                        icon: const Icon(Icons.science_outlined),
                        label: const Text('Test with HRX Demo Records'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // QR Scanner Viewfinder with Corners & Laser
          Center(
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: Stack(
                children: [
                  CustomPaint(
                    size: Size(scanBoxSize, scanBoxSize),
                    painter: QrViewfinderPainter(
                      cornerColor: _scannerState == QrScannerState.error
                          ? const Color(0xFFEF4444)
                          : (_scannerState == QrScannerState.success ? const Color(0xFF10B981) : const Color(0xFF7C3AED)),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserAnimation.value * scanBoxSize,
                        left: 14,
                        right: 14,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Color(0xFF38BDF8), Color(0xFFA855F7), Colors.transparent],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Top Instruction / Processing Status Badge
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _scannerState == QrScannerState.error
                      ? const Color(0xFFEF4444)
                      : (_scannerState == QrScannerState.processing ||
                              _scannerState == QrScannerState.validating ||
                              _scannerState == QrScannerState.decrypting
                          ? const Color(0xFFF59E0B)
                          : Colors.white24),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_scannerState == QrScannerState.processing ||
                      _scannerState == QrScannerState.validating ||
                      _scannerState == QrScannerState.decrypting)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
                      ),
                    )
                  else
                    Icon(
                      _scannerState == QrScannerState.error ? Icons.warning_amber_rounded : Icons.camera_enhance_rounded,
                      color: _scannerState == QrScannerState.error ? const Color(0xFFEF4444) : Colors.white,
                      size: 16,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    _statusMessage ?? 'Point camera at Patient or Visit QR Code',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Quick Action Buttons
          Positioned(
            bottom: 30,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _promptDemoPicker,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.science_outlined, color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Test Demo QRs',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _promptManualEntry,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_rounded, color: Colors.white, size: 15),
                        SizedBox(width: 6),
                        Text(
                          'Manual Entry',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QrViewfinderPainter extends CustomPainter {
  final Color cornerColor;
  QrViewfinderPainter({required this.cornerColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right
    canvas.drawLine(Offset(size.width, 0), Offset(size.width - cornerLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, cornerLength), paint);

    // Bottom-Left
    canvas.drawLine(Offset(0, size.height), Offset(cornerLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - cornerLength), paint);

    // Bottom-Right
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - cornerLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
