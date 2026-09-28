import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hrx_protocol/hrx_protocol.dart';
import 'package:provider/provider.dart';
import '../../providers/health_profile_provider.dart';

/// Interactive Camera Scanner Screen for scanning Family Member Digital Health QRs.
/// Allows instant QR detection followed by direct relationship selection to save family data.
class FamilyQrCameraScannerScreen extends StatefulWidget {
  const FamilyQrCameraScannerScreen({super.key});

  @override
  State<FamilyQrCameraScannerScreen> createState() => _FamilyQrCameraScannerScreenState();
}

class _FamilyQrCameraScannerScreenState extends State<FamilyQrCameraScannerScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _flashOn = false;
  bool _isRearCamera = true;
  bool _isProcessing = false;

  // Preset mock digital health QR data for realistic one-tap scanning
  final List<Map<String, String>> _sampleFamilyQrs = [
    {
      'name': 'Pooja Malhotra',
      'id': 'ASH-PT-4512',
      'ageGender': '32 Yrs • Female',
      'blood': 'B+ Positive',
      'phone': '+91 98765 43210',
    },
    {
      'name': 'Rohan Malhotra',
      'id': 'ASH-PT-8821',
      'ageGender': '8 Yrs • Male',
      'blood': 'O+ Positive',
      'phone': '+91 98765 01234',
    },
    {
      'name': 'Sita Devi',
      'id': 'ASH-PT-3309',
      'ageGender': '64 Yrs • Female',
      'blood': 'AB+ Positive',
      'phone': '+91 98112 34567',
    },
    {
      'name': 'Amit Malhotra',
      'id': 'ASH-PT-7704',
      'ageGender': '36 Yrs • Male',
      'blood': 'A+ Positive',
      'phone': '+91 99554 12345',
    },
  ];

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    super.dispose();
  }

  void _onQrScanned(Map<String, String> qrData) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    HapticFeedback.heavyImpact();

    // Show relationship selector sheet directly
    _showRelationshipSelectionSheet(qrData);
  }

  void _processRawQrCode(String rawCode) {
    final trimmed = rawCode.trim();
    if (trimmed.isEmpty) return;

    try {
      final decoder = HrxDecoder();
      final result = decoder.decode(trimmed);

      if (result.success && result.patient != null) {
        final p = result.patient!;
        final ageInfo = p.dateOfBirth.isNotEmpty ? p.dateOfBirth : (p.extra['age']?.toString() ?? '');
        final ageGender = [if (ageInfo.isNotEmpty) ageInfo, if (p.gender.isNotEmpty) p.gender].join(' • ');

        _onQrScanned({
          'name': p.name,
          'id': p.patientId.isNotEmpty ? p.patientId : p.patientRef,
          'ageGender': ageGender.isNotEmpty ? ageGender : 'Patient',
          'blood': p.bloodGroup.isNotEmpty ? p.bloodGroup : 'Unknown',
          'phone': p.phone,
        });
        return;
      } else if (result.success && result.visit != null) {
        final v = result.visit!;
        final diagName = v.diagnosis.isNotEmpty ? v.diagnosis.first.name : (v.chiefComplaints.isNotEmpty ? v.chiefComplaints.first : 'Medical Visit');
        _onQrScanned({
          'name': v.patientRef,
          'id': v.patientRef,
          'ageGender': 'Visit • $diagName',
          'blood': 'Unknown',
          'phone': '',
        });
        return;
      }

      // Fallback: Check if it's raw non-HRX JSON
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        final Map<String, dynamic> map = jsonDecode(trimmed) as Map<String, dynamic>;
        final name = map['name'] ?? map['patientName'] ?? 'Family Member';
        final id = map['id'] ?? map['patientId'] ?? map['patientRef'] ?? 'ASH-PT-0000';
        final age = map['age']?.toString() ?? '';
        final gender = map['gender']?.toString() ?? '';
        final blood = map['blood'] ?? map['bloodGroup'] ?? '';
        final phone = map['phone'] ?? map['contact'] ?? '';

        final ageGender = [if (age.isNotEmpty) '$age Yrs', if (gender.isNotEmpty) gender].join(' • ');

        _onQrScanned({
          'name': name.toString(),
          'id': id.toString(),
          'ageGender': ageGender.isNotEmpty ? ageGender : 'Family Member',
          'blood': blood.toString(),
          'phone': phone.toString(),
        });
        return;
      }

      // If format not recognized
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unrecognized QR payload: ${result.errorMessage ?? trimmed.substring(0, math.min(trimmed.length, 30))}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to parse QR code: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  void _showManualQrInputDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 8),
            Text('Enter / Paste QR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Paste an HRX QR string (e.g. HRX:P|1|...) or JSON data to decode:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'HRX:P|1|... or {"name": "..."}',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, size: 20),
                  tooltip: 'Paste from Clipboard',
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      textController.text = data!.text!;
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            onPressed: () {
              final text = textController.text.trim();
              Navigator.pop(dialogCtx);
              if (text.isNotEmpty) {
                _processRawQrCode(text);
              }
            },
            child: const Text('Decode & Add'),
          ),
        ],
      ),
    );
  }

  void _showRelationshipSelectionSheet(Map<String, String> qrData) {
    final name = qrData['name'] ?? 'Family Member';
    final id = qrData['id'] ?? 'ASH-PT-0000';

    final relations = [
      {'label': 'Spouse', 'icon': Icons.favorite_rounded, 'color': const Color(0xFFE11D48)},
      {'label': 'Child', 'icon': Icons.child_care_rounded, 'color': const Color(0xFF0D9488)},
      {'label': 'Father', 'icon': Icons.elderly_rounded, 'color': const Color(0xFF2563EB)},
      {'label': 'Mother', 'icon': Icons.elderly_woman_rounded, 'color': const Color(0xFF7C3AED)},
      {'label': 'Sibling', 'icon': Icons.people_rounded, 'color': const Color(0xFFD97706)},
      {'label': 'Grandparent', 'icon': Icons.family_restroom_rounded, 'color': const Color(0xFF059669)},
      {'label': 'Other', 'icon': Icons.person_outline_rounded, 'color': const Color(0xFF64748B)},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Success Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF16A34A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'QR Scanned Successfully',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E1B4B),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF16A34A)),
                        ],
                      ),
                      const Text(
                        'Select relationship to save family member immediately',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scanned Patient Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDD6FE), width: 1.2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF7C3AED),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'F',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E1B4B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                id,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              qrData['ageGender'] ?? '',
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'SELECT RELATIONSHIP',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 10),

            // Direct 1-Tap Relationship Grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: relations.map((rel) {
                final label = rel['label'] as String;
                final icon = rel['icon'] as IconData;
                final color = rel['color'] as Color;

                return InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(sheetCtx); // Close sheet

                    // Save directly to HealthProfileProvider
                    final provider = Provider.of<HealthProfileProvider>(context, listen: false);
                    await provider.syncFamilyMember(
                      name: name,
                      memberPatientId: id,
                      relation: label,
                    );

                    if (mounted) {
                      Navigator.pop(context); // Close camera screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$name ($label) saved to your family data!',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: const Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: color),
                        const SizedBox(width: 7),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Cancel button
            OutlinedButton(
              onPressed: () {
                Navigator.pop(sheetCtx);
                setState(() => _isProcessing = false);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Rescan / Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final scanBoxSize = math.min(screenSize.width * 0.72, 260.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated Camera Viewport Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [
                    _flashOn ? const Color(0xFF334155) : const Color(0xFF0F172A),
                    Colors.black,
                  ],
                ),
              ),
              child: Center(
                child: Opacity(
                  opacity: 0.12,
                  child: Icon(
                    _isRearCamera ? Icons.camera_alt_rounded : Icons.camera_front_rounded,
                    size: 160,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Central Aperture Cutout with Darkened Surrounding
          Positioned.fill(
            child: CustomPaint(
              painter: _ScannerOverlayPainter(
                boxSize: scanBoxSize,
                flashOn: _flashOn,
              ),
            ),
          ),

          // Animated Laser Line in Center
          Center(
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: Stack(
                children: [
                  // Corner Reticle Brackets
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CornerBracketPainter(color: const Color(0xFF8B5CF6)),
                    ),
                  ),

                  // Center QR Watermark
                  Center(
                    child: Opacity(
                      opacity: 0.25,
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        size: 110,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Moving Laser Beam
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _laserAnimation.value * (scanBoxSize - 4),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3.5,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF8B5CF6),
                                Color(0xFF38BDF8),
                                Color(0xFF8B5CF6),
                                Colors.transparent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.8),
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

          // Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Scan Family Member QR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _flashOn ? Colors.amber : Colors.white,
                          size: 22,
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _flashOn = !_flashOn);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white, size: 22),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          setState(() => _isRearCamera = !_isRearCamera);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Instruction Text below scanner
          Positioned(
            left: 20,
            right: 20,
            top: (screenSize.height / 2) + (scanBoxSize / 2) + 20,
            child: const Column(
              children: [
                Text(
                  'Point camera at family member\'s Digital Health QR',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Align QR code inside the frame to scan instantly',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Quick Scan Deck (For real testing & instant demo recognition)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 26),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.85),
                    Colors.black,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Action Buttons Row: Capture & Manual Paste
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: FilledButton.icon(
                            onPressed: () => _onQrScanned(_sampleFamilyQrs[0]),
                            icon: const Icon(Icons.camera_rounded, size: 19),
                            label: const Text('Scan in Frame', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF7C3AED),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: OutlinedButton.icon(
                            onPressed: _showManualQrInputDialog,
                            icon: const Icon(Icons.paste_rounded, size: 18, color: Color(0xFFDDD6FE)),
                            label: const Text('Paste QR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
                              backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Select Sample QR codes
                    const Text(
                      'OR TAP TO SIMULATE DETECTED QR:',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 8),

                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _sampleFamilyQrs.map((qr) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _onQrScanned(qr),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.qr_code_2_rounded, color: Color(0xFFC4B5FD), size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${qr['name']} (${qr['id']})',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
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

/// Custom painter to darken everything except the central transparent square
class _ScannerOverlayPainter extends CustomPainter {
  final double boxSize;
  final bool flashOn;

  _ScannerOverlayPainter({required this.boxSize, required this.flashOn});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: flashOn ? 0.45 : 0.65);

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: boxSize, height: boxSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) =>
      oldDelegate.boxSize != boxSize || oldDelegate.flashOn != flashOn;
}

/// Custom painter for camera viewfinder corner brackets
class _CornerBracketPainter extends CustomPainter {
  final Color color;

  _CornerBracketPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, cornerLength)
        ..lineTo(0, 0)
        ..lineTo(cornerLength, 0),
      paint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, cornerLength),
      paint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - cornerLength)
        ..lineTo(0, size.height)
        ..lineTo(cornerLength, size.height),
      paint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - cornerLength, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerBracketPainter oldDelegate) => false;
}
