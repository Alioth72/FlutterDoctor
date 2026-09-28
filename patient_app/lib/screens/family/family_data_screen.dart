import 'package:flutter/material.dart';
import '../../providers/language_provider.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/family_member.dart';
import '../../providers/health_profile_provider.dart';
import '../../theme/app_colors.dart';
import 'family_qr_camera_scanner_screen.dart';

class FamilyDataScreen extends StatefulWidget {
  const FamilyDataScreen({super.key});

  @override
  State<FamilyDataScreen> createState() => _FamilyDataScreenState();
}

class _FamilyDataScreenState extends State<FamilyDataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _patientIdController = TextEditingController();
  String _selectedRelation = 'Spouse';
  bool _isSubmitting = false;

    String _relationLabel(String r, LanguageProvider lang) {
    switch (r.toLowerCase()) {
      case 'spouse': return lang.tr('spouse');
      case 'child': return lang.tr('child');
      case 'father': return lang.tr('father');
      case 'mother': return lang.tr('mother');
      case 'sibling': return lang.tr('sibling');
      case 'grandparent': return lang.tr('grandparent');
      default: return lang.tr('other_relation');
    }
  }

  final List<String> _relations = const [
    'Spouse',
    'Child',
    'Father',
    'Mother',
    'Sibling',
    'Grandparent',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _patientIdController.dispose();
    super.dispose();
  }

  void _showAddMemberModal() {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    _nameController.clear();
    _patientIdController.clear();
    _selectedRelation = 'Spouse';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.group_add_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.tr('sync_family_member'),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              lang.tr('link_family_sub'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Member Name
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: lang.tr('family_member_name'),
                      hintText: 'e.g. Pooja Malhotra',
                      prefixIcon: const Icon(Icons.person_outline),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter family member name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Patient ID
                  TextFormField(
                    controller: _patientIdController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: lang.tr('member_patient_id'),
                      hintText: 'e.g. ASH-PT-4512',
                      prefixIcon: const Icon(Icons.badge_outlined),
                      prefixText: 'ID: ',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Please enter their Patient ID';
                      }
                      if (v.trim().length < 4) {
                        return 'Patient ID must be at least 4 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Relationship Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRelation,
                    decoration: InputDecoration(
                      labelText: lang.tr('relationship_label'),
                      prefixIcon: const Icon(Icons.people_outline),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: _relations.map((r) => DropdownMenuItem(value: r, child: Text(_relationLabel(r, lang)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => _selectedRelation = val);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  FilledButton(
                    onPressed: _isSubmitting ? null : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setModalState(() => _isSubmitting = true);

                      final provider = Provider.of<HealthProfileProvider>(context, listen: false);
                      final name = _nameController.text.trim();
                      final id = _patientIdController.text.trim().toUpperCase();
                      final rel = _selectedRelation;

                      await provider.syncFamilyMember(
                        name: name,
                        memberPatientId: id,
                        relation: rel,
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$name (ID: $id) synced with your family data!'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Sync & Link Family Member',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(height: 14),

                  // Divider between manual entry and quick QR camera scan
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'OR SCAN QR',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey.shade300)),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // "Open camera for scanning QR" button
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openCameraForScanningQr(context);
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 20, color: AppColors.primary),
                    label: const Text(
                      'Open camera for scanning QR',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1.6),
                      backgroundColor: const Color(0xFFF5F3FF),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openCameraForScanningQr(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FamilyQrCameraScannerScreen(),
      ),
    );
  }

  void _confirmDeleteMember(BuildContext context, FamilyMember member) {
    final lang = Provider.of<LanguageProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('unlink_family_q')),
        content: Text('${lang.tr('unlink_family_q')} ${member.name} (ID: ${member.patientId})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.tr('close_btn')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<HealthProfileProvider>(context, listen: false).removeFamilyMember(member.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${member.name} unlinked from family data.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(lang.tr('unlink_btn')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HealthProfileProvider>(context);
    final lang = Provider.of<LanguageProvider>(context);
    final profile = provider.profile;
    final myPatientId = profile?.patientId ?? 'ASH-PT-1001';
    final familyList = provider.familyMembers;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        title: Text(
          lang.tr('sync_family_member'),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your Patient ID Card (For sharing with family)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'YOUR PATIENT ID',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: Color(0xFFDDD6FE),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active Account',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        myPatientId,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                        tooltip: 'Copy Patient ID',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: myPatientId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(Provider.of<LanguageProvider>(context, listen: false).tr('patient_id_copied')),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Share this ID with family members to link and synchronize medical records.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Synced Family Members Header + Add CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Synced Family Members',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '${familyList.length} member${familyList.length == 1 ? "" : "s"} linked',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddMemberModal,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                  label: Text(Provider.of<LanguageProvider>(context, listen: false).tr('add_member_btn')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Family Members List or Empty State
            if (familyList.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.family_restroom_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Family Members Linked Yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap "Add Member" above to enter their Name and Patient ID to synchronize health records.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: familyList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final member = familyList[index];
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEDE9FE), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: const Color(0xFFEDE9FE),
                          child: Text(
                            member.name.isNotEmpty ? member.name[0].toUpperCase() : 'F',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      member.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF5F3FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFDDD6FE)),
                                    ),
                                    child: Text(
                                      member.relation,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6D28D9),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  const Icon(Icons.badge_outlined, size: 13, color: Color(0xFF64748B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ID: ${member.patientId}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF334155),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF10B981)),
                                  const SizedBox(width: 3),
                                  const Text(
                                    'Synced',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20),
                          onPressed: () => _confirmDeleteMember(context, member),
                          tooltip: 'Unlink Member',
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
