import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../shared/custom_app_bar.dart';
import '../../../utils/colors.dart';
import '../../src/services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService.instance;

  LatLng? _currentPosition;
  bool _isLoading = true;
  String? _errorMessage;
  List<Marker> _markers = [];
  bool _isMapReady = false;
  late AnimationController _pulseController;
  double _currentZoom = 13.0;
  bool _isTracking = true;
  String? _profileImagePath;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  static final customCacheManager = CacheManager(
    Config(
      'mapTileCache',
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: 'mapTileCache'),
      fileService: HttpFileService(),
    ),
  );

  // Dynamic locations from API
  List<LocationData> _locations = [];
  bool _isLoadingLocations = false;

  // Distance filter
  double _distanceFilter = 10.0; // Default 10km
  List<LocationData> get _filteredLocations {
    if (_currentPosition == null) return _locations;

    return _locations.where((location) {
      final distance = _calculateDistanceInKm(location.position);
      return distance <= _distanceFilter;
    }).toList()..sort((a, b) {
      final distA = _calculateDistanceInKm(a.position);
      final distB = _calculateDistanceInKm(b.position);
      return distA.compareTo(distB);
    });
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _loadProfileImage();
    _getCurrentLocation();
    _loadStoreLocations();
  }

  Future<void> _loadProfileImage() async {
    try {
      final path = await _storage.read(key: 'profile_image_local_path');
      if (mounted && path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          setState(() {
            _profileImagePath = path;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile image: $e');
    }
  }

  Future<void> _loadStoreLocations() async {
    setState(() {
      _isLoadingLocations = true;
    });

    try {
      final response = await _apiService.get(
        '/retail/store-locations',
        requiresAuth: true,
      );

      if (response.isSuccess && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];

        final locations = data
            .map((json) => LocationData.fromRetailerJson(json))
            .toList();

        final validLocations = locations
            .where((loc) => loc.hasValidCoordinates())
            .toList();

        if (mounted) {
          setState(() {
            _locations = validLocations;
            _markers = _buildAllMarkers();
            _isLoadingLocations = false;
          });

          debugPrint('✅ Loaded ${validLocations.length} store locations');

          if (locations.length != validLocations.length) {
            _showSnackBar(
              '${locations.length - validLocations.length} store(s) have invalid coordinates',
              isError: false,
            );
          }
        }
      } else if (response.isOffline) {
        if (mounted) {
          setState(() {
            _isLoadingLocations = false;
          });
          _showSnackBar('No internet connection', isError: true);
        }
      } else if (response.isUnauthorized || response.isUnauthenticated) {
        if (mounted) {
          setState(() {
            _isLoadingLocations = false;
          });
          _showSnackBar('Authentication required', isError: true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingLocations = false;
          });
          _showSnackBar(
            response.error ?? 'Failed to load store locations',
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading store locations: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
        _showSnackBar('Error loading stores: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.orange,
        duration: Duration(seconds: isError ? 4 : 3),
        action: isError
            ? SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: _loadStoreLocations,
              )
            : null,
      ),
    );
  }

  Future<void> _refreshLocations() async {
    await _loadStoreLocations();
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
    // Only show markers within the distance filter
    return _filteredLocations.map((location) {
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

  /// Show store list bottom sheet with distance filter
  void _showStoreListBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true, // Allow tap outside to dismiss
      enableDrag: true, // Allow dragging to dismiss
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header (without close button)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.store,
                            color: AppColors.primaryGreen,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Nearby Stores',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${_filteredLocations.length} stores within ${_getDistanceLabel(_distanceFilter)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Distance slider with specific intervals
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Distance Filter',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _getDistanceLabel(_distanceFilter),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: AppColors.primaryGreen,
                              inactiveTrackColor: AppColors.primaryGreen
                                  .withOpacity(0.2),
                              thumbColor: AppColors.primaryGreen,
                              overlayColor: AppColors.primaryGreen.withOpacity(
                                0.2,
                              ),
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 12,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 24,
                              ),
                            ),
                            child: Slider(
                              value: _getSliderValue(_distanceFilter),
                              min: 0,
                              max: 6,
                              divisions: 6,
                              onChanged: (value) {
                                final newDistance = _getDistanceFromSlider(
                                  value,
                                );
                                setModalState(() {
                                  _distanceFilter = newDistance;
                                });
                                setState(() {
                                  _markers = _buildAllMarkers();
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Store list
                    Expanded(
                      child: _filteredLocations.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.store_mall_directory_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No stores found within ${_getDistanceLabel(_distanceFilter)}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setModalState(() {
                                        _distanceFilter = 50;
                                      });
                                      setState(() {
                                        _markers = _buildAllMarkers();
                                      });
                                    },
                                    child: const Text(
                                      'Increase distance filter',
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _filteredLocations.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final location = _filteredLocations[index];
                                final distance = _calculateDistanceInKm(
                                  location.position,
                                );

                                return ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  leading: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _getLocationColor(
                                        location.type,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _getLocationIcon(location.type),
                                      color: _getLocationColor(location.type),
                                      size: 28,
                                    ),
                                  ),
                                  title: Text(
                                    location.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 4),
                                      Text(
                                        location.description,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      if (location.address != null &&
                                          location.address!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          location.address!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[500],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: AppColors.primaryGreen,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${distance.toStringAsFixed(2)} km away',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  trailing: const Icon(
                                    Icons.arrow_forward_ios,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _navigateToLocation(location.position);
                                    Future.delayed(
                                      const Duration(milliseconds: 500),
                                      () {
                                        _showLocationInfo(location);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper methods for distance intervals
  double _getSliderValue(double distance) {
    const intervals = [1.0, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0];
    for (int i = 0; i < intervals.length; i++) {
      if (distance <= intervals[i]) {
        return i.toDouble();
      }
    }
    return 6.0;
  }

  double _getDistanceFromSlider(double sliderValue) {
    const intervals = [1.0, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0];
    int index = sliderValue.round().clamp(0, intervals.length - 1);
    return intervals[index];
  }

  String _getDistanceLabel(double distance) {
    return '${distance.toStringAsFixed(0)} km';
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

            if (location.address != null && location.address!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_city,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        location.address!,
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

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
                          'Distance: ${_calculateDistanceInKm(location.position).toStringAsFixed(2)} km',
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

  double _calculateDistanceInKm(LatLng destination) {
    if (_currentPosition == null) return 0.0;
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, _currentPosition!, destination);
  }

  String _calculateDistance(LatLng destination) {
    return _calculateDistanceInKm(destination).toStringAsFixed(2);
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
      width: 125,
      height: 125,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 75 + (50 * _pulseController.value),
                  height: 75 + (50 * _pulseController.value),
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
                  width: 62.5,
                  height: 62.5,
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
                  width: 50,
                  height: 50,
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
                    image: _profileImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_profileImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImagePath == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.primaryGreen,
                          size: 30,
                        )
                      : null,
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
      appBar: BackAppBar(
        title: 'Map Service',
        actions: [
          IconButton(
            icon: _isLoadingLocations
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isLoadingLocations ? null : _refreshLocations,
            tooltip: 'Refresh store locations',
          ),
        ],
      ),
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
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'app.agrhi.com',
                          maxZoom: 19,
                          tileProvider: NetworkTileProvider(
                            headers: {'User-Agent': 'app.agrhi.com'},
                          ),
                        ),
                        MarkerLayer(markers: _markers),
                      ],
                    ),
                  ),
                ),

                // Clickable store count badge
                if (_locations.isNotEmpty)
                  Positioned(
                    top: 100,
                    left: 16,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showStoreListBottomSheet,
                        borderRadius: BorderRadius.circular(20),
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
                                Icons.store,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
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
  final String? address;

  LocationData({
    required this.id,
    required this.name,
    required this.position,
    required this.description,
    required this.type,
    this.address,
  });

  factory LocationData.fromRetailerJson(Map<String, dynamic> json) {
    return LocationData(
      id: json['retailer_id'] ?? '',
      name: json['shop_name'] ?? 'Unknown Store',
      position: LatLng(
        _parseDouble(json['latitude']),
        _parseDouble(json['longitude']),
      ),
      description: json['business_type'] ?? '',
      type: _parseBusinessType(json['business_type']),
      address: json['shop_address'],
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null && parsed.abs() <= 180) {
        return parsed;
      }
      return 0.0;
    }
    return 0.0;
  }

  static LocationType _parseBusinessType(String? type) {
    switch (type?.toLowerCase()) {
      case 'fertilizer':
      case 'seeds':
      case 'equipment':
      case 'all':
        return LocationType.retailer;
      case 'farm':
        return LocationType.farm;
      case 'warehouse':
        return LocationType.warehouse;
      default:
        return LocationType.other;
    }
  }

  bool hasValidCoordinates() {
    return position.latitude.abs() <= 90 &&
        position.longitude.abs() <= 180 &&
        position.latitude != 0.0 &&
        position.longitude != 0.0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'description': description,
      'type': type.toString().split('.').last,
      'address': address,
    };
  }
}

enum LocationType { retailer, farm, warehouse, other }
