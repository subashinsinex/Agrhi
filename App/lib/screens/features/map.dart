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
  double _currentZoom = 17.0;
  bool _isTracking = true;
  bool _showLocationCard = true;

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
        _markers = [_buildUserMarker()];
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
          _markers = [_buildUserMarker()];
        });

        if (_isTracking && _isMapReady) {
          _mapController.move(_currentPosition!, _currentZoom);
        }
      }
    });
  }

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
      _mapController.move(_currentPosition!, _currentZoom);
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
                            _currentPosition ?? const LatLng(20.5937, 78.9629),
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
                if (_showLocationCard)
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
