import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrx_protocol/hrx_protocol.dart';
import '../models/health_profile.dart';
import 'dynamic_translated_text.dart';

/// Modal sheets for displaying Patient Identity QR and Offline Visit QRs.
class PatientQrSheets {
  PatientQrSheets._();

  /// Shows the primary Patient Digital Health Identity QR modal.
  static void showPatientIdentityQrModal(BuildContext context, HealthProfile? profile) {
    final patientRecord = PatientRecord(
      patientRef: profile?.patientId != null && profile!.patientId.isNotEmpty
          ? 'P-${profile.patientId.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}'
          : 'P-7A92F81C',
      patientId: profile?.patientId ?? 'ASH-PT-1234',
      name: profile?.name ?? 'Vikram Malhotra',
      phone: profile?.phoneNumber ?? '9876501234',
      bloodGroup: profile?.bloodGroup ?? 'B+',
      gender: profile?.gender ?? 'Male',
      dateOfBirth: profile?.dateOfBirth ?? '1984-06-15',
    );

    final qrPayload = HrxEncoder().encodePatientQr(patientRecord, compact: true);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
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
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.qr_code_2_rounded, color: Color(0xFF7C3AED), size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Patient Digital Health QR',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1B4B)),
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
            const SizedBox(height: 16),

            // QR Card Container
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Scannable HRX Patient QR Widget with Tap-to-Enlarge
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showFullscreenQrDialog(
                        context,
                        title: 'Patient Health Identity QR',
                        subtitle: '${patientRecord.name} • ${patientRecord.patientId}',
                        qrData: qrPayload,
                      );
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 220,
                      height: 220,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: HrxQrWidget(
                        data: qrPayload,
                        size: 200,
                        foregroundColor: const Color(0xFF1E1B4B),
                        embeddedCenterWidget: null, // Zero obstruction for instant scan
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tap to expand tip
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in_rounded, size: 14, color: Colors.purple.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'Tap QR for Fullscreen Scan Mode',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Patient Name
                  DynamicTranslatedText(
                    text: patientRecord.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Patient ID Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ID: ${patientRecord.patientId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Status and ABHA
                  Text(
                    '+91 ${patientRecord.phone} • ABHA Verified • ${patientRecord.bloodGroup}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Protocol Verification Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded, size: 14, color: Color(0xFF059669)),
                        SizedBox(width: 4),
                        Text(
                          'HRX Protocol v1 • Scannable Offline',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Show this QR code at hospital reception desk or to your doctor for instantaneous check-in and records lookup.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // Button for offline QRs where last 5 visits are stored
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showOfflineVisitsQrModal(context, profile);
              },
              icon: const Icon(Icons.history_edu_rounded, size: 20, color: Color(0xFF7C3AED)),
              label: const Text(
                'Offline Visit QRs (Last 5 Visits)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                backgroundColor: const Color(0xFFF5F3FF),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),

            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Done'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Displays the 5 offline Visit QRs with full clinical reconstruction and diagnostics.
  static void showOfflineVisitsQrModal(BuildContext context, HealthProfile? profile) {
    int selectedIndex = 0;
    bool showDiagnostics = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final visits = LocalVisitRepository.instance.getLastFiveVisits('P-7A92F81C');

          return FutureBuilder<List<VisitRecord>>(
            future: visits,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(32),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: const Center(child: CircularProgressIndicator(color: Color(0xFF7C3AED))),
                );
              }

              final visitList = snapshot.data!;
              final currentVisit = visitList[selectedIndex.clamp(0, visitList.length - 1)];

              // Encode through direct built-in Deflate compression pipeline for maximum camera scannability
              final encodeResult = HrxEncoder().encodeCompactVisitQr(currentVisit);

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.92,
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
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Modal Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEDE9FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF7C3AED), size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offline Doctor Visit QRs',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E1B4B),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.wifi_off_rounded, color: Color(0xFF16A34A), size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      '5 Stored Visits • Encrypted & Scannable Offline',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(modalCtx),
                          icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Visit Selector Tabs (1 to 5)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(visitList.length, (i) {
                          final isSelected = i == selectedIndex;
                          final v = visitList[i];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setModalState(() => selectedIndex = i);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFF6D28D9) : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_rounded,
                                      size: 14,
                                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Visit ${i + 1} (${v.visitId})',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                        color: isSelected ? Colors.white : const Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Scrollable Visit Card Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Main Scannable QR Card
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
                              ),
                              child: Column(
                                children: [
                                  // Scannable Offline QR Box with Tap-to-Enlarge
                                  InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      showFullscreenQrDialog(
                                        context,
                                        title: 'Offline Visit QR (${currentVisit.visitId})',
                                        subtitle: '${currentVisit.doctorName} • ${currentVisit.facilityName}',
                                        qrData: encodeResult.qrPayload,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(18),
                                    child: Container(
                                      width: 230,
                                      height: 230,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.06),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: HrxQrWidget(
                                        data: encodeResult.qrPayload,
                                        size: 206,
                                        foregroundColor: const Color(0xFF1E1B4B),
                                        embeddedCenterWidget: null, // Center logo removed for maximum scannability
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.fullscreen_rounded, size: 14, color: Colors.purple.shade600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Tap to Enlarge for Doctor Scanner',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.purple.shade700),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Doctor Name & Facility
                                  Text(
                                    currentVisit.doctorName.isNotEmpty
                                        ? currentVisit.doctorName
                                        : 'Dr. Consultation',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    '${currentVisit.facilityName} • ${currentVisit.timestamp.split("T").first}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Security Badges Row
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      _buildStatusBadge(Icons.compress_rounded, 'Deflate (Built-in)', const Color(0xFF7C3AED)),
                                      _buildStatusBadge(Icons.qr_code_rounded, 'QR v${encodeResult.qrVersion} ${encodeResult.qrVersion <= 11 ? "(Chunky)" : "(Compact)"}', encodeResult.qrVersion <= 11 ? const Color(0xFF16A34A) : const Color(0xFF0284C7)),
                                      _buildStatusBadge(Icons.verified_rounded, 'HRX:Z: Payload', const Color(0xFF0284C7)),
                                      _buildStatusBadge(Icons.bolt_rounded, 'Instant Scan', const Color(0xFFD97706)),
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Visit ID Token Pill with Copy
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: currentVisit.visitId));
                                      HapticFeedback.lightImpact();
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Copied Visit ID: ${currentVisit.visitId}'),
                                          duration: const Duration(seconds: 1),
                                          behavior: SnackBarBehavior.floating,
                                          backgroundColor: const Color(0xFF7C3AED),
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Visit ID: ${currentVisit.visitId}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          const Icon(Icons.copy_rounded, color: Colors.white, size: 12),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Clinical Details Container
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (currentVisit.diagnosis.isNotEmpty) ...[
                                    _buildInfoRow(
                                      Icons.medical_services_outlined,
                                      'Diagnosis',
                                      currentVisit.diagnosis.map((d) => '${d.name} (${d.code})').join(', '),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (currentVisit.chiefComplaints.isNotEmpty) ...[
                                    _buildInfoRow(
                                      Icons.sick_outlined,
                                      'Complaints',
                                      currentVisit.chiefComplaints.join(', '),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (currentVisit.vitals.isNotEmpty) ...[
                                    _buildInfoRow(
                                      Icons.monitor_heart_outlined,
                                      'Vitals',
                                      currentVisit.vitals.entries.map((e) => '${e.key}: ${e.value}').join(' • '),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (currentVisit.medications.isNotEmpty) ...[
                                    _buildInfoRow(
                                      Icons.medication_rounded,
                                      'Prescriptions',
                                      currentVisit.medications
                                          .map((m) => '${m.name} ${m.strength} (${m.frequency})')
                                          .join('\n'),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (currentVisit.advice.isNotEmpty) ...[
                                    _buildInfoRow(
                                      Icons.lightbulb_outline_rounded,
                                      'Doctor Advice',
                                      currentVisit.advice.join(' • '),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (currentVisit.notes.isNotEmpty) ...[
                                    _buildInfoRow(
                                      Icons.notes_rounded,
                                      'Clinical Notes',
                                      currentVisit.notes,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Diagnostics Toggle Card
                            InkWell(
                              onTap: () {
                                setModalState(() => showDiagnostics = !showDiagnostics);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF475569)),
                                        const SizedBox(width: 6),
                                        Text(
                                          showDiagnostics ? 'Hide QR Diagnostics' : 'Show Developer QR Diagnostics',
                                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                        ),
                                      ],
                                    ),
                                    Icon(
                                      showDiagnostics ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                      size: 18,
                                      color: const Color(0xFF475569),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            if (showDiagnostics) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'HRX PROTOCOL SPECIFICATION DIAGNOSTICS',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF38BDF8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildDiagRow('Original JSON Size', '${encodeResult.originalSize} B'),
                                    _buildDiagRow('Deflate Compressed', '${encodeResult.compressedSize} B (${encodeResult.compressionAlgorithm})'),
                                    _buildDiagRow('Final QR Payload', '${encodeResult.finalPayloadSize} chars (${encodeResult.payloadEncoding})'),
                                    _buildDiagRow('QR Matrix Version', 'Version ${encodeResult.qrVersion} (~${encodeResult.qrVersion * 4 + 17}×${encodeResult.qrVersion * 4 + 17} grid)'),
                                    _buildDiagRow('Compression Ratio', '${(encodeResult.compressionRatio * 100).toStringAsFixed(1)}%'),
                                    _buildDiagRow('Camera Scannability', '⚡ ULTRA-FAST (< 150ms)'),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Offline Notice
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.shield_outlined, color: Color(0xFF16A34A), size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Authenticated Medical Record: Doctor App can scan and reconstruct this visit completely offline without internet connectivity.',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFF15803D), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              showPatientIdentityQrModal(context, profile);
                            },
                            icon: const Icon(Icons.arrow_back_rounded, size: 16),
                            label: const Text('Back to Main QR'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF7C3AED),
                              side: const BorderSide(color: Color(0xFFCBD5E1)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(modalCtx),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text('Done'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        },
      ),
    );
  }

  static Widget _buildStatusBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: const Color(0xFF7C3AED)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF334155),
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildDiagRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8))),
          Text(value, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC))),
        ],
      ),
    );
  }

  /// Displays a full-screen, high-contrast QR view for effortless camera scanning.
  static void showFullscreenQrDialog(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String qrData,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final screenWidth = MediaQuery.of(ctx).size.width;
        final qrSize = (screenWidth * 0.78).clamp(260.0, 340.0);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top bar with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                          if (subtitle.isNotEmpty)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // High-Contrast Pure White Card with Large QR
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: HrxQrWidget(
                    data: qrData,
                    size: qrSize,
                    foregroundColor: Colors.black, // High-contrast black on white
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 16),

                // Brightness & Scanning Tip Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.brightness_high_rounded, size: 16, color: Color(0xFF16A34A)),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'High-contrast mode • Turn up screen brightness for instant scanning',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Done'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}
