import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/app_colors.dart';

class LeafletMapPickerScreen extends StatefulWidget {
  final String? initialLocationName;
  final LatLng? initialCenter;

  const LeafletMapPickerScreen({
    super.key,
    this.initialLocationName,
    this.initialCenter,
  });

  @override
  State<LeafletMapPickerScreen> createState() => _LeafletMapPickerScreenState();
}

class _LeafletMapPickerScreenState extends State<LeafletMapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  // Default initial center: New Delhi, India
  static const LatLng _defaultIndiaCenter = LatLng(28.6139, 77.2090);

  LatLng _currentMapCenter = _defaultIndiaCenter;
  LatLng? _selectedPoint;
  String _resolvedAddress = '';
  String _resolvedCity = '';
  bool _isGeocoding = false;
  bool _isGpsLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  // Popular Quick-Jump Hubs in India
  final List<Map<String, dynamic>> _quickHubs = [
    {'name': 'Delhi NCR', 'coord': const LatLng(28.6139, 77.2090)},
    {'name': 'Mumbai', 'coord': const LatLng(19.0760, 72.8777)},
    {'name': 'Bengaluru', 'coord': const LatLng(12.9716, 77.5946)},
    {'name': 'Kolkata', 'coord': const LatLng(22.5726, 88.3639)},
    {'name': 'Chennai', 'coord': const LatLng(13.0827, 80.2707)},
    {'name': 'Hyderabad', 'coord': const LatLng(17.3850, 78.4867)},
    {'name': 'Lucknow', 'coord': const LatLng(26.8467, 80.9462)},
    {'name': 'Jaipur', 'coord': const LatLng(26.9124, 75.7873)},
    {'name': 'Patna', 'coord': const LatLng(25.5941, 85.1376)},
    {'name': 'Bhopal', 'coord': const LatLng(23.2599, 77.4126)},
  ];

  // Offline Indian Cities and Coordinates Fallback
  static const List<Map<String, dynamic>> _indianCitiesCoords = [
    {'city': 'New Delhi', 'name': 'New Delhi, Delhi', 'lat': 28.6139, 'lng': 77.2090},
    {'city': 'Noida', 'name': 'Noida, Uttar Pradesh', 'lat': 28.5355, 'lng': 77.3910},
    {'city': 'Gurugram', 'name': 'Gurugram, Haryana', 'lat': 28.4595, 'lng': 77.0266},
    {'city': 'Mumbai', 'name': 'Mumbai, Maharashtra', 'lat': 19.0760, 'lng': 72.8777},
    {'city': 'Pune', 'name': 'Pune, Maharashtra', 'lat': 18.5204, 'lng': 73.8567},
    {'city': 'Bengaluru', 'name': 'Bengaluru, Karnataka', 'lat': 12.9716, 'lng': 77.5946},
    {'city': 'Hyderabad', 'name': 'Hyderabad, Telangana', 'lat': 17.3850, 'lng': 78.4867},
    {'city': 'Chennai', 'name': 'Chennai, Tamil Nadu', 'lat': 13.0827, 'lng': 80.2707},
    {'city': 'Kolkata', 'name': 'Kolkata, West Bengal', 'lat': 22.5726, 'lng': 88.3639},
    {'city': 'Ahmedabad', 'name': 'Ahmedabad, Gujarat', 'lat': 23.0225, 'lng': 72.5714},
    {'city': 'Jaipur', 'name': 'Jaipur, Rajasthan', 'lat': 26.9124, 'lng': 75.7873},
    {'city': 'Lucknow', 'name': 'Lucknow, Uttar Pradesh', 'lat': 26.8467, 'lng': 80.9462},
    {'city': 'Patna', 'name': 'Patna, Bihar', 'lat': 25.5941, 'lng': 85.1376},
    {'city': 'Bhopal', 'name': 'Bhopal, Madhya Pradesh', 'lat': 23.2599, 'lng': 77.4126},
    {'city': 'Chandigarh', 'name': 'Chandigarh, Punjab', 'lat': 30.7333, 'lng': 76.7794},
    {'city': 'Kochi', 'name': 'Kochi, Kerala', 'lat': 9.9312, 'lng': 76.2673},
    {'city': 'Guwahati', 'name': 'Guwahati, Assam', 'lat': 26.1445, 'lng': 91.7362},
    {'city': 'Dehradun', 'name': 'Dehradun, Uttarakhand', 'lat': 30.3165, 'lng': 78.0322},
    {'city': 'Bhubaneswar', 'name': 'Bhubaneswar, Odisha', 'lat': 20.2961, 'lng': 85.8245},
    {'city': 'Ranchi', 'name': 'Ranchi, Jharkhand', 'lat': 23.3441, 'lng': 85.3096},
    {'city': 'Varanasi', 'name': 'Varanasi, Uttar Pradesh', 'lat': 25.3176, 'lng': 82.9739},
    {'city': 'Srinagar', 'name': 'Srinagar, Jammu & Kashmir', 'lat': 34.0837, 'lng': 74.7973},
  ];

  Map<String, String> _getNearestIndianCity(LatLng point) {
    double minDistance = double.infinity;
    Map<String, dynamic> closest = _indianCitiesCoords.first;
    for (final c in _indianCitiesCoords) {
      final dLat = point.latitude - (c['lat'] as double);
      final dLng = point.longitude - (c['lng'] as double);
      final dist = dLat * dLat + dLng * dLng;
      if (dist < minDistance) {
        minDistance = dist;
        closest = c;
      }
    }
    return {
      'city': closest['city'] as String,
      'name': closest['name'] as String,
    };
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialCenter != null) {
      _currentMapCenter = widget.initialCenter!;
      _selectedPoint = widget.initialCenter;
      if (widget.initialLocationName != null) {
        _resolvedAddress = widget.initialLocationName!;
        _resolvedCity = widget.initialLocationName!.split(',').first.trim();
      } else {
        _reverseGeocode(_selectedPoint!);
      }
    } else {
      _selectedPoint = _defaultIndiaCenter;
      _resolvedAddress = widget.initialLocationName ?? 'New Delhi, Delhi, India';
      _resolvedCity = 'New Delhi';
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Reverse geocode LatLng using OpenStreetMap Nominatim API with Indian cities fallback
  Future<void> _reverseGeocode(LatLng point) async {
    setState(() {
      _isGeocoding = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${point.latitude}&lon=${point.longitude}&zoom=18&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AshwiniHealthcarePatientApp/1.0 (dtu_sih_project)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final road = address['road'] ?? address['suburb'] ?? address['neighbourhood'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? address['state_district'] ?? '';
          final state = address['state'] ?? '';
          final postcode = address['postcode'] ?? '';

          final List<String> parts = [];
          if (road.toString().isNotEmpty) parts.add(road.toString());
          if (city.toString().isNotEmpty) parts.add(city.toString());
          if (state.toString().isNotEmpty) parts.add(state.toString());
          if (postcode.toString().isNotEmpty) parts.add(postcode.toString());

          final fullAddress = parts.isNotEmpty ? parts.join(', ') : (data['display_name'] ?? 'Selected Location');

          if (mounted) {
            setState(() {
              _resolvedAddress = fullAddress;
              _resolvedCity = city.toString().isNotEmpty
                  ? city.toString()
                  : (state.toString().isNotEmpty ? state.toString() : 'India');
              _isGeocoding = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback to nearest Indian city
    final nearest = _getNearestIndianCity(point);
    if (mounted) {
      setState(() {
        _resolvedAddress = '${nearest['name']} (${point.latitude.toStringAsFixed(4)}° N, ${point.longitude.toStringAsFixed(4)}° E)';
        _resolvedCity = nearest['city']!;
        _isGeocoding = false;
      });
    }
  }

  /// Search place across India via Nominatim search API
  Future<void> _searchPlace(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&countrycodes=in&limit=5&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'AshwiniHealthcarePatientApp/1.0 (dtu_sih_project)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        final results = list.map((item) => item as Map<String, dynamic>).toList();

        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (hasGesture) {
      setState(() {
        _selectedPoint = camera.center;
        _currentMapCenter = camera.center;
      });
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted && _selectedPoint != null) {
          _reverseGeocode(_selectedPoint!);
        }
      });
    }
  }

  void _onMapTapped(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _currentMapCenter = point;
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
    _mapController.move(point, _mapController.camera.zoom);
    _reverseGeocode(point);
  }

  /// Fetch user's live mobile GPS position and jump map to it
  Future<void> _fetchLiveGpsLocation() async {
    setState(() {
      _isGpsLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showEnableGpsDialog();
        setState(() => _isGpsLoading = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _showSnackBar('Location permission denied. Please allow location to use live GPS.', isError: true);
          setState(() => _isGpsLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showPermissionPermanentlyDeniedDialog();
        setState(() => _isGpsLoading = false);
        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _selectedPoint = userLatLng;
          _currentMapCenter = userLatLng;
          _isGpsLoading = false;
        });

        _mapController.move(userLatLng, 15.5);
        _reverseGeocode(userLatLng);

        _showSnackBar('Live GPS Location detected successfully!', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGpsLoading = false);
        _showSnackBar('Could not acquire live GPS. Please check location settings.', isError: true);
      }
    }
  }

  void _showEnableGpsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.location_off_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 8),
            Text('Enable Location (GPS)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Location services are disabled on your phone. Please turn on GPS location in your device settings to detect your current position.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionPermanentlyDeniedDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Permission Needed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Location permission is permanently denied for ASHWINI app. Please allow location permissions in device settings to use the live mobile GPS feature.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
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

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _confirmSelection() {
    final finalLocation = _resolvedAddress.trim().isNotEmpty
        ? _resolvedAddress.trim()
        : (_selectedPoint != null
            ? 'Lat: ${_selectedPoint!.latitude.toStringAsFixed(4)}, Lng: ${_selectedPoint!.longitude.toStringAsFixed(4)}'
            : 'New Delhi, Delhi');

    Navigator.of(context).pop(finalLocation);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Location on Map',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            Text(
              'Leaflet & OpenStreetMap • Pan anywhere in India',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Live GPS Location',
            icon: _isGpsLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.my_location_rounded, color: AppColors.primary),
            onPressed: _isGpsLoading ? null : _fetchLiveGpsLocation,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // 1. LEAFLET MAP CANVAS (Rotation Locked North-Up)
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentMapCenter,
              initialZoom: 6.0,
              minZoom: 3.5,
              maxZoom: 18.0,
              // Strictly disable map rotation so it never points in random directions
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) => _onMapTapped(point),
              onPositionChanged: (camera, hasGesture) => _onPositionChanged(camera, hasGesture),
            ),
            children: [
              // OpenStreetMap Leaflet Tile Layer
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.ashwini.sih_project',
              ),
            ],
          ),

          // 2. CENTER PIN POINTER (Fixed in center of map canvas, needle tip touches target dot)
          Center(
            child: IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ground Target Dot & Radar Ring at exact coordinate (0, 0)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF5B21B6),
                    ),
                  ),

                  // Floating Teardrop Pin Marker whose bottom needle tip sits exactly at (0, 0)
                  Transform.translate(
                    offset: const Offset(0, -38.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Pin Badge Bubble showing city
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1B4B),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _resolvedCity.isNotEmpty ? _resolvedCity : 'Select Point',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),

                        // Pin Head
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        ),

                        // Pin Needle Tip pointing straight down at (0,0)
                        CustomPaint(
                          size: const Size(12, 10),
                          painter: _TrianglePainter(color: const Color(0xFF6D28D9)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. TOP FLOATING SEARCH & QUICK REGIONS BAR
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              children: [
                // Search Input Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      if (val.length >= 3) {
                        _searchPlace(val);
                      } else {
                        setState(() => _searchResults = []);
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Search city, town, landmark in India...',
                      hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : (_isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),

                // Search Autocomplete Results Dropdown
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 200),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, idx) {
                        final item = _searchResults[idx];
                        final displayName = item['display_name'] ?? '';
                        final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0;
                        final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0;

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 20),
                          title: Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                          ),
                          onTap: () {
                            final targetPoint = LatLng(lat, lon);
                            _mapController.move(targetPoint, 14.5);
                            _onMapTapped(targetPoint);
                            setState(() {
                              _searchResults = [];
                              _searchController.text = displayName.split(',').first.trim();
                            });
                          },
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),

                // Quick Hubs Horizontal Carousel
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickHubs.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final hub = _quickHubs[index];
                      final name = hub['name'] as String;
                      final coord = hub['coord'] as LatLng;

                      return InkWell(
                        onTap: () {
                          _mapController.move(coord, 12.0);
                          _onMapTapped(coord);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFDDD6FE), width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.near_me_rounded, size: 12, color: AppColors.primary),
                              const SizedBox(width: 5),
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E1B4B),
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
          ),

          // 4. FLOATING ACTION BUTTONS (Right Side)
          Positioned(
            right: 14,
            bottom: 220,
            child: Column(
              children: [
                // Live Mobile GPS Button
                FloatingActionButton.small(
                  heroTag: 'liveGpsBtn',
                  backgroundColor: const Color(0xFF7C3AED),
                  foregroundColor: Colors.white,
                  tooltip: 'My Live Mobile GPS Location',
                  onPressed: _isGpsLoading ? null : _fetchLiveGpsLocation,
                  child: _isGpsLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.gps_fixed_rounded, size: 20),
                ),
                const SizedBox(height: 8),

                // Align North Button
                FloatingActionButton.small(
                  heroTag: 'alignNorthBtn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF7C3AED),
                  tooltip: 'Align North',
                  onPressed: () {
                    _mapController.rotate(0);
                    _showSnackBar('Map aligned to North', isError: false);
                  },
                  child: const Icon(Icons.explore_rounded, size: 20),
                ),
                const SizedBox(height: 8),

                // Zoom In
                FloatingActionButton.small(
                  heroTag: 'zoomInBtn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E1B4B),
                  tooltip: 'Zoom In',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom + 1);
                  },
                  child: const Icon(Icons.add, size: 20),
                ),
                const SizedBox(height: 6),

                // Zoom Out
                FloatingActionButton.small(
                  heroTag: 'zoomOutBtn',
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1E1B4B),
                  tooltip: 'Zoom Out',
                  onPressed: () {
                    final zoom = _mapController.camera.zoom;
                    _mapController.move(_mapController.camera.center, zoom - 1);
                  },
                  child: const Icon(Icons.remove, size: 20),
                ),
              ],
            ),
          ),

          // 5. BOTTOM CONFIRMATION / ADDRESS DETAILS SHEET
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Selected Location Header & Coordinates Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDD6FE)),
                        ),
                        child: const Icon(Icons.pin_drop_rounded, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolvedCity.isNotEmpty ? _resolvedCity : 'Selected Location',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (_isGeocoding)
                              const Row(
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Resolving address in India...',
                                    style: TextStyle(fontSize: 11.5, color: AppColors.muted, fontStyle: FontStyle.italic),
                                  ),
                                ],
                              )
                            else
                              Text(
                                _resolvedAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.3),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Coordinates & Status Badges
                  if (_selectedPoint != null)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.gps_fixed, size: 11, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                '${_selectedPoint!.latitude.toStringAsFixed(4)}° N, ${_selectedPoint!.longitude.toStringAsFixed(4)}° E',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 11, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text(
                                'INDIA REGION',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Confirm & Select Button
                  FilledButton.icon(
                    onPressed: _isGeocoding ? null : _confirmSelection,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 20),
                    label: const Text(
                      'Confirm & Select This Location',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
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

/// Downward pointing needle painter for the center pin pointer
class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
