import 'package:flutter/material.dart';
import '../models/room_machine_models.dart';
import '../theme/app_colors.dart';
import '../services/api_client.dart';

class MachineRecordsScreen extends StatefulWidget {
  const MachineRecordsScreen({super.key});

  @override
  State<MachineRecordsScreen> createState() => _MachineRecordsScreenState();
}

class _MachineRecordsScreenState extends State<MachineRecordsScreen> {
  late List<DoctorHospital> _doctorHospitals;
  late List<RoomInfo> _allRooms;

  late DoctorHospital _selectedHospital;
  late HospitalDepartment _selectedDepartment;

  final TextEditingController _searchController = TextEditingController();
  String _equipmentSearchQuery = '';
  bool _searchAcrossAllDepartments = false;

  final List<String> _quickEquipmentFilters = [
    'All',
    'Ventilator',
    'ECG Monitor',
    'Defibrillator',
    'Dialysis',
    'Infusion Pump',
    'BiPAP',
    'Ultrasound',
    'X-Ray',
    'Oxygen Concentrator',
    'Suction',
  ];
  String _selectedQuickFilter = 'All';

  @override
  void initState() {
    super.initState();
    _doctorHospitals = RoomMachineRepository.getDoctorHospitals();
    _allRooms = RoomMachineRepository.getAllRooms();

    _selectedHospital = _doctorHospitals.first;
    _selectedDepartment = _selectedHospital.departments.first;
    _loadLiveMachines();
  }

  Future<void> _loadLiveMachines() async {
    try {
      final liveMachines = await ApiClient.getMachines();
      if (liveMachines.isNotEmpty && mounted) {
        setState(() {
          for (final room in _allRooms) {
            for (final live in liveMachines) {
              if (!room.equipments.any((e) => e.serialNumber == live.serialNumber)) {
                room.equipments.insert(0, live);
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onHospitalChanged(DoctorHospital hospital) {
    setState(() {
      _selectedHospital = hospital;
      if (!hospital.departments.any((d) => d.id == _selectedDepartment.id)) {
        _selectedDepartment = hospital.departments.first;
      }
    });
  }

  void _onDepartmentChanged(HospitalDepartment department) {
    setState(() {
      _selectedDepartment = department;
    });
  }

  void _onSearchQueryChanged(String query) {
    setState(() {
      _equipmentSearchQuery = query;
      if (query.isEmpty) {
        _selectedQuickFilter = 'All';
      } else {
        final match = _quickEquipmentFilters.firstWhere(
          (filter) => filter.toLowerCase() == query.toLowerCase(),
          orElse: () => '',
        );
        _selectedQuickFilter = match.isNotEmpty ? match : '';
      }
    });
  }

  void _applyQuickFilter(String filter) {
    setState(() {
      _selectedQuickFilter = filter;
      if (filter == 'All') {
        _equipmentSearchQuery = '';
        _searchController.clear();
      } else {
        _equipmentSearchQuery = filter;
        _searchController.text = filter;
      }
    });
  }

  List<RoomInfo> get _filteredRooms {
    final query = _equipmentSearchQuery.trim();

    return _allRooms.where((room) {
      final matchesHospital = room.hospitalId == _selectedHospital.id;
      if (!matchesHospital) return false;

      final matchesDepartment = _searchAcrossAllDepartments ||
          room.departmentId == _selectedDepartment.id;
      if (!matchesDepartment) return false;

      if (query.isNotEmpty) {
        return room.hasEquipment(query);
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayedRooms = _filteredRooms;
    final totalBedsInScope = displayedRooms.fold<int>(0, (sum, r) => sum + r.totalBeds);
    final occupiedBedsInScope = displayedRooms.fold<int>(0, (sum, r) => sum + r.occupiedBeds);
    final availableBedsInScope = displayedRooms.fold<int>(0, (sum, r) => sum + r.availableBeds);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available Rooms & Machines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              'Bed Availability & Equipment Records',
              style: TextStyle(fontSize: 12, color: AppColors.primaryLight),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Top Controls: Hospital & Department Selectors
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHospitalSelector(),
                  const SizedBox(height: 14),
                  _buildDepartmentChips(),
                  const SizedBox(height: 14),
                  _buildEquipmentSearchBar(),
                  const SizedBox(height: 10),
                  _buildQuickFilterChips(),
                  const SizedBox(height: 14),
                  _buildStatsSummaryCard(
                    totalRooms: displayedRooms.length,
                    totalBeds: totalBedsInScope,
                    occupiedBeds: occupiedBedsInScope,
                    availableBeds: availableBedsInScope,
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader(displayedRooms.length),
                ],
              ),
            ),
          ),

          // Rooms Grid (Small Boxes)
          if (displayedRooms.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.88,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final room = displayedRooms[index];
                    return _buildRoomBox(room);
                  },
                  childCount: displayedRooms.length,
                ),
              ),
            ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 30),
          ),
        ],
      ),
    );
  }

  /// Hospital Selector Widget
  Widget _buildHospitalSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_hospital_rounded, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'YOUR PRACTICING HOSPITAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<DoctorHospital>(
              value: _selectedHospital,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
              items: _doctorHospitals.map((hospital) {
                return DropdownMenuItem<DoctorHospital>(
                  value: hospital,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        hospital.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${hospital.branch} • ${hospital.address}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (newHospital) {
                if (newHospital != null) {
                  _onHospitalChanged(newHospital);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Department Selection Chips
  Widget _buildDepartmentChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Department',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedHospital.departments.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final dept = _selectedHospital.departments[index];
              final isSelected = dept.id == _selectedDepartment.id;

              return InkWell(
                onTap: () => _onDepartmentChanged(dept),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        dept.icon,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.bodyText,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dept.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.bodyText,
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
    );
  }

  /// Equipment Search Bar
  Widget _buildEquipmentSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _equipmentSearchQuery.isNotEmpty ? AppColors.primary : AppColors.border,
          width: _equipmentSearchQuery.isNotEmpty ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchQueryChanged,
        decoration: InputDecoration(
          hintText: 'Search equipment (e.g., Ventilator, ECG, Dialysis...)',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
          suffixIcon: _equipmentSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: AppColors.muted, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchQueryChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  /// Quick Filter Chips for Equipment
  Widget _buildQuickFilterChips() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _quickEquipmentFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final filter = _quickEquipmentFilters[index];
          final isSelected = _selectedQuickFilter == filter;

          return InkWell(
            onTap: () => _applyQuickFilter(filter),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppColors.primaryDark : AppColors.muted,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Stats Summary Card
  Widget _buildStatsSummaryCard({
    required int totalRooms,
    required int totalBeds,
    required int occupiedBeds,
    required int availableBeds,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryItem(
              title: 'Total Rooms',
              value: '$totalRooms',
              icon: Icons.meeting_room_rounded,
              color: AppColors.primary,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: _buildSummaryItem(
              title: 'Occupied Beds',
              value: '$occupiedBeds',
              icon: Icons.bed_rounded,
              color: AppColors.danger,
              badgeBg: AppColors.dangerBg,
            ),
          ),
          Container(width: 1, height: 36, color: AppColors.divider),
          Expanded(
            child: _buildSummaryItem(
              title: 'Available Beds',
              value: '$availableBeds',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.success,
              badgeBg: AppColors.successBg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    Color? badgeBg,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Section Header with Search Across Departments Toggle
  Widget _buildSectionHeader(int roomCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              _searchAcrossAllDepartments
                  ? 'All Rooms in Hospital ($roomCount)'
                  : '${_selectedDepartment.name} Rooms ($roomCount)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.headingText,
              ),
            ),
          ],
        ),
        if (_equipmentSearchQuery.isNotEmpty)
          InkWell(
            onTap: () {
              setState(() {
                _searchAcrossAllDepartments = !_searchAcrossAllDepartments;
              });
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    _searchAcrossAllDepartments
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'All Depts',
                    style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Small Room Box Widget (Grid item)
  Widget _buildRoomBox(RoomInfo room) {
    final matchingEquipments = _equipmentSearchQuery.isEmpty
        ? room.equipments
        : room.equipments
            .where((e) =>
                e.name.toLowerCase().contains(_equipmentSearchQuery.toLowerCase()) ||
                e.category.toLowerCase().contains(_equipmentSearchQuery.toLowerCase()))
            .toList();

    return InkWell(
      onTap: () => _showRoomDetailsModal(room),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _equipmentSearchQuery.isNotEmpty && matchingEquipments.isNotEmpty
                ? AppColors.primary
                : AppColors.border,
            width: _equipmentSearchQuery.isNotEmpty && matchingEquipments.isNotEmpty ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Room Number & Bed Ratio Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    room.roomNumber,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headingText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: room.availableBeds > 0 ? AppColors.successBg : AppColors.dangerBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${room.occupiedBeds}/${room.totalBeds} Occ',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: room.availableBeds > 0 ? AppColors.successText : AppColors.dangerText,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 2),
            Text(
              room.roomName,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 6),

            // Mini Bed Status Indicator Dots/Boxes
            // Red = Occupied, Green = Unoccupied
            Row(
              children: [
                const Text(
                  'Beds: ',
                  style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: room.beds.map((bed) {
                      return Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: bed.isOccupied ? AppColors.danger : AppColors.success,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Equipment Info Section
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.precision_manufacturing_outlined, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${room.equipments.length} Equipments',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    room.equipments.map((e) => e.name).take(2).join(', '),
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.bodyText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_equipmentSearchQuery.isNotEmpty && matchingEquipments.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Matches: ${matchingEquipments.first.name}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 4),
            const Center(
              child: Text(
                'Tap for details →',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Empty State for Search or Empty Department
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _equipmentSearchQuery.isNotEmpty
                  ? 'No Rooms Found with "$_equipmentSearchQuery"'
                  : 'No Rooms in this Department',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.headingText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              _equipmentSearchQuery.isNotEmpty
                  ? 'Try searching across all departments in this hospital or clearing the equipment filter.'
                  : 'There are no active room records currently mapped to ${_selectedDepartment.name}.',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (_equipmentSearchQuery.isNotEmpty && !_searchAcrossAllDepartments)
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchAcrossAllDepartments = true;
                  });
                },
                icon: const Icon(Icons.domain_rounded, size: 16),
                label: const Text('Search Across All Hospital Departments'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            if (_equipmentSearchQuery.isNotEmpty)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  _onSearchQueryChanged('');
                },
                child: const Text('Clear Search Filter'),
              ),
          ],
        ),
      ),
    );
  }

  /// Interactive Room Details Modal / Bottom Sheet
  /// Demonstrates:
  /// - Number of beds & occupied beds
  /// - Occupied beds shown with a RED color box
  /// - Unoccupied beds shown with a GREEN color box
  /// - Tapping a green bed allows assigning a patient
  /// - Names of equipments available in that room
  void _showRoomDetailsModal(RoomInfo room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.meeting_room_rounded, color: AppColors.primary, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    room.roomNumber,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.headingText,
                                    ),
                                  ),
                                  Text(
                                    '${room.roomName} • ${room.floor}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1),

                      // Content list
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(18),
                          children: [
                            // Bed Statistics Card
                            _buildRoomBedStatsCard(room),

                            const SizedBox(height: 20),

                            // BED VISUALIZATION SECTION
                            // Occupied Beds = RED color box
                            // Unoccupied Beds = GREEN color box (Clickable to Assign)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Bed Occupancy Layout',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.headingText,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildLegendIndicator('Occupied', AppColors.danger),
                                    const SizedBox(width: 12),
                                    _buildLegendIndicator('Available', AppColors.success),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '💡 Tap any green bed to assign a patient',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Bed boxes grid (Interactive)
                            _buildBedBoxesGrid(room, setModalState),

                            const SizedBox(height: 24),

                            // AVAILABLE EQUIPMENTS SECTION
                            Row(
                              children: [
                                const Icon(Icons.precision_manufacturing_rounded, size: 18, color: AppColors.primary),
                                const SizedBox(width: 6),
                                Text(
                                  'Equipments in this Room (${room.equipments.length})',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.headingText,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            ...room.equipments.map((equipment) => _buildEquipmentDetailCard(equipment)),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// Room Bed Stats Card inside modal
  Widget _buildRoomBedStatsCard(RoomInfo room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModalStat(
                label: 'Total Beds',
                value: '${room.totalBeds}',
                color: AppColors.headingText,
              ),
              Container(width: 1, height: 32, color: AppColors.divider),
              _buildModalStat(
                label: 'Occupied Beds',
                value: '${room.occupiedBeds}',
                color: AppColors.danger,
              ),
              Container(width: 1, height: 32, color: AppColors.divider),
              _buildModalStat(
                label: 'Available Beds',
                value: '${room.availableBeds}',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: room.totalBeds > 0 ? room.occupiedBeds / room.totalBeds : 0,
              backgroundColor: AppColors.successBg,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.danger),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Occupancy: ${room.totalBeds > 0 ? ((room.occupiedBeds / room.totalBeds) * 100).toInt() : 0}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted),
              ),
              Text(
                room.availableBeds > 0 ? '${room.availableBeds} bed(s) ready for admission' : 'Room is fully occupied',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: room.availableBeds > 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModalStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  /// Bed Boxes Grid
  /// Occupied beds = RED color box
  /// Unoccupied beds = GREEN color box (Clickable to Assign Patient)
  Widget _buildBedBoxesGrid(RoomInfo room, StateSetter setModalState) {
    final beds = room.beds;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.12,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: beds.length,
      itemBuilder: (context, index) {
        final bed = beds[index];
        final isOccupied = bed.isOccupied;

        // Occupied: RED box | Unoccupied: GREEN box
        final boxColor = isOccupied ? AppColors.danger : AppColors.success;
        final lightBg = isOccupied ? AppColors.dangerBg : AppColors.successBg;

        return InkWell(
          onTap: () {
            if (!isOccupied) {
              _showAssignBedDialog(room, bed, setModalState);
            } else {
              _showOccupiedBedDetailsDialog(room, bed, setModalState);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: lightBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: boxColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: boxColor.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bed Header Row: Icon, Bed Number & Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: boxColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.bed_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bed.bedNumber,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: boxColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Status Tag inside the colored box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: boxColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOccupied ? 'OCCUPIED' : 'UNOCCUPIED',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                const Spacer(),

                // Patient details or Interactive Vacant Prompt
                if (isOccupied) ...[
                  Text(
                    bed.patientName ?? 'Admitted Patient',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headingText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (bed.primaryDiagnosis != null)
                    Text(
                      bed.primaryDiagnosis!,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.bodyText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ] else ...[
                  const Text(
                    'Vacant & Ready',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Assign Bed',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dialog to assign an unoccupied (green) bed to a person
  void _showAssignBedDialog(RoomInfo room, BedInfo bed, StateSetter setModalState) {
    final nameController = TextEditingController();
    final ageController = TextEditingController(text: '42');
    final diagController = TextEditingController();
    String selectedGender = 'Male';
    String admissionPriority = 'Standard Admission';

    final queuePatients = [
      {'name': 'Aarav Sharma', 'age': '42', 'gender': 'Male', 'diag': 'Acute Bronchitis with Dyspnea'},
      {'name': 'Pooja Verma', 'age': '29', 'gender': 'Female', 'diag': 'Severe Dengue with Thrombocytopenia'},
      {'name': 'Mohit Sen', 'age': '61', 'gender': 'Male', 'diag': 'Unstable Angina / Chest Pain'},
      {'name': 'Ananya Iyer', 'age': '35', 'gender': 'Female', 'diag': 'Post-Operative Observation'},
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success, width: 1.5),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.success, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign ${bed.bedNumber}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                        ),
                        Text(
                          '${room.roomNumber} • ${room.roomName}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.88,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick select chips from OPD queue
                      const Text(
                        'Select from OPD Waiting Queue:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: queuePatients.map((qp) {
                          final isCurrent = nameController.text == qp['name'];
                          return InkWell(
                            onTap: () {
                              setDialogState(() {
                                nameController.text = qp['name']!;
                                ageController.text = qp['age']!;
                                selectedGender = qp['gender']!;
                                diagController.text = qp['diag']!;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCurrent ? AppColors.primaryLight : AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCurrent ? AppColors.primary : AppColors.border,
                                ),
                              ),
                              child: Text(
                                '${qp['name']} (${qp['age']}/${qp['gender']![0]})',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                  color: isCurrent ? AppColors.primaryDark : AppColors.bodyText,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // Patient Name
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Patient Full Name *',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                          prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Age & Gender Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ageController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Age *',
                                labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                                filled: true,
                                fillColor: AppColors.background,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedGender,
                                  isExpanded: true,
                                  items: ['Male', 'Female', 'Other'].map((g) {
                                    return DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDialogState(() => selectedGender = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Primary Diagnosis / Reason for Admission
                      TextField(
                        controller: diagController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Primary Diagnosis / Admission Reason *',
                          labelStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                          prefixIcon: const Icon(Icons.medical_services_outlined, size: 20, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.background,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Priority Selection
                      Row(
                        children: [
                          const Text('Priority: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted)),
                          const SizedBox(width: 6),
                          ...['Standard Admission', 'Urgent'].map((pri) {
                            final isSel = admissionPriority == pri;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(pri, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.bodyText)),
                                selected: isSel,
                                selectedColor: pri == 'Urgent' ? AppColors.danger : AppColors.primary,
                                onSelected: (selected) {
                                  if (selected) {
                                    setDialogState(() => admissionPriority = pri);
                                  }
                                },
                              ),
                            );
                          }),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Attending Doctor info badge
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 16, color: AppColors.primary),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Admitting Physician: Dr. Rajesh V. Sharma (Senior Consultant)',
                                style: TextStyle(fontSize: 10.5, color: AppColors.primaryDark, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final diag = diagController.text.trim();
                    final age = int.tryParse(ageController.text.trim()) ?? 40;

                    if (name.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter patient name'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }
                    if (diag.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter primary diagnosis'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }

                    // Assign bed
                    bed.assign(
                      name: name,
                      age: age,
                      gender: selectedGender,
                      diagnosis: diag,
                    );

                    Navigator.pop(dialogContext);

                    // Update modal bottom sheet state (turns bed RED immediately)
                    setModalState(() {});

                    // Update main screen state (updates room card count and top stats immediately)
                    setState(() {});

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${bed.bedNumber} in ${room.roomNumber} assigned to $name.'),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Confirm & Assign Bed'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Dialog when doctor taps an occupied (red) bed: shows patient details & allows vacating/discharging
  void _showOccupiedBedDetailsDialog(RoomInfo room, BedInfo bed, StateSetter setModalState) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger, width: 1.5),
                ),
                child: const Icon(Icons.bed_rounded, color: AppColors.danger, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bed.bedNumber} (Occupied)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.headingText),
                    ),
                    Text(
                      '${room.roomNumber} • ${room.roomName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          bed.patientName ?? 'Admitted Patient',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.headingText),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OCCUPIED',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${bed.patientAge ?? 45} Yrs • ${bed.patientGender ?? 'Not Specified'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const Divider(height: 16),
                    const Text('Diagnosis:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.muted)),
                    Text(
                      bed.primaryDiagnosis ?? 'Acute Condition',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingText),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded, size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(
                          'Admitted: ${bed.admissionDate ?? 'Recent'}',
                          style: const TextStyle(fontSize: 11, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            OutlinedButton.icon(
              onPressed: () {
                bed.vacate();
                Navigator.pop(dialogContext);

                // Update bottom sheet and parent
                setModalState(() {});
                setState(() {});

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${bed.bedNumber} in ${room.roomNumber} has been vacated and is now available.'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
              label: const Text('Discharge / Vacate Bed', style: TextStyle(color: AppColors.danger)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Individual Equipment Card
  Widget _buildEquipmentDetailCard(EquipmentInfo equipment) {
    Color statusColor;
    Color statusBg;
    switch (equipment.status.toLowerCase()) {
      case 'in use':
        statusColor = AppColors.warning;
        statusBg = AppColors.warningBg;
        break;
      case 'operational':
        statusColor = AppColors.success;
        statusBg = AppColors.successBg;
        break;
      default:
        statusColor = AppColors.info;
        statusBg = AppColors.infoBg;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.precision_manufacturing_rounded,
              color: AppColors.primary,
              size: 22,
            ),
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
                        equipment.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.headingText,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        equipment.status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${equipment.model} • ${equipment.category}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      'S/N: ${equipment.serialNumber}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.build_circle_outlined, size: 12, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Text(
                      'Serviced: ${equipment.lastMaintenance}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
