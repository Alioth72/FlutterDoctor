import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../providers/health_profile_provider.dart';
import '../services/patient_database_service.dart';
import '../screens/leaflet_map_picker_screen.dart';
import '../theme/app_colors.dart';

class LocationSelectionSheet extends StatefulWidget {
  const LocationSelectionSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationSelectionSheet(),
    );
  }

  @override
  State<LocationSelectionSheet> createState() => _LocationSelectionSheetState();
}

class _LocationSelectionSheetState extends State<LocationSelectionSheet> {
  final _searchController = TextEditingController();
  List<String> _filteredLocations = [];
  bool _isDetectingGps = false;

  @override
  void initState() {
    super.initState();
    _filteredLocations = List.from(PatientDatabaseService.availableLocations);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = List.from(PatientDatabaseService.availableLocations);
      } else {
        _filteredLocations = PatientDatabaseService.availableLocations
            .where((loc) => loc.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  void _selectLocation(String location) {
    final provider = Provider.of<HealthProfileProvider>(context, listen: false);
    provider.updateLocation(location);
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text('Location set to: $location')),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF7C3AED),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Open full Leaflet map picker
  Future<void> _openLeafletMapPicker() async {
    final provider = Provider.of<HealthProfileProvider>(context, listen: false);
    final selectedLocation = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => LeafletMapPickerScreen(
          initialLocationName: provider.currentLocation,
        ),
      ),
    );

    if (selectedLocation != null && selectedLocation.trim().isNotEmpty && mounted) {
      _selectLocation(selectedLocation.trim());
    }
  }

  /// Acquire phone's live GPS position and reverse-geocode to exact Indian location
  Future<void> _detectAndSetLiveGps() async {
    setState(() => _isDetectingGps = true);

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _isDetectingGps = false);
        _showGpsSettingsDialog();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() => _isDetectingGps = false);
          _showToast('Location permission denied. Please allow location access to use live GPS.', isError: true);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _isDetectingGps = false);
        _showPermissionSettingsDialog();
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      // Reverse geocode via OpenStreetMap Nominatim
      String resolved = 'Live GPS (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})';

      try {
        final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        );
        final response = await http.get(
          url,
          headers: {'User-Agent': 'AshwiniHealthcarePatientApp/1.0 (dtu_sih_project)'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? '';
            final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? '';
            final state = address['state'] ?? '';
            final postcode = address['postcode'] ?? '';

            final List<String> parts = [];
            if (road.toString().isNotEmpty) parts.add(road.toString());
            if (city.toString().isNotEmpty) parts.add(city.toString());
            if (state.toString().isNotEmpty) parts.add(state.toString());
            if (postcode.toString().isNotEmpty) parts.add(postcode.toString());

            if (parts.isNotEmpty) {
              resolved = parts.join(', ');
            } else if (data['display_name'] != null) {
              resolved = data['display_name'].toString();
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() => _isDetectingGps = false);
        _selectLocation(resolved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDetectingGps = false);
        _showToast('Could not fetch phone GPS location. Please try the Leaflet Map.', isError: true);
      }
    }
  }

  void _showGpsSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Turn On Location (GPS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Location services are turned off on your device. Please enable GPS in device settings to detect your current position.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text('Device Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Location Permission Needed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Location permission is permanently denied for ASHWINI app. Please allow location permissions in device settings to detect your live location.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text('App Settings'),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF7C3AED),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HealthProfileProvider>(context);
    final currentLocation = provider.currentLocation;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF7C3AED),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Location',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Interactive Leaflet Map • Live Mobile GPS • Indian Cities',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // TWO PROMINENT ACTION BUTTONS: LEAFLET MAP & LIVE MOBILE GPS
          Row(
            children: [
              // 1. Leaflet Interactive Map Card
              Expanded(
                child: InkWell(
                  onTap: _openLeafletMapPicker,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Icon(Icons.map_rounded, color: Colors.white, size: 24),
                            Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: 16),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Leaflet Map',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Navigate & click in India',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // 2. Live Mobile Phone GPS Button
              Expanded(
                child: InkWell(
                  onTap: _isDetectingGps ? null : _detectAndSetLiveGps,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFDDD6FE), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_isDetectingGps)
                              const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF7C3AED)),
                              )
                            else
                              const Icon(Icons.my_location_rounded, color: Color(0xFF7C3AED), size: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: const Text(
                                'GPS',
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _isDetectingGps ? 'Locating...' : 'Live GPS',
                          style: const TextStyle(
                            color: Color(0xFF1E1B4B),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Phone location sensor',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
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
          const SizedBox(height: 18),

          // Divider with "OR SEARCH CITIES"
          Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR SELECT CITY IN INDIA',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: Color(0xFFE2E8F0))),
            ],
          ),
          const SizedBox(height: 14),

          // Search / Custom Input
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search city, district, or custom place...',
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7C3AED)),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    ),
                  IconButton(
                    tooltip: 'Pick on Leaflet Map',
                    icon: const Icon(Icons.map_outlined, color: Color(0xFF7C3AED), size: 20),
                    onPressed: _openLeafletMapPicker,
                  ),
                ],
              ),
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Custom location entry option if query doesn't match list
          if (_searchController.text.trim().isNotEmpty &&
              !PatientDatabaseService.availableLocations
                  .map((e) => e.toLowerCase())
                  .contains(_searchController.text.trim().toLowerCase())) ...[
            InkWell(
              onTap: () => _selectLocation(_searchController.text.trim()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_location_alt_rounded, color: Color(0xFF7C3AED), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Set custom: "${_searchController.text.trim()}"',
                        style: const TextStyle(
                          color: Color(0xFF4C1D95),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF7C3AED)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Locations List
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 230),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              itemCount: _filteredLocations.length,
              separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, index) {
                final loc = _filteredLocations[index];
                final isSelected = loc == currentLocation;

                return InkWell(
                  onTap: () => _selectLocation(loc),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: isSelected ? const Color(0xFF7C3AED) : AppColors.muted,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            loc,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF4C1D95) : AppColors.darkText,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ACTIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7C3AED),
                              ),
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
