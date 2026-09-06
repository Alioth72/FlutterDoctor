import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../models/appointment_model.dart';

enum ColleagueStatus { online, inSurgery, busy, offline }

class ColleagueDoctor {
  final String id;
  final String name;
  final String department;
  final String hospital;
  final String experience;
  final ColleagueStatus status;
  final String avatarInitials;
  final String phone;
  final String email;

  const ColleagueDoctor({
    required this.id,
    required this.name,
    required this.department,
    required this.hospital,
    required this.experience,
    required this.status,
    required this.avatarInitials,
    required this.phone,
    required this.email,
  });
}

class ChatConsultMessage {
  final String id;
  final String sender;
  final String text;
  final DateTime time;
  final bool isPrescriptionReview;
  final String? drugName;
  final String? dosage;
  final String? diagnosis;
  final String? patientName;
  final String? status;

  ChatConsultMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.isPrescriptionReview = false,
    this.drugName,
    this.dosage,
    this.diagnosis,
    this.patientName,
    this.status,
  });
}

// -------------------------------------------------------------
// PRE-POPULATED PRESCRIPTION REVIEW DIALOG/MODAL
// Automatically fills patient name, age, gender, diagnosis & meds
// -------------------------------------------------------------
void openAutoPrescriptionReviewModal({
  required BuildContext context,
  required AppointmentItem appt,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => AutoPrescriptionReviewSheet(appt: appt),
  );
}

class AutoPrescriptionReviewSheet extends StatefulWidget {
  final AppointmentItem appt;
  const AutoPrescriptionReviewSheet({super.key, required this.appt});

  @override
  State<AutoPrescriptionReviewSheet> createState() => _AutoPrescriptionReviewSheetState();
}

class _AutoPrescriptionReviewSheetState extends State<AutoPrescriptionReviewSheet> {
  late TextEditingController _patientCtrl;
  late TextEditingController _diagnosisCtrl;
  late TextEditingController _medicinesCtrl;
  late TextEditingController _concernCtrl;

  ColleagueDoctor? _selectedDoctor;
  String _selectedDepartment = 'Pharmacology & Toxicology';

  final List<String> _departments = [
    'Pharmacology & Toxicology',
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Internal Medicine',
    'Pediatrics',
    'Nephrology',
    'Pulmonology',
  ];

  final List<ColleagueDoctor> _allColleagues = const [
    ColleagueDoctor(
      id: 'DOC-102',
      name: 'Dr. Ananya Iyer',
      department: 'Pharmacology & Toxicology',
      hospital: 'Safdarjung Hospital',
      experience: '14 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'AI',
      phone: '+91 98202 34567',
      email: 'dr.ananya.i@safdarjung.nic.in',
    ),
    ColleagueDoctor(
      id: 'DOC-101',
      name: 'Dr. Ramesh Chandra',
      department: 'Cardiology',
      hospital: 'AIIMS New Delhi',
      experience: '18 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'RC',
      phone: '+91 98101 23456',
      email: 'dr.ramesh.c@aiims.edu',
    ),
    ColleagueDoctor(
      id: 'DOC-103',
      name: 'Dr. Vikramaditya Rathore',
      department: 'Neurology',
      hospital: 'Max Super Speciality',
      experience: '22 yrs exp',
      status: ColleagueStatus.busy,
      avatarInitials: 'VR',
      phone: '+91 98711 45678',
      email: 'dr.rathore@maxhealth.com',
    ),
    ColleagueDoctor(
      id: 'DOC-104',
      name: 'Dr. Sunita Deshmukh',
      department: 'Nephrology',
      hospital: 'Fortis Escorts',
      experience: '16 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'SD',
      phone: '+91 98333 56789',
      email: 'dr.sunita@fortis.com',
    ),
    ColleagueDoctor(
      id: 'DOC-105',
      name: 'Dr. Harpreet Singh',
      department: 'Internal Medicine',
      hospital: 'RML Hospital',
      experience: '11 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'HS',
      phone: '+91 98112 67890',
      email: 'dr.harpreet@rml.gov.in',
    ),
    ColleagueDoctor(
      id: 'DOC-106',
      name: 'Dr. Kavita Menon',
      department: 'Pediatrics',
      hospital: 'Apollo Hospital',
      experience: '15 yrs exp',
      status: ColleagueStatus.inSurgery,
      avatarInitials: 'KM',
      phone: '+91 98450 78901',
      email: 'dr.kavita@apollo.com',
    ),
    ColleagueDoctor(
      id: 'DOC-107',
      name: 'Dr. Alok Verma',
      department: 'Orthopedics',
      hospital: 'Medanta Medicity',
      experience: '19 yrs exp',
      status: ColleagueStatus.offline,
      avatarInitials: 'AV',
      phone: '+91 98990 89012',
      email: 'dr.alok@medanta.org',
    ),
    ColleagueDoctor(
      id: 'DOC-108',
      name: 'Dr. Farhan Siddiqui',
      department: 'Pulmonology',
      hospital: 'Sir Ganga Ram Hospital',
      experience: '13 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'FS',
      phone: '+91 98188 90123',
      email: 'dr.farhan@sgrh.com',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final a = widget.appt;

    // Format medicines from appointment
    final medsSummary = a.medicines.isNotEmpty
        ? a.medicines.map((m) => '• ${m.name} (${m.dosage} - ${m.duration})').join('\n')
        : 'Paracetamol 650mg TDS, Amoxicillin 500mg BD';

    _patientCtrl = TextEditingController(text: '${a.patientName} (${a.age} yrs, ${a.gender}) [Appt: ${a.appointmentNo}]');
    _diagnosisCtrl = TextEditingController(
      text: a.diagnosis.isNotEmpty ? a.diagnosis : 'Viral Upper Respiratory Infection + Mild Hypertension',
    );
    _medicinesCtrl = TextEditingController(text: medsSummary);
    _concernCtrl = TextEditingController(
      text: 'Uncertain if proposed dosage/combination has contraindications or requires renal/hepatic adjustments.',
    );

    // Default select first doctor in department
    final deptDocs = _allColleagues.where((d) => d.department == _selectedDepartment).toList();
    _selectedDoctor = deptDocs.isNotEmpty ? deptDocs.first : _allColleagues.first;
  }

  @override
  void dispose() {
    _patientCtrl.dispose();
    _diagnosisCtrl.dispose();
    _medicinesCtrl.dispose();
    _concernCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableDoctorsInDept = _allColleagues.where((d) => d.department == _selectedDepartment).toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
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
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prescription Second Opinion',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                      ),
                      Text(
                        'Auto-populated from this patient appointment card',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Select Target Department
            const Text('Consult Department', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.headingText)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedDepartment,
                  items: _departments.map((dept) {
                    return DropdownMenuItem(
                      value: dept,
                      child: Text(dept, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDepartment = val;
                        final matched = _allColleagues.where((d) => d.department == val).toList();
                        _selectedDoctor = matched.isNotEmpty ? matched.first : _allColleagues.first;
                      });
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Select Colleague Doctor in that Department
            const Text('Select Specialist / Colleague', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.headingText)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<ColleagueDoctor>(
                  isExpanded: true,
                  value: _selectedDoctor,
                  items: (availableDoctorsInDept.isNotEmpty ? availableDoctorsInDept : _allColleagues).map((doc) {
                    return DropdownMenuItem(
                      value: doc,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(doc.avatarInitials, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${doc.name} • ${doc.hospital}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDoctor = val);
                  },
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Auto-populated fields
            _buildField('Patient Demographics', _patientCtrl, Icons.person_outline, readOnly: true),
            const SizedBox(height: 10),
            _buildField('Diagnosis / Condition', _diagnosisCtrl, Icons.medical_services_outlined),
            const SizedBox(height: 10),
            _buildField('Prescription Medications', _medicinesCtrl, Icons.medication_outlined, maxLines: 3),
            const SizedBox(height: 10),
            _buildField('Your Concern / Specific Question', _concernCtrl, Icons.help_outline, maxLines: 2),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final targetDoctor = _selectedDoctor ?? _allColleagues.first;
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ColleagueChatScreen(
                        colleague: targetDoctor,
                        initialCustomRxRequest: 'Rx Verification Request:\n• Patient: ${_patientCtrl.text}\n• Diagnosis: ${_diagnosisCtrl.text}\n• Prescribed Meds:\n${_medicinesCtrl.text}\n• Concern: ${_concernCtrl.text}',
                        patientName: widget.appt.patientName,
                        diagnosis: widget.appt.diagnosis.isNotEmpty ? widget.appt.diagnosis : _diagnosisCtrl.text,
                        drugSummary: _medicinesCtrl.text,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  'Send to ${_selectedDoctor?.name.split(" ").first ?? "Doctor"} for Second Opinion',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1, bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.headingText)),
            if (readOnly) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                child: const Text('AUTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          readOnly: readOnly,
          style: TextStyle(fontSize: 13, color: readOnly ? Colors.grey[800] : Colors.black87),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: AppColors.primary),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF1F5F9) : Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------
// COLLEAGUE CONSULT DIRECTORY SCREEN (CLEANED - Only "Consult" button)
// -------------------------------------------------------------
class ColleagueConsultScreen extends StatefulWidget {
  const ColleagueConsultScreen({super.key});

  @override
  State<ColleagueConsultScreen> createState() => _ColleagueConsultScreenState();
}

class _ColleagueConsultScreenState extends State<ColleagueConsultScreen> {
  String _selectedDepartment = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _departments = [
    'All',
    'Cardiology',
    'Neurology',
    'Orthopedics',
    'Pharmacology & Toxicology',
    'Internal Medicine',
    'Pediatrics',
    'Nephrology',
    'Pulmonology',
  ];

  final List<ColleagueDoctor> _colleagues = const [
    ColleagueDoctor(
      id: 'DOC-101',
      name: 'Dr. Ramesh Chandra',
      department: 'Cardiology',
      hospital: 'AIIMS New Delhi',
      experience: '18 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'RC',
      phone: '+91 98101 23456',
      email: 'dr.ramesh.c@aiims.edu',
    ),
    ColleagueDoctor(
      id: 'DOC-102',
      name: 'Dr. Ananya Iyer',
      department: 'Pharmacology & Toxicology',
      hospital: 'Safdarjung Hospital',
      experience: '14 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'AI',
      phone: '+91 98202 34567',
      email: 'dr.ananya.i@safdarjung.nic.in',
    ),
    ColleagueDoctor(
      id: 'DOC-103',
      name: 'Dr. Vikramaditya Rathore',
      department: 'Neurology',
      hospital: 'Max Super Speciality',
      experience: '22 yrs exp',
      status: ColleagueStatus.busy,
      avatarInitials: 'VR',
      phone: '+91 98711 45678',
      email: 'dr.rathore@maxhealth.com',
    ),
    ColleagueDoctor(
      id: 'DOC-104',
      name: 'Dr. Sunita Deshmukh',
      department: 'Nephrology',
      hospital: 'Fortis Escorts',
      experience: '16 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'SD',
      phone: '+91 98333 56789',
      email: 'dr.sunita@fortis.com',
    ),
    ColleagueDoctor(
      id: 'DOC-105',
      name: 'Dr. Harpreet Singh',
      department: 'Internal Medicine',
      hospital: 'RML Hospital',
      experience: '11 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'HS',
      phone: '+91 98112 67890',
      email: 'dr.harpreet@rml.gov.in',
    ),
    ColleagueDoctor(
      id: 'DOC-106',
      name: 'Dr. Kavita Menon',
      department: 'Pediatrics',
      hospital: 'Apollo Hospital',
      experience: '15 yrs exp',
      status: ColleagueStatus.inSurgery,
      avatarInitials: 'KM',
      phone: '+91 98450 78901',
      email: 'dr.kavita@apollo.com',
    ),
    ColleagueDoctor(
      id: 'DOC-107',
      name: 'Dr. Alok Verma',
      department: 'Orthopedics',
      hospital: 'Medanta Medicity',
      experience: '19 yrs exp',
      status: ColleagueStatus.offline,
      avatarInitials: 'AV',
      phone: '+91 98990 89012',
      email: 'dr.alok@medanta.org',
    ),
    ColleagueDoctor(
      id: 'DOC-108',
      name: 'Dr. Farhan Siddiqui',
      department: 'Pulmonology',
      hospital: 'Sir Ganga Ram Hospital',
      experience: '13 yrs exp',
      status: ColleagueStatus.online,
      avatarInitials: 'FS',
      phone: '+91 98188 90123',
      email: 'dr.farhan@sgrh.com',
    ),
  ];

  List<ColleagueDoctor> get _filteredColleagues {
    return _colleagues.where((doc) {
      final matchesDept = _selectedDepartment == 'All' || doc.department == _selectedDepartment;
      final matchesSearch = doc.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc.department.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          doc.hospital.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesDept && matchesSearch;
    }).toList();
  }

  Color _statusColor(ColleagueStatus status) {
    switch (status) {
      case ColleagueStatus.online:
        return const Color(0xFF10B981);
      case ColleagueStatus.busy:
        return const Color(0xFFF59E0B);
      case ColleagueStatus.inSurgery:
        return const Color(0xFFEF4444);
      case ColleagueStatus.offline:
        return const Color(0xFF9CA3AF);
    }
  }

  String _statusLabel(ColleagueStatus status) {
    switch (status) {
      case ColleagueStatus.online:
        return 'Online';
      case ColleagueStatus.busy:
        return 'In Consult';
      case ColleagueStatus.inSurgery:
        return 'In Surgery';
      case ColleagueStatus.offline:
        return 'Off Duty';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startConsultation(ColleagueDoctor doctor) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ColleagueChatScreen(colleague: doctor),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Colleague Consult', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Doctor-to-Doctor Hospital Network', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inter-Department Specialist Directory',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Connect directly with specialist colleagues across departments and hospitals.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search doctor, specialty, or hospital...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _departments.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final dept = _departments[idx];
                final isSelected = dept == _selectedDepartment;
                return ChoiceChip(
                  label: Text(dept),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDepartment = dept);
                  },
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.headingText,
                  ),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                  ),
                  showCheckmark: false,
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _filteredColleagues.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined, size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 10),
                        Text('No doctors found in "$_selectedDepartment"',
                            style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: _filteredColleagues.length,
                    itemBuilder: (context, index) {
                      final doc = _filteredColleagues[index];
                      final statusCol = _statusColor(doc.status);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                    child: Text(
                                      doc.avatarInitials,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 1,
                                    right: 1,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: statusCol,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            doc.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.headingText,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusCol.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _statusLabel(doc.status),
                                            style: TextStyle(
                                              color: statusCol,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      doc.department,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.local_hospital_outlined, size: 13, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${doc.hospital} • ${doc.experience}',
                                            style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _startConsultation(doc),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                label: const Text('Consult', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// CHAT SCREEN BETWEEN DOCTORS
// -------------------------------------------------------------
class ColleagueChatScreen extends StatefulWidget {
  final ColleagueDoctor colleague;
  final String? initialCustomRxRequest;
  final String? patientName;
  final String? diagnosis;
  final String? drugSummary;

  const ColleagueChatScreen({
    super.key,
    required this.colleague,
    this.initialCustomRxRequest,
    this.patientName,
    this.diagnosis,
    this.drugSummary,
  });

  @override
  State<ColleagueChatScreen> createState() => _ColleagueChatScreenState();
}

class _ColleagueChatScreenState extends State<ColleagueChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatConsultMessage> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadSampleConversation();

    if (widget.initialCustomRxRequest != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(
          text: widget.initialCustomRxRequest!,
          isRx: true,
          patientName: widget.patientName,
          diagnosis: widget.diagnosis,
          drugName: widget.drugSummary,
        );
      });
    }
  }

  void _loadSampleConversation() {
    _messages.add(
      ChatConsultMessage(
        id: '1',
        sender: 'doctor',
        text: 'Hello, how can I assist you in ${widget.colleague.department} today?',
        time: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
    );
  }

  void _sendMessage({
    required String text,
    bool isRx = false,
    String? drugName,
    String? dosage,
    String? diagnosis,
    String? patientName,
  }) {
    if (text.trim().isEmpty && !isRx) return;

    setState(() {
      _messages.add(
        ChatConsultMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          sender: 'me',
          text: text,
          time: DateTime.now(),
          isPrescriptionReview: isRx,
          drugName: drugName,
          dosage: dosage,
          diagnosis: diagnosis,
          patientName: patientName,
        ),
      );
    });

    _msgController.clear();
    _scrollToBottom();

    if (isRx) {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() {
          _messages.add(
            ChatConsultMessage(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              sender: 'doctor',
              text:
                  'Reviewed! For $patientName with $diagnosis, the proposed prescription looks clinically sound. Monitor electrolytes and renal parameters after 5 days.',
              time: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _callDoctor() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Calling ${widget.colleague.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
            'Doctor VoIP Line: ${widget.colleague.phone}\nDepartment: ${widget.colleague.department}\nHospital: ${widget.colleague.hospital}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('End Call', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(widget.colleague.avatarInitials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.colleague.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis),
                  Text('${widget.colleague.department} • ${widget.colleague.hospital}',
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.phone_rounded), tooltip: 'Call Doctor', onPressed: _callDoctor),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, idx) {
                final msg = _messages[idx];
                final isMe = msg.sender == 'me';

                if (msg.isPrescriptionReview) {
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.85,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.medication_liquid_rounded, size: 18, color: AppColors.primary),
                                SizedBox(width: 6),
                                Text(
                                  'AUTO-FETCHED PRESCRIPTION REVIEW',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient: ${msg.patientName ?? "N/A"}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Diagnosis: ${msg.diagnosis ?? "N/A"}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration:
                                      BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    msg.drugName ?? 'No medicines attached',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.primaryDark),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(msg.text, style: const TextStyle(fontSize: 12, height: 1.3)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(color: isMe ? Colors.white : AppColors.headingText, fontSize: 13, height: 1.3),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: Colors.white,
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Discuss case or ask recommendation...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      ),
                      onSubmitted: (val) => _sendMessage(text: val),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 20,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                      onPressed: () => _sendMessage(text: _msgController.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
