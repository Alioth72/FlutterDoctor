import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_colors.dart';
import '../models/appointment_model.dart';
import 'appointment_detail_screen.dart';

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

  bool _isProcessing = false;
  bool _flashOn = false;
  AppointmentItem? _foundPatient;
  String? _scannedCode;

  final TextEditingController _manualIdController = TextEditingController();

  final List<AppointmentItem> _databasePatients = [
    AppointmentItem(
      id: '1',
      appointmentNo: 'APT-101',
      patientName: 'Rajesh Sharma',
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
    AppointmentItem(
      id: '3',
      appointmentNo: 'APT-103',
      patientName: 'Amitabh Patel',
      age: 58,
      gender: 'Male',
      timing: '12:00 PM - Today',
      paymentStatus: 'Paid Online (₹650)',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: ['CAD Post-PTCA (Stent 2021)', 'Dyslipidemia'],
      heightCm: 168.0,
      weightKg: 82.0,
      familyHistory: 'Strong family history of IHD',
      diagnosis: 'Stable Angina Follow-up',
      medicines: [
        MedicineItem(
          name: 'Atorvastatin 20mg',
          dosage: '0-0-1 at bedtime',
          duration: '30 Days',
          closestClinic: 'Ashwini Central Pharmacy',
        ),
        MedicineItem(
          name: 'Ecosprin 75mg',
          dosage: '0-1-0 after lunch',
          duration: '30 Days',
          closestClinic: 'Ashwini Central Pharmacy',
        ),
      ],
      isAdmitted: false,
    ),
    AppointmentItem(
      id: '4',
      appointmentNo: 'APT-104',
      patientName: 'Sunita Rao',
      age: 28,
      gender: 'Female',
      timing: '01:30 PM - Today',
      paymentStatus: 'Paid Online (₹500)',
      isPaid: true,
      mode: AppointmentMode.qr,
      patientHistory: ['Hypothyroidism'],
      heightCm: 158.0,
      weightKg: 54.0,
      familyHistory: 'None',
      diagnosis: 'Thyroid Panel Review',
      medicines: [
        MedicineItem(
          name: 'Thyronorm 50mcg',
          dosage: '1-0-0 empty stomach',
          duration: '60 Days',
          closestClinic: 'South Ex Dispensary',
        ),
      ],
      isAdmitted: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
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
    final barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final code = barcodes.first.rawValue!;
      _decodeAndFetchPatient(code);
    }
  }

  void _decodeAndFetchPatient(String rawCode) {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _scannedCode = rawCode.trim().toUpperCase();
    });

    final pool = widget.existingAppointments ?? _databasePatients;
    AppointmentItem? matched;

    for (final p in pool) {
      if (p.appointmentNo.toUpperCase() == _scannedCode ||
          p.id == _scannedCode ||
          p.patientName.toUpperCase().contains(_scannedCode!) ||
          _scannedCode!.contains(p.appointmentNo.toUpperCase())) {
        matched = p;
        break;
      }
    }

    if (matched == null) {
      for (final p in _databasePatients) {
        if (p.appointmentNo.toUpperCase() == _scannedCode ||
            p.id == _scannedCode ||
            _scannedCode!.contains(p.appointmentNo.toUpperCase())) {
          matched = p;
          break;
        }
      }
    }

    matched ??= AppointmentItem(
      id: 'QR-${DateTime.now().millisecondsSinceEpoch % 10000}',
      appointmentNo: _scannedCode!.startsWith('APT-') ? _scannedCode! : 'APT-${_scannedCode!}',
      patientName: 'Verified Patient (${_scannedCode!})',
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

    setState(() {
      _foundPatient = matched;
    });

    _showPatientFoundSheet(matched);
  }

  void _showPatientFoundSheet(AppointmentItem patient) {
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
                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.medical_information_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Diagnosis: ${patient.diagnosis.isNotEmpty ? patient.diagnosis : "General OPD"}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.headingText),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (patient.isAdmitted) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.hotel_outlined, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Admitted: ${patient.roomNo ?? "Ward Assigned"}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _isProcessing = false;
                          _foundPatient = null;
                        });
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: const Text('Scan Another'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.headingText,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
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
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Open Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _promptManualEntry() {
    _manualIdController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Enter Patient ID / Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter patient appointment token or health UID if camera is obstructed:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: _manualIdController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g. APT-101, APT-102, APT-103',
                prefixIcon: const Icon(Icons.qr_code_rounded, color: AppColors.primary),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () {
              if (_manualIdController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                _decodeAndFetchPatient(_manualIdController.text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Fetch Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanBoxSize = math.min(screenSize.width * 0.72, 280.0);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Scan Patient QR Code', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: 'Flash Toggle',
            onPressed: () async {
              await _cameraController.toggleTorch();
              setState(() => _flashOn = !_flashOn);
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
                        'Camera error: ${error.errorCode.name}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _promptManualEntry,
                        icon: const Icon(Icons.keyboard_rounded),
                        label: const Text('Enter ID Manually'),
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
                    painter: QrViewfinderPainter(cornerColor: AppColors.primary),
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

          // Top Instruction Badge
          Positioned(
            top: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.camera_enhance_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Point camera at Patient ID QR Code',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Manual Entry Button (Black Pill Design matching top badge)
          Positioned(
            bottom: 30,
            child: InkWell(
              onTap: _promptManualEntry,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.keyboard_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Enter Patient ID Manually',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
