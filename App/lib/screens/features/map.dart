import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
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
  double _currentZoom = 15.0;
  bool _isTracking = true;

  // Custom cache manager for map tiles
  static final customCacheManager = CacheManager(
    Config(
      'mapTileCache',
      stalePeriod: const Duration(days: 30), // Cache tiles for 30 days
      maxNrOfCacheObjects: 1000, // Store up to 1000 tiles
      repo: JsonCacheInfoRepository(databaseName: 'mapTileCache'),
      fileService: HttpFileService(),
    ),
  );

  // Define multiple locations
  final List<LocationData> _locations = [
    LocationData(
      id: '1',
      name: 'Green Valley Farm',
      position: const LatLng(13.0827, 80.2707),
      description: 'Organic vegetable farm',
      type: LocationType.farm,
    ),
    LocationData(
      id: '2',
      name: 'Agri Retailer Store',
      position: const LatLng(13.0500, 80.2500),
      description: 'Seeds and fertilizer store',
      type: LocationType.retailer,
    ),
    LocationData(
      id: '3',
      name: 'Main Warehouse',
      position: const LatLng(13.1000, 80.3000),
      description: 'Central storage facility',
      type: LocationType.warehouse,
    ),
    LocationData(
      id: '4',
      name: 'Sunrise Farm',
      position: const LatLng(13.0700, 80.2600),
      description: 'Rice cultivation',
      type: LocationType.farm,
    ),
    LocationData(
      id: '5',
      name: 'Farm Supply Center',
      position: const LatLng(13.0900, 80.2800),
      description: 'Equipment and tools',
      type: LocationType.retailer,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _getCurrentLocation();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Location services are disabled. Please enable them.';
          _isLoading = false;
        });
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Location permission denied';
            _isLoading = false;
          });
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied';
          _isLoading = false;
        });
      }
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

      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _markers = _buildAllMarkers();
          _isLoading = false;
        });

        if (_isMapReady && _currentPosition != null) {
          _mapController.move(_currentPosition!, _currentZoom);
        }
      }

      _listenToLocationUpdates();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error getting location: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _listenToLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (!mounted) return;

      final newPos = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentPosition = newPos;
        _markers = _buildAllMarkers();
      });

      if (_isTracking && _isMapReady) {
        _mapController.move(newPos, _currentZoom);
      }
    });
  }

  List<Marker> _buildAllMarkers() {
    List<Marker> allMarkers = [];

    if (_currentPosition != null) {
      allMarkers.add(_buildUserMarker());
    }

    allMarkers.addAll(_buildLocationMarkers());

    return allMarkers;
  }

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

  String _calculateDistance(LatLng destination) {
    if (_currentPosition == null) return '0.0';
    const Distance distance = Distance();
    final double km = distance.as(
      LengthUnit.Kilometer,
      _currentPosition!,
      destination,
    );
    return km.toStringAsFixed(2);
  }

  void _navigateToLocation(LatLng position) {
    if (_isMapReady) {
      setState(() {
        _isTracking = false;
      });
      _mapController.move(position, 16.0);
    }
  }

  Future<void> _openDirections(LatLng destination) async {
    if (_currentPosition == null) {
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}',
      );
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  Marker _buildUserMarker() {
    return Marker(
      point: _currentPosition!,
      width: 100,
      height: 100,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
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
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.mediumGreenAccent.withOpacity(0.3),
                    border: Border.all(
                      color: AppColors.secondaryGreen,
                      width: 2,
                    ),
                  ),
                ),
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

  // Method to clear cache if needed
  Future<void> _clearMapCache() async {
    await customCacheManager.emptyCache();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Map cache cleared')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _isLoading ? AppColors.backgroundColor : null,
      appBar: BackAppBar(title: 'Map Service'),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                    strokeWidth: 3,
                  ),
                  SizedBox(height: 16),
                  Text(
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
                          if (hasGesture) {
                            setState(() {
                              _currentZoom = position.zoom;
                            });
                          }
                        },
                      ),
                      children: [
                        // TileLayer with caching enabled
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'app.agrhi.com',
                          maxZoom: 19,
                          // Enable tile caching
                          tileProvider: NetworkTileProvider(
                            headers: {'User-Agent': 'app.agrhi.com'},
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

                // Bottom left badges
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_currentPosition != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      GestureDetector(
                        onTap: _launchCopyright,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: const Text(
                            '© OpenStreetMap',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
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

enum LocationType { retailer, farm, warehouse, other }
