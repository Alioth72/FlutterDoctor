import 'package:flutter/material.dart';

class BedInfo {
  final String id;
  final String bedNumber;
  bool isOccupied;
  String? patientName;
  int? patientAge;
  String? patientGender;
  String? admissionDate;
  String? primaryDiagnosis;

  BedInfo({
    required this.id,
    required this.bedNumber,
    required this.isOccupied,
    this.patientName,
    this.patientAge,
    this.patientGender,
    this.admissionDate,
    this.primaryDiagnosis,
  });

  void assign({
    required String name,
    required int age,
    required String gender,
    required String diagnosis,
    String? date,
  }) {
    isOccupied = true;
    patientName = name;
    patientAge = age;
    patientGender = gender;
    primaryDiagnosis = diagnosis;
    admissionDate = date ?? 'Today, Just Now';
  }

  void vacate() {
    isOccupied = false;
    patientName = null;
    patientAge = null;
    patientGender = null;
    admissionDate = null;
    primaryDiagnosis = null;
  }
}

class EquipmentInfo {
  final String id;
  final String name;
  final String model;
  final String category;
  final String status; // 'Operational', 'In Use', 'Calibrated', 'Standby'
  final String serialNumber;
  final String lastMaintenance;

  EquipmentInfo({
    required this.id,
    required this.name,
    required this.model,
    required this.category,
    required this.status,
    required this.serialNumber,
    required this.lastMaintenance,
  });
}

class RoomInfo {
  final String id;
  final String roomNumber;
  final String roomName;
  final String floor;
  final String departmentId;
  final String hospitalId;
  final List<BedInfo> beds;
  final List<EquipmentInfo> equipments;

  RoomInfo({
    required this.id,
    required this.roomNumber,
    required this.roomName,
    required this.floor,
    required this.departmentId,
    required this.hospitalId,
    required this.beds,
    required this.equipments,
  });

  int get totalBeds => beds.length;
  int get occupiedBeds => beds.where((b) => b.isOccupied).length;
  int get availableBeds => beds.where((b) => !b.isOccupied).length;

  bool hasEquipment(String query) {
    if (query.trim().isEmpty) return true;
    final q = query.toLowerCase().trim();
    return equipments.any((e) =>
        e.name.toLowerCase().contains(q) ||
        e.category.toLowerCase().contains(q) ||
        e.model.toLowerCase().contains(q));
  }
}

class HospitalDepartment {
  final String id;
  final String name;
  final IconData icon;

  HospitalDepartment({
    required this.id,
    required this.name,
    required this.icon,
  });
}

class DoctorHospital {
  final String id;
  final String name;
  final String branch;
  final String address;
  final List<HospitalDepartment> departments;

  DoctorHospital({
    required this.id,
    required this.name,
    required this.branch,
    required this.address,
    required this.departments,
  });
}

class RoomMachineRepository {
  static List<DoctorHospital> getDoctorHospitals() {
    return [
      DoctorHospital(
        id: 'hosp_1',
        name: 'Ashwini Central Hospital',
        branch: 'Super-Speciality Block',
        address: 'Sector 14, Main Institutional Area',
        departments: [
          HospitalDepartment(id: 'dept_cardio', name: 'Cardiology', icon: Icons.favorite_rounded),
          HospitalDepartment(id: 'dept_icu', name: 'Intensive Care (ICU)', icon: Icons.health_and_safety_rounded),
          HospitalDepartment(id: 'dept_gen_med', name: 'General Medicine', icon: Icons.medical_services_rounded),
          HospitalDepartment(id: 'dept_emergency', name: 'Emergency & Trauma', icon: Icons.emergency_rounded),
          HospitalDepartment(id: 'dept_pulmo', name: 'Pulmonology', icon: Icons.air_rounded),
          HospitalDepartment(id: 'dept_neuro', name: 'Neurology', icon: Icons.psychology_rounded),
        ],
      ),
      DoctorHospital(
        id: 'hosp_2',
        name: 'AIIMS New Delhi',
        branch: 'Cardio-Thoracic & Neurosciences Centre',
        address: 'Ansari Nagar, New Delhi',
        departments: [
          HospitalDepartment(id: 'dept_cardio', name: 'Cardiology', icon: Icons.favorite_rounded),
          HospitalDepartment(id: 'dept_icu', name: 'Intensive Care (ICU)', icon: Icons.health_and_safety_rounded),
          HospitalDepartment(id: 'dept_gen_med', name: 'General Medicine', icon: Icons.medical_services_rounded),
          HospitalDepartment(id: 'dept_emergency', name: 'Emergency & Trauma', icon: Icons.emergency_rounded),
        ],
      ),
      DoctorHospital(
        id: 'hosp_3',
        name: 'Metro Healthcare OPD',
        branch: 'Consultant Clinical Annex',
        address: 'Ring Road, South City',
        departments: [
          HospitalDepartment(id: 'dept_gen_med', name: 'General Medicine', icon: Icons.medical_services_rounded),
          HospitalDepartment(id: 'dept_cardio', name: 'Cardiology', icon: Icons.favorite_rounded),
          HospitalDepartment(id: 'dept_pulmo', name: 'Pulmonology', icon: Icons.air_rounded),
        ],
      ),
      DoctorHospital(
        id: 'hosp_4',
        name: 'Apollo Multi-Speciality',
        branch: 'Sarita Vihar Wing',
        address: 'Mathura Road, New Delhi',
        departments: [
          HospitalDepartment(id: 'dept_icu', name: 'Intensive Care (ICU)', icon: Icons.health_and_safety_rounded),
          HospitalDepartment(id: 'dept_cardio', name: 'Cardiology', icon: Icons.favorite_rounded),
          HospitalDepartment(id: 'dept_emergency', name: 'Emergency & Trauma', icon: Icons.emergency_rounded),
        ],
      ),
    ];
  }

  static List<RoomInfo> getAllRooms() {
    return [
      // ==================== ASHWINI CENTRAL HOSPITAL - CARDIOLOGY ====================
      RoomInfo(
        id: 'rm_c101',
        roomNumber: 'Room C-101',
        roomName: 'Cardiac Acute Care Bay 1',
        floor: '1st Floor, Cardiac Wing',
        departmentId: 'dept_cardio',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_101_1',
            bedNumber: 'Bed 1',
            isOccupied: true,
            patientName: 'Rameshwar Verma',
            patientAge: 58,
            patientGender: 'Male',
            admissionDate: '04 Sep, 02:30 PM',
            primaryDiagnosis: 'Unstable Angina, Post-Angioplasty Monitoring',
          ),
          BedInfo(
            id: 'b_101_2',
            bedNumber: 'Bed 2',
            isOccupied: false,
          ),
          BedInfo(
            id: 'b_101_3',
            bedNumber: 'Bed 3',
            isOccupied: true,
            patientName: 'Meenakshi Sundaram',
            patientAge: 64,
            patientGender: 'Female',
            admissionDate: '05 Sep, 10:15 AM',
            primaryDiagnosis: 'Acute Coronary Syndrome',
          ),
          BedInfo(
            id: 'b_101_4',
            bedNumber: 'Bed 4',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_1',
            name: 'Multipara ECG Monitor',
            model: 'Philips IntelliVue MX750',
            category: 'Cardiac Monitoring',
            status: 'Operational',
            serialNumber: 'PM-CARD-9012',
            lastMaintenance: '28 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_2',
            name: 'Automated External Defibrillator',
            model: 'Zoll R Series Plus',
            category: 'Emergency Resuscitation',
            status: 'Operational',
            serialNumber: 'DF-ZOLL-4411',
            lastMaintenance: '01 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_3',
            name: 'Syringe Infusion Pump',
            model: 'B. Braun Space Perfusor',
            category: 'Infusion System',
            status: 'In Use',
            serialNumber: 'IP-BRN-8821',
            lastMaintenance: '20 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_c102',
        roomNumber: 'Room C-102',
        roomName: 'Cardiology Sub-Acute Ward',
        floor: '1st Floor, Cardiac Wing',
        departmentId: 'dept_cardio',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_102_1',
            bedNumber: 'Bed 1',
            isOccupied: true,
            patientName: 'Sunita Chauhan',
            patientAge: 52,
            patientGender: 'Female',
            admissionDate: '03 Sep, 08:45 PM',
            primaryDiagnosis: 'Atrial Fibrillation with RVR',
          ),
          BedInfo(
            id: 'b_102_2',
            bedNumber: 'Bed 2',
            isOccupied: true,
            patientName: 'Kishore Mathur',
            patientAge: 71,
            patientGender: 'Male',
            admissionDate: '05 Sep, 11:30 AM',
            primaryDiagnosis: 'Congestive Heart Failure NYHA-III',
          ),
          BedInfo(
            id: 'b_102_3',
            bedNumber: 'Bed 3',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_4',
            name: '12-Lead Digital ECG Machine',
            model: 'GE MAC 2000 Diagnostic',
            category: 'Diagnostics',
            status: 'Operational',
            serialNumber: 'ECG-GEM-1102',
            lastMaintenance: '25 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_5',
            name: 'Cardiac Telemetry Transmitter',
            model: 'Mindray BeneVision TM80',
            category: 'Telemetry',
            status: 'In Use',
            serialNumber: 'TL-MND-3390',
            lastMaintenance: '15 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_c103',
        roomNumber: 'Room C-103',
        roomName: 'Cardiac Catheterization Recovery',
        floor: '1st Floor, Cardiac Wing',
        departmentId: 'dept_cardio',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_103_1',
            bedNumber: 'Bed 1',
            isOccupied: true,
            patientName: 'Harish Chandra',
            patientAge: 62,
            patientGender: 'Male',
            admissionDate: '06 Sep, 09:00 AM',
            primaryDiagnosis: 'Post-PTCA Stent Recovery',
          ),
          BedInfo(
            id: 'b_103_2',
            bedNumber: 'Bed 2',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_6',
            name: 'Mechanical Ventilator',
            model: 'Hamilton-C6 High End',
            category: 'Respiratory Support',
            status: 'Operational',
            serialNumber: 'VT-HAM-7740',
            lastMaintenance: '02 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_7',
            name: 'Intra-Aortic Balloon Pump (IABP)',
            model: 'Getinge Cardiosave Hybrid',
            category: 'Circulatory Support',
            status: 'Standby',
            serialNumber: 'IABP-GET-009',
            lastMaintenance: '30 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_8',
            name: 'Multipara ECG Monitor',
            model: 'Philips IntelliVue MX750',
            category: 'Cardiac Monitoring',
            status: 'In Use',
            serialNumber: 'PM-CARD-9015',
            lastMaintenance: '28 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_c104',
        roomNumber: 'Room C-104',
        roomName: 'Cardiology Step-Down Suite',
        floor: '1st Floor, Cardiac Wing',
        departmentId: 'dept_cardio',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_104_1',
            bedNumber: 'Bed 1',
            isOccupied: false,
          ),
          BedInfo(
            id: 'b_104_2',
            bedNumber: 'Bed 2',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_9',
            name: 'Multipara ECG Monitor',
            model: 'Mindray ePM 12M',
            category: 'Vital Monitoring',
            status: 'Operational',
            serialNumber: 'PM-MND-4412',
            lastMaintenance: '10 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_10',
            name: 'Automated External Defibrillator',
            model: 'Philips HeartStart FRx',
            category: 'Emergency Resuscitation',
            status: 'Operational',
            serialNumber: 'DF-PHL-9923',
            lastMaintenance: '12 Aug 2026',
          ),
        ],
      ),

      // ==================== ASHWINI CENTRAL HOSPITAL - ICU ====================
      RoomInfo(
        id: 'rm_icu_201',
        roomNumber: 'ICU Bay 1',
        roomName: 'Medical Intensive Care Unit',
        floor: '2nd Floor, Critical Care Block',
        departmentId: 'dept_icu',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_icu1_1',
            bedNumber: 'Bed ICU-01',
            isOccupied: true,
            patientName: 'Devendra Joshi',
            patientAge: 69,
            patientGender: 'Male',
            admissionDate: '02 Sep, 04:20 PM',
            primaryDiagnosis: 'Septic Shock with ARDS',
          ),
          BedInfo(
            id: 'b_icu1_2',
            bedNumber: 'Bed ICU-02',
            isOccupied: true,
            patientName: 'Anita Saxena',
            patientAge: 47,
            patientGender: 'Female',
            admissionDate: '04 Sep, 01:10 PM',
            primaryDiagnosis: 'Severe Diabetic Ketoacidosis',
          ),
          BedInfo(
            id: 'b_icu1_3',
            bedNumber: 'Bed ICU-03',
            isOccupied: true,
            patientName: 'Gurpreet Singh',
            patientAge: 55,
            patientGender: 'Male',
            admissionDate: '06 Sep, 06:00 AM',
            primaryDiagnosis: 'Post-CABG Hemodynamic Instability',
          ),
          BedInfo(
            id: 'b_icu1_4',
            bedNumber: 'Bed ICU-04',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_11',
            name: 'Mechanical Ventilator',
            model: 'Dräger Evita V800',
            category: 'Critical Respiratory Care',
            status: 'In Use',
            serialNumber: 'VT-DRG-5501',
            lastMaintenance: '03 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_12',
            name: 'Mechanical Ventilator',
            model: 'Hamilton-G5',
            category: 'Critical Respiratory Care',
            status: 'In Use',
            serialNumber: 'VT-HAM-9922',
            lastMaintenance: '01 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_13',
            name: 'Dialysis Machine (CRRT)',
            model: 'Fresenius multiFiltratePRO',
            category: 'Renal Replacement',
            status: 'Operational',
            serialNumber: 'DL-FRS-8833',
            lastMaintenance: '29 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_14',
            name: 'Multipara ECG Monitor',
            model: 'GE CARESCAPE B850',
            category: 'Multi-Parameter Monitoring',
            status: 'In Use',
            serialNumber: 'PM-GE-7721',
            lastMaintenance: '24 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_15',
            name: 'Syringe Infusion Pump',
            model: 'Fresenius Kabi Agilia',
            category: 'Infusion System',
            status: 'In Use',
            serialNumber: 'IP-FRS-6644',
            lastMaintenance: '18 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_icu_202',
        roomNumber: 'ICU Bay 2',
        roomName: 'Surgical & Trauma ICU',
        floor: '2nd Floor, Critical Care Block',
        departmentId: 'dept_icu',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_icu2_1',
            bedNumber: 'Bed ICU-05',
            isOccupied: true,
            patientName: 'Vikramjit Roy',
            patientAge: 38,
            patientGender: 'Male',
            admissionDate: '05 Sep, 11:45 PM',
            primaryDiagnosis: 'Polytrauma, Flail Chest',
          ),
          BedInfo(
            id: 'b_icu2_2',
            bedNumber: 'Bed ICU-06',
            isOccupied: false,
          ),
          BedInfo(
            id: 'b_icu2_3',
            bedNumber: 'Bed ICU-07',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_16',
            name: 'Mechanical Ventilator',
            model: 'Puritan Bennett 980',
            category: 'Critical Respiratory Care',
            status: 'In Use',
            serialNumber: 'VT-PB-1290',
            lastMaintenance: '27 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_17',
            name: 'Automated External Defibrillator',
            model: 'Zoll X Series Advanced',
            category: 'Emergency Resuscitation',
            status: 'Operational',
            serialNumber: 'DF-ZOLL-8839',
            lastMaintenance: '30 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_18',
            name: 'Portable Ultrasound Machine',
            model: 'Sonosite Edge II',
            category: 'POCUS Diagnostic',
            status: 'Operational',
            serialNumber: 'US-SNS-3310',
            lastMaintenance: '02 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_19',
            name: 'Mobile Suction Unit',
            model: 'Medela Dominant Flex',
            category: 'Suction Apparatus',
            status: 'Operational',
            serialNumber: 'SC-MDL-5521',
            lastMaintenance: '22 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_icu_203',
        roomNumber: 'ICU Isolation',
        roomName: 'Negative Pressure Isolation ICU',
        floor: '2nd Floor, Critical Care Block',
        departmentId: 'dept_icu',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(
            id: 'b_icu3_1',
            bedNumber: 'Bed ISO-01',
            isOccupied: true,
            patientName: 'Abdul Kareem',
            patientAge: 61,
            patientGender: 'Male',
            admissionDate: '03 Sep, 03:00 PM',
            primaryDiagnosis: 'Multidrug-Resistant Pneumonia with Type 2 Respiratory Failure',
          ),
          BedInfo(
            id: 'b_icu3_2',
            bedNumber: 'Bed ISO-02',
            isOccupied: false,
          ),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_20',
            name: 'Mechanical Ventilator',
            model: 'Hamilton-C3 Intelligent',
            category: 'Critical Respiratory Care',
            status: 'In Use',
            serialNumber: 'VT-HAM-2201',
            lastMaintenance: '04 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_21',
            name: 'BiPAP / Non-Invasive Ventilator',
            model: 'Philips Respironics V60 Plus',
            category: 'Non-Invasive Ventilation',
            status: 'Standby',
            serialNumber: 'BP-PHL-8822',
            lastMaintenance: '01 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_22',
            name: 'Multipara ECG Monitor',
            model: 'Philips IntelliVue MX550',
            category: 'Vital Monitoring',
            status: 'In Use',
            serialNumber: 'PM-PHL-4419',
            lastMaintenance: '28 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_23',
            name: 'Medical Oxygen Concentrator',
            model: 'AirSep NewLife Intensity 10',
            category: 'Oxygen Delivery',
            status: 'Operational',
            serialNumber: 'OX-AIR-7711',
            lastMaintenance: '26 Aug 2026',
          ),
        ],
      ),

      // ==================== ASHWINI CENTRAL HOSPITAL - GENERAL MEDICINE ====================
      RoomInfo(
        id: 'rm_gm_301',
        roomNumber: 'Room 301',
        roomName: 'Male Medical Inpatient Ward',
        floor: '3rd Floor, Medical Block',
        departmentId: 'dept_gen_med',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_gm1_1', bedNumber: 'Bed 301-A', isOccupied: true, patientName: 'Mohan Lal', patientAge: 51, patientGender: 'Male', admissionDate: '04 Sep', primaryDiagnosis: 'Type 2 DM with Foot Ulcer'),
          BedInfo(id: 'b_gm1_2', bedNumber: 'Bed 301-B', isOccupied: true, patientName: 'Sanjay Aggarwal', patientAge: 44, patientGender: 'Male', admissionDate: '05 Sep', primaryDiagnosis: 'Dengue with Thrombocytopenia'),
          BedInfo(id: 'b_gm1_3', bedNumber: 'Bed 301-C', isOccupied: false),
          BedInfo(id: 'b_gm1_4', bedNumber: 'Bed 301-D', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_24',
            name: 'Multipara ECG Monitor',
            model: 'Contec CMS8000',
            category: 'Vital Signs Monitor',
            status: 'Operational',
            serialNumber: 'PM-CNT-3301',
            lastMaintenance: '14 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_25',
            name: 'Infusion Pump',
            model: 'B. Braun Infusomat Space',
            category: 'Infusion System',
            status: 'In Use',
            serialNumber: 'IP-BRN-3319',
            lastMaintenance: '19 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_26',
            name: 'Mobile Suction Unit',
            model: 'Atmos Record 55',
            category: 'Suction Apparatus',
            status: 'Operational',
            serialNumber: 'SC-ATM-1102',
            lastMaintenance: '11 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_gm_302',
        roomNumber: 'Room 302',
        roomName: 'Female Medical Inpatient Ward',
        floor: '3rd Floor, Medical Block',
        departmentId: 'dept_gen_med',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_gm2_1', bedNumber: 'Bed 302-A', isOccupied: true, patientName: 'Kamla Devi', patientAge: 68, patientGender: 'Female', admissionDate: '02 Sep', primaryDiagnosis: 'Hypertensive Encephalopathy'),
          BedInfo(id: 'b_gm2_2', bedNumber: 'Bed 302-B', isOccupied: false),
          BedInfo(id: 'b_gm2_3', bedNumber: 'Bed 302-C', isOccupied: true, patientName: 'Pooja Bhatt', patientAge: 29, patientGender: 'Female', admissionDate: '06 Sep', primaryDiagnosis: 'Severe Acute Gastroenteritis'),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_27',
            name: 'Multipara ECG Monitor',
            model: 'Contec CMS8000',
            category: 'Vital Signs Monitor',
            status: 'Operational',
            serialNumber: 'PM-CNT-3302',
            lastMaintenance: '14 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_28',
            name: 'BiPAP / Non-Invasive Ventilator',
            model: 'ResMed Astral 150',
            category: 'Respiratory Therapy',
            status: 'Operational',
            serialNumber: 'BP-RSM-9021',
            lastMaintenance: '02 Sep 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_gm_303',
        roomNumber: 'Room 303',
        roomName: 'Private Medical Deluxe Room',
        floor: '3rd Floor, Medical Block',
        departmentId: 'dept_gen_med',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_gm3_1', bedNumber: 'Deluxe Bed 1', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_29',
            name: 'Multipara ECG Monitor',
            model: 'Philips Efficia CM100',
            category: 'Vital Signs Monitor',
            status: 'Operational',
            serialNumber: 'PM-PHL-9912',
            lastMaintenance: '20 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_30',
            name: 'Medical Oxygen Concentrator',
            model: 'Philips Respironics EverFlo',
            category: 'Oxygen Supply',
            status: 'Operational',
            serialNumber: 'OX-PHL-1104',
            lastMaintenance: '15 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_gm_304',
        roomNumber: 'Room 304',
        roomName: 'High Dependency Unit (HDU)',
        floor: '3rd Floor, Medical Block',
        departmentId: 'dept_gen_med',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_gm4_1', bedNumber: 'HDU Bed 1', isOccupied: true, patientName: 'Om Prakash', patientAge: 73, patientGender: 'Male', admissionDate: '01 Sep', primaryDiagnosis: 'CKD Stage V with Uremic Symptoms'),
          BedInfo(id: 'b_gm4_2', bedNumber: 'HDU Bed 2', isOccupied: true, patientName: 'Shanti Swaroop', patientAge: 65, patientGender: 'Male', admissionDate: '03 Sep', primaryDiagnosis: 'Severe Sepsis secondary to UTI'),
          BedInfo(id: 'b_gm4_3', bedNumber: 'HDU Bed 3', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_31',
            name: 'Dialysis Machine (Hemodialysis)',
            model: 'Nipro Surdial X',
            category: 'Renal Replacement',
            status: 'Operational',
            serialNumber: 'DL-NPR-4491',
            lastMaintenance: '01 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_32',
            name: 'Automated External Defibrillator',
            model: 'Mindray BeneHeart D3',
            category: 'Emergency Defibrillation',
            status: 'Operational',
            serialNumber: 'DF-MND-7712',
            lastMaintenance: '28 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_33',
            name: 'Multipara ECG Monitor',
            model: 'Mindray uMEC 12',
            category: 'Vital Signs',
            status: 'In Use',
            serialNumber: 'PM-MND-8833',
            lastMaintenance: '26 Aug 2026',
          ),
        ],
      ),

      // ==================== ASHWINI CENTRAL HOSPITAL - EMERGENCY ====================
      RoomInfo(
        id: 'rm_em_01',
        roomNumber: 'Triage & Resuscitation Bay',
        roomName: 'Red Zone Resus Room',
        floor: 'Ground Floor, Emergency Wing',
        departmentId: 'dept_emergency',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_em1_1', bedNumber: 'Resus Bed 1', isOccupied: true, patientName: 'Trauma Patient #402', patientAge: 32, patientGender: 'Male', admissionDate: 'Today, 06:10 PM', primaryDiagnosis: 'Head Injury, GCS 7'),
          BedInfo(id: 'b_em1_2', bedNumber: 'Resus Bed 2', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_34',
            name: 'Mechanical Ventilator',
            model: 'Hamilton-T1 Transport Ventilator',
            category: 'Emergency Transport Ventilation',
            status: 'In Use',
            serialNumber: 'VT-HAM-1099',
            lastMaintenance: '05 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_35',
            name: 'Automated External Defibrillator',
            model: 'Stryker LIFEPAK 15',
            category: 'Emergency Defibrillation',
            status: 'Operational',
            serialNumber: 'DF-STR-0012',
            lastMaintenance: '03 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_36',
            name: 'Portable Ultrasound Machine',
            model: 'GE Vscan Extend Handheld',
            category: 'Emergency FAST Ultrasound',
            status: 'Operational',
            serialNumber: 'US-GE-4421',
            lastMaintenance: '02 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_37',
            name: 'Portable X-Ray Unit',
            model: 'Siemens Mobilett Elara Max',
            category: 'Radiology Mobile',
            status: 'Operational',
            serialNumber: 'XR-SIE-7788',
            lastMaintenance: '30 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_em_02',
        roomNumber: 'Observation Bay A',
        roomName: 'Yellow Zone Observation Ward',
        floor: 'Ground Floor, Emergency Wing',
        departmentId: 'dept_emergency',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_em2_1', bedNumber: 'Obs Bed 1', isOccupied: true, patientName: 'Satish Narang', patientAge: 48, patientGender: 'Male', admissionDate: 'Today, 04:00 PM', primaryDiagnosis: 'Renal Colic with Hematuria'),
          BedInfo(id: 'b_em2_2', bedNumber: 'Obs Bed 2', isOccupied: true, patientName: 'Priya Chawla', patientAge: 26, patientGender: 'Female', admissionDate: 'Today, 05:20 PM', primaryDiagnosis: 'Acute Bronchospasm'),
          BedInfo(id: 'b_em2_3', bedNumber: 'Obs Bed 3', isOccupied: false),
          BedInfo(id: 'b_em2_4', bedNumber: 'Obs Bed 4', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_38',
            name: 'Multipara ECG Monitor',
            model: 'Mindray uMEC 10',
            category: 'Vital Signs',
            status: 'Operational',
            serialNumber: 'PM-MND-2211',
            lastMaintenance: '20 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_39',
            name: 'Mobile Suction Unit',
            model: 'Medela Basic Suction',
            category: 'Suction Apparatus',
            status: 'Operational',
            serialNumber: 'SC-MDL-8831',
            lastMaintenance: '18 Aug 2026',
          ),
        ],
      ),

      // ==================== ASHWINI CENTRAL HOSPITAL - PULMONOLOGY ====================
      RoomInfo(
        id: 'rm_pul_401',
        roomNumber: 'Room P-401',
        roomName: 'Respiratory Step-Down Room',
        floor: '4th Floor, Chest Clinic',
        departmentId: 'dept_pulmo',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_pul1_1', bedNumber: 'Bed P-01', isOccupied: true, patientName: 'Gurdas Mann', patientAge: 67, patientGender: 'Male', admissionDate: '03 Sep', primaryDiagnosis: 'COPD Acute Exacerbation'),
          BedInfo(id: 'b_pul1_2', bedNumber: 'Bed P-02', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_40',
            name: 'Mechanical Ventilator',
            model: 'Maquet SERVO-air',
            category: 'Respiratory Support',
            status: 'Operational',
            serialNumber: 'VT-MQT-3399',
            lastMaintenance: '29 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_41',
            name: 'BiPAP / Non-Invasive Ventilator',
            model: 'Philips Respironics Trilogy Evo',
            category: 'NIV Respiratory System',
            status: 'In Use',
            serialNumber: 'BP-PHL-5520',
            lastMaintenance: '01 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_42',
            name: 'High Flow Nasal Cannula (HFNC)',
            model: 'Fisher & Paykel AIRVO 2',
            category: 'High-Flow Oxygenation',
            status: 'In Use',
            serialNumber: 'HF-FNP-7712',
            lastMaintenance: '03 Sep 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_pul_402',
        roomNumber: 'Room P-402',
        roomName: 'Sleep & Pulmonary Diagnostics Suite',
        floor: '4th Floor, Chest Clinic',
        departmentId: 'dept_pulmo',
        hospitalId: 'hosp_1',
        beds: [
          BedInfo(id: 'b_pul2_1', bedNumber: 'Bed P-03', isOccupied: false),
          BedInfo(id: 'b_pul2_2', bedNumber: 'Bed P-04', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_43',
            name: 'Polysomnography Machine (Sleep Lab)',
            model: 'SomnoMedics SOMNOscreen Plus',
            category: 'Diagnostic Sleep Study',
            status: 'Operational',
            serialNumber: 'SL-SMM-1140',
            lastMaintenance: '15 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_44',
            name: 'Medical Oxygen Concentrator',
            model: 'Inogen One G5 High Output',
            category: 'Oxygen Therapy',
            status: 'Operational',
            serialNumber: 'OX-ING-9002',
            lastMaintenance: '10 Aug 2026',
          ),
        ],
      ),

      // ==================== AIIMS NEW DELHI - CARDIOLOGY ====================
      RoomInfo(
        id: 'rm_aiims_c1',
        roomNumber: 'Room AIIMS-101',
        roomName: 'Cardiac Care Unit (CCU 1)',
        floor: 'Ground Floor, CN Centre',
        departmentId: 'dept_cardio',
        hospitalId: 'hosp_2',
        beds: [
          BedInfo(id: 'b_ac1_1', bedNumber: 'CCU Bed 1', isOccupied: true, patientName: 'Deepak Chopra', patientAge: 59, patientGender: 'Male', admissionDate: '05 Sep', primaryDiagnosis: 'Cardiogenic Shock Post-STEMI'),
          BedInfo(id: 'b_ac1_2', bedNumber: 'CCU Bed 2', isOccupied: true, patientName: 'Nalini Sengupta', patientAge: 70, patientGender: 'Female', admissionDate: '06 Sep', primaryDiagnosis: 'Severe Mitral Regurgitation'),
          BedInfo(id: 'b_ac1_3', bedNumber: 'CCU Bed 3', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_50',
            name: 'Mechanical Ventilator',
            model: 'Dräger Babylog VN800',
            category: 'Advanced Ventilation',
            status: 'Operational',
            serialNumber: 'VT-DRG-9901',
            lastMaintenance: '02 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_51',
            name: 'Intra-Aortic Balloon Pump (IABP)',
            model: 'Datascope CS300',
            category: 'Hemodynamic Support',
            status: 'In Use',
            serialNumber: 'IABP-DSC-1100',
            lastMaintenance: '04 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_52',
            name: 'Automated External Defibrillator',
            model: 'Philips HeartStart MRx',
            category: 'Defibrillator',
            status: 'Operational',
            serialNumber: 'DF-PHL-3341',
            lastMaintenance: '01 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_53',
            name: 'Multipara ECG Monitor',
            model: 'Philips IntelliVue MX800',
            category: 'Cardiac Monitoring',
            status: 'In Use',
            serialNumber: 'PM-PHL-1209',
            lastMaintenance: '28 Aug 2026',
          ),
        ],
      ),

      RoomInfo(
        id: 'rm_aiims_c2',
        roomNumber: 'Room AIIMS-102',
        roomName: 'Cardiac Post-Op Recovery',
        floor: 'Ground Floor, CN Centre',
        departmentId: 'dept_cardio',
        hospitalId: 'hosp_2',
        beds: [
          BedInfo(id: 'b_ac2_1', bedNumber: 'Post-Op 1', isOccupied: true, patientName: 'Balwant Rai', patientAge: 66, patientGender: 'Male', admissionDate: '04 Sep', primaryDiagnosis: 'Aortic Valve Replacement'),
          BedInfo(id: 'b_ac2_2', bedNumber: 'Post-Op 2', isOccupied: false),
          BedInfo(id: 'b_ac2_3', bedNumber: 'Post-Op 3', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_54',
            name: 'ECG Monitor & Telemetry',
            model: 'GE ApexPro CH Telemetry',
            category: 'Telemetry',
            status: 'Operational',
            serialNumber: 'TL-GE-7788',
            lastMaintenance: '25 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_55',
            name: 'Syringe Infusion Pump',
            model: 'Alaris CC Plus Guardrails',
            category: 'Infusion System',
            status: 'In Use',
            serialNumber: 'IP-ALR-4411',
            lastMaintenance: '20 Aug 2026',
          ),
        ],
      ),

      // ==================== AIIMS NEW DELHI - ICU ====================
      RoomInfo(
        id: 'rm_aiims_icu1',
        roomNumber: 'AIIMS Main ICU-A',
        roomName: 'Medical Intensive Care Unit',
        floor: '1st Floor, Main Hospital',
        departmentId: 'dept_icu',
        hospitalId: 'hosp_2',
        beds: [
          BedInfo(id: 'b_aicu_1', bedNumber: 'Bed 1', isOccupied: true, patientName: 'Chanchal Goyal', patientAge: 55, patientGender: 'Female', admissionDate: '03 Sep', primaryDiagnosis: 'Severe Sepsis'),
          BedInfo(id: 'b_aicu_2', bedNumber: 'Bed 2', isOccupied: true, patientName: 'Tanmay Bannerjee', patientAge: 49, patientGender: 'Male', admissionDate: '05 Sep', primaryDiagnosis: 'Acute Pancreatitis Necrotizing'),
          BedInfo(id: 'b_aicu_3', bedNumber: 'Bed 3', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_56',
            name: 'Mechanical Ventilator',
            model: 'Getinge SERVO-u',
            category: 'Critical Respiratory Care',
            status: 'In Use',
            serialNumber: 'VT-GTG-6621',
            lastMaintenance: '03 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_57',
            name: 'Dialysis Machine (CRRT)',
            model: 'Baxter Prismaflex System',
            category: 'Renal Replacement',
            status: 'In Use',
            serialNumber: 'DL-BXT-3321',
            lastMaintenance: '02 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_58',
            name: 'Automated External Defibrillator',
            model: 'Zoll R Series Plus',
            category: 'Emergency Defibrillation',
            status: 'Operational',
            serialNumber: 'DF-ZOLL-9910',
            lastMaintenance: '01 Sep 2026',
          ),
        ],
      ),

      // ==================== METRO HEALTHCARE OPD - GENERAL MEDICINE ====================
      RoomInfo(
        id: 'rm_metro_gm1',
        roomNumber: 'Day-Care Room 1',
        roomName: 'Clinical Infusion & Observation Bay',
        floor: 'Ground Floor',
        departmentId: 'dept_gen_med',
        hospitalId: 'hosp_3',
        beds: [
          BedInfo(id: 'b_mg1_1', bedNumber: 'Day Bed 1', isOccupied: true, patientName: 'Rohit Khandelwal', patientAge: 35, patientGender: 'Male', admissionDate: 'Today, 10:00 AM', primaryDiagnosis: 'Iron Deficiency Infusion'),
          BedInfo(id: 'b_mg1_2', bedNumber: 'Day Bed 2', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_60',
            name: 'Multipara ECG Monitor',
            model: 'Bionet BM3 Pro',
            category: 'Vital Signs',
            status: 'Operational',
            serialNumber: 'PM-BIO-1122',
            lastMaintenance: '12 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_61',
            name: 'Infusion Pump',
            model: 'Terumo TE-171',
            category: 'Infusion System',
            status: 'In Use',
            serialNumber: 'IP-TRM-8833',
            lastMaintenance: '14 Aug 2026',
          ),
        ],
      ),

      // ==================== APOLLO MULTI-SPECIALITY - ICU ====================
      RoomInfo(
        id: 'rm_apollo_icu1',
        roomNumber: 'Apollo ICU Unit 1',
        roomName: 'Cardio-Vascular ICU Bay',
        floor: '3rd Floor, Apollo Wing A',
        departmentId: 'dept_icu',
        hospitalId: 'hosp_4',
        beds: [
          BedInfo(id: 'b_ap1_1', bedNumber: 'Bed A-1', isOccupied: true, patientName: 'Subhash Chandra', patientAge: 63, patientGender: 'Male', admissionDate: '04 Sep', primaryDiagnosis: 'Aortic Dissection Type B'),
          BedInfo(id: 'b_ap1_2', bedNumber: 'Bed A-2', isOccupied: false),
          BedInfo(id: 'b_ap1_3', bedNumber: 'Bed A-3', isOccupied: true, patientName: 'Rekha Deshmukh', patientAge: 58, patientGender: 'Female', admissionDate: '06 Sep', primaryDiagnosis: 'Post-Mitral Valvuloplasty'),
          BedInfo(id: 'b_ap1_4', bedNumber: 'Bed A-4', isOccupied: false),
        ],
        equipments: [
          EquipmentInfo(
            id: 'eq_70',
            name: 'Mechanical Ventilator',
            model: 'Hamilton-G5',
            category: 'Critical Respiratory Care',
            status: 'In Use',
            serialNumber: 'VT-HAM-5544',
            lastMaintenance: '02 Sep 2026',
          ),
          EquipmentInfo(
            id: 'eq_71',
            name: 'Automated External Defibrillator',
            model: 'Philips HeartStart XL+',
            category: 'Emergency Defibrillation',
            status: 'Operational',
            serialNumber: 'DF-PHL-7721',
            lastMaintenance: '29 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_72',
            name: 'Dialysis Machine (CRRT)',
            model: 'Fresenius 5008S CorDiax',
            category: 'Hemodialysis System',
            status: 'Operational',
            serialNumber: 'DL-FRS-9922',
            lastMaintenance: '30 Aug 2026',
          ),
          EquipmentInfo(
            id: 'eq_73',
            name: 'Portable X-Ray Unit',
            model: 'Shimadzu MobileDaRt Evolution',
            category: 'Mobile Diagnostic Imaging',
            status: 'Operational',
            serialNumber: 'XR-SHM-4401',
            lastMaintenance: '01 Sep 2026',
          ),
        ],
      ),
    ];
  }
}
