import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../shared/custom_app_bar.dart';
import '../../../utils/colors.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  List<Marker> _markers = [];
  bool _isMapReady = false;
  late AnimationController _pulseController;
  double _currentZoom = 13.0;
  bool _isTracking = true;
  bool _showLocationCard = true;

  // Define multiple locations
  final List<LocationData> _locations = [
    LocationData(
      id: '1',
      name: 'Green Valley Farm',
      position: LatLng(13.0827, 80.2707),
      description: 'Organic vegetable farm',
      type: LocationType.farm,
    ),
    LocationData(
      id: '2',
      name: 'Agri Retailer Store',
      position: LatLng(13.0500, 80.2500),
      description: 'Seeds and fertilizer store',
      type: LocationType.retailer,
    ),
    LocationData(
      id: '3',
      name: 'Main Warehouse',
      position: LatLng(13.1000, 80.3000),
      description: 'Central storage facility',
      type: LocationType.warehouse,
    ),
    LocationData(
      id: '4',
      name: 'Sunrise Farm',
      position: LatLng(13.0700, 80.2600),
      description: 'Rice cultivation',
      type: LocationType.farm,
    ),
    LocationData(
      id: '5',
      name: 'Farm Supply Center',
      position: LatLng(13.0900, 80.2800),
      description: 'Equipment and tools',
      type: LocationType.retailer,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _errorMessage = 'Location services are disabled. Please enable them.';
        _isLoading = false;
      });
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          _errorMessage = 'Location permission denied';
          _isLoading = false;
        });
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _errorMessage = 'Location permissions are permanently denied';
        _isLoading = false;
      });
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _markers = _buildAllMarkers();
        _isLoading = false;
      });

      if (_isMapReady && _currentPosition != null) {
        _mapController.move(_currentPosition!, _currentZoom);
      }

      _listenToLocationUpdates();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
        _isLoading = false;
      });
    }
  }

  void _listenToLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _markers = _buildAllMarkers();
        });

        if (_isTracking && _isMapReady) {
          _mapController.move(_currentPosition!, _currentZoom);
        }
      }
    });
  }

  // Build all markers (user location + all locations)
  List<Marker> _buildAllMarkers() {
    List<Marker> allMarkers = [];

    // Add user location marker
    if (_currentPosition != null) {
      allMarkers.add(_buildUserMarker());
    }

    // Add all location markers
    allMarkers.addAll(_buildLocationMarkers());

    return allMarkers;
  }

  // Build location markers
  List<Marker> _buildLocationMarkers() {
    return _locations.map((location) {
      return Marker(
        point: location.position,
        width: 80,
        height: 80,
        child: GestureDetector(
          onTap: () => _showLocationInfo(location),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getLocationColor(location.type),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Icon(
                  _getLocationIcon(location.type),
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  location.name,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  // Get color based on location type
  Color _getLocationColor(LocationType type) {
    switch (type) {
      case LocationType.retailer:
        return Colors.blue;
      case LocationType.farm:
        return Colors.green.shade700;
      case LocationType.warehouse:
        return Colors.orange.shade700;
      case LocationType.other:
        return AppColors.primaryGreen;
    }
  }

  // Get icon based on location type
  IconData _getLocationIcon(LocationType type) {
    switch (type) {
      case LocationType.retailer:
        return Icons.store;
      case LocationType.farm:
        return Icons.agriculture;
      case LocationType.warehouse:
        return Icons.warehouse;
      case LocationType.other:
        return Icons.location_on;
    }
  }

  // Show location info bottom sheet
  void _showLocationInfo(LocationData location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getLocationColor(location.type),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getLocationIcon(location.type),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        location.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        location.description,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Location details
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${location.position.latitude.toStringAsFixed(6)}, ${location.position.longitude.toStringAsFixed(6)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentPosition != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 18,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Distance: ${_calculateDistance(location.position)} km',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _navigateToLocation(location.position);
                    },
                    icon: const Icon(Icons.center_focus_strong),
                    label: const Text('Center'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _openDirections(location.position);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Calculate distance between current position and location
  String _calculateDistance(LatLng destination) {
    if (_currentPosition == null) return '0.0';

    final Distance distance = Distance();
    final double km = distance.as(
      LengthUnit.Kilometer,
      _currentPosition!,
      destination,
    );

    return km.toStringAsFixed(2);
  }

  // Navigate map to specific location
  void _navigateToLocation(LatLng position) {
    if (_isMapReady) {
      setState(() {
        _isTracking = false;
      });
      _mapController.move(position, 16.0);
    }
  }

  // Open directions in external maps app
  // Open directions in external maps app with current location as origin
  Future<void> _openDirections(LatLng destination) async {
    if (_currentPosition == null) {
      // If current position is not available, just show the destination
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // Build URL with origin (current location) and destination
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=driving'
      '&dir_action=navigate',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: try opening without navigation action
      final fallbackUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
        '&destination=${destination.latitude},${destination.longitude}',
      );

      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
      }
    }
  }


  // Build user marker with pulse animation
  Marker _buildUserMarker() {
    return Marker(
      point: _currentPosition!,
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse circle
              Container(
                width: 60 + (40 * _pulseController.value),
                height: 60 + (40 * _pulseController.value),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mediumGreenAccent.withOpacity(
                    0.15 * (1 - _pulseController.value),
                  ),
                  border: Border.all(
                    color: AppColors.secondaryGreen.withOpacity(
                      0.4 * (1 - _pulseController.value),
                    ),
                    width: 2,
                  ),
                ),
              ),
              // Inner accuracy circle
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mediumGreenAccent.withOpacity(0.3),
                  border: Border.all(color: AppColors.secondaryGreen, width: 2),
                ),
              ),
              // User icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: AppColors.primaryGreen, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _recenterMap() {
    if (_currentPosition != null && _isMapReady) {
      setState(() {
        _isTracking = true;
      });
      _mapController.move(_currentPosition!, 17.0);
    }
  }

  void _zoomIn() {
    if (_isMapReady && _currentZoom < 19.0) {
      setState(() {
        _currentZoom = (_currentZoom + 1).clamp(5.0, 19.0);
      });
      final center = _mapController.camera.center;
      _mapController.move(center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_isMapReady && _currentZoom > 5.0) {
      setState(() {
        _currentZoom = (_currentZoom - 1).clamp(5.0, 19.0);
      });
      final center = _mapController.camera.center;
      _mapController.move(center, _currentZoom);
    }
  }

  Future<void> _launchCopyright() async {
    final uri = Uri.parse('https://www.openstreetmap.org/copyright');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _isLoading ? AppColors.backgroundColor : null,
      appBar: BackAppBar(
        title: 'Map Service',
        actions: [
          if (_currentPosition != null)
            IconButton(
              icon: Icon(
                _showLocationCard ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textWhite,
                size: 24,
              ),
              onPressed: () {
                setState(() {
                  _showLocationCard = !_showLocationCard;
                });
              },
              tooltip: _showLocationCard ? 'Hide Info' : 'Show Info',
            ),
        ],
      ),
      body: Stack(
        children: [
          // Main content
          if (_isLoading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Getting your location...',
                    style: TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await Geolocator.openLocationSettings();
                      },
                      icon: const Icon(Icons.settings),
                      label: const Text('Open Settings'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Stack(
              children: [
                // Full-screen map
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(top: 90),
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter:
                            _currentPosition ?? const LatLng(13.0827, 80.2707),
                        initialZoom: _currentZoom,
                        minZoom: 5.0,
                        maxZoom: 19.0,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                          pinchZoomThreshold: 0.5,
                          pinchZoomWinGestures: MultiFingerGesture.pinchZoom,
                          pinchMoveThreshold: 40.0,
                          enableMultiFingerGestureRace: true,
                        ),
                        onMapReady: () {
                          setState(() {
                            _isMapReady = true;
                          });
                          if (_currentPosition != null) {
                            _mapController.move(
                              _currentPosition!,
                              _currentZoom,
                            );
                          }
                        },
                        onPositionChanged: (position, hasGesture) {
                          if (hasGesture && _isTracking) {
                            setState(() {
                              _isTracking = false;
                            });
                          }
                          setState(() {
                            _currentZoom = position.zoom;
                          });
                        },
                      ),
                      children: [
                        // OpenStreetMap tiles
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            AppColors.secondaryGreen.withOpacity(0.12),
                            BlendMode.softLight,
                          ),
                          child: TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.agrhi.app',
                            maxZoom: 19,
                          ),
                        ),
                        // All markers (user + locations)
                        MarkerLayer(markers: _markers),
                      ],
                    ),
                  ),
                ),

                // Zoom controls
                Positioned(
                  bottom: 24,
                  right: 16,
                  child: Column(
                    children: [
                      // Zoom In
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _zoomIn,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(10),
                                topRight: Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        height: 1,
                        width: 44,
                        color: AppColors.tertiaryGreen,
                      ),
                      // Zoom Out
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _zoomOut,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(10),
                            bottomRight: Radius.circular(10),
                          ),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen,
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(10),
                                bottomRight: Radius.circular(10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.remove,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Recenter button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _recenterMap,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _isTracking
                                  ? AppColors.secondaryGreen
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.my_location,
                              color: _isTracking
                                  ? Colors.white
                                  : AppColors.primaryGreen,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Attribution
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: GestureDetector(
                    onTap: _launchCopyright,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap',
                        style: TextStyle(fontSize: 8, color: Colors.black87),
                      ),
                    ),
                  ),
                ),

                // Compact location info card
                if (_showLocationCard && _currentPosition != null)
                  Positioned(
                    top: 100,
                    left: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showLocationCard = false;
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryGreen,
                              AppColors.primaryGreen.withOpacity(0.95),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryGreen,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryGreen.withOpacity(
                                    0.3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Z${_currentZoom.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Locations count badge
                Positioned(
                  top: 100,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.pin_drop,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_locations.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}

// Location data model
class LocationData {
  final String id;
  final String name;
  final LatLng position;
  final String description;
  final LocationType type;

  LocationData({
    required this.id,
    required this.name,
    required this.position,
    required this.description,
    required this.type,
  });

  // From JSON (for API integration)
  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      id: json['id'].toString(),
      name: json['name'],
      position: LatLng(
        double.parse(json['latitude'].toString()),
        double.parse(json['longitude'].toString()),
      ),
      description: json['description'] ?? '',
      type: _parseLocationType(json['type']),
    );
  }

  static LocationType _parseLocationType(String? type) {
    switch (type?.toLowerCase()) {
      case 'retailer':
        return LocationType.retailer;
      case 'farm':
        return LocationType.farm;
      case 'warehouse':
        return LocationType.warehouse;
      default:
        return LocationType.other;
    }
  }

  // To JSON (for API integration)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'description': description,
      'type': type.toString().split('.').last,
    };
  }
}

// Location type enum
enum LocationType { retailer, farm, warehouse, other }
