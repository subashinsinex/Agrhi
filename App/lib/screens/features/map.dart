import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../shared/custom_app_bar.dart';
import '../../../utils/colors.dart';
import '../../src/services/api_service.dart';

/// Custom tile provider with caching support
class CachedTileProvider extends TileProvider {
  final CacheManager cacheManager;
  final Map<String, String> headers;

  CachedTileProvider({required this.cacheManager, this.headers = const {}});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);

    return CachedNetworkImageProvider(
      url,
      cacheManager: cacheManager,
      headers: headers,
    );
  }

  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    return options.urlTemplate!
        .replaceAll('{z}', coordinates.z.toString())
        .replaceAll('{x}', coordinates.x.toString())
        .replaceAll('{y}', coordinates.y.toString());
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService.instance;

  LatLng? _currentPosition;
  List<Marker> _markers = [];
  bool _isMapReady = false;
  late AnimationController _pulseController;
  double _currentZoom = 17.0;
  bool _isTracking = true;
  String? _profileImagePath;
  Timer? _locationUpdateTimer;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  // Optimized cache manager for map tiles
  static final customCacheManager = CacheManager(
    Config(
      'mapTileCache',
      stalePeriod: const Duration(days: 90),
      maxNrOfCacheObjects: 2000,
      repo: JsonCacheInfoRepository(databaseName: 'mapTileCache'),
      fileService: HttpFileService(),
    ),
  );

  // Dynamic locations from API
  List<LocationData> _locations = [];
  bool _isLoadingLocations = false;

  // Distance filter
  double _distanceFilter = 10.0;

  // Default center (Chennai)
  static const LatLng _defaultCenter = LatLng(13.0827, 80.2707);

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

    // ✅ Load everything immediately in parallel
    _initializeMapData();
  }

  /// ✅ Load profile image and location instantly, then stores
  Future<void> _initializeMapData() async {
    // Start profile image and location loading immediately (non-blocking)
    unawaited(_loadProfileImage());
    unawaited(_getLocationFast());

    // Load stores in background after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _loadStoreLocations();
    });
  }

  /// ✅ Fast location strategy: last known position first, then accurate position
  Future<void> _getLocationFast() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    try {
      // ✅ Step 1: Get last known position INSTANTLY (cached, no GPS wait)
      final lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null && mounted) {
        final lastPos = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _currentPosition = lastPos;
          _markers = _buildAllMarkers();
        });

        // Move map to last known position immediately
        if (_isMapReady) {
          _mapController.move(lastPos, _currentZoom);
        }

        debugPrint(
          '✅ Showing last known position: ${lastPos.latitude}, ${lastPos.longitude}',
        );
      }

      // ✅ Step 2: Get accurate current position in background (may take 2-4 seconds)
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (mounted) {
        final currentPos = LatLng(
          currentPosition.latitude,
          currentPosition.longitude,
        );

        // Only update if position changed significantly (> 10 meters)
        if (_currentPosition == null ||
            _calculateDistance(_currentPosition!, currentPos) > 10) {
          setState(() {
            _currentPosition = currentPos;
            _markers = _buildAllMarkers();
          });

          // Smoothly move to accurate position
          if (_isMapReady && _isTracking) {
            _mapController.move(currentPos, _currentZoom);
          }

          debugPrint(
            '✅ Updated to accurate position: ${currentPos.latitude}, ${currentPos.longitude}',
          );
        }
      }

      // Start listening for real-time updates
      _listenToLocationUpdates();
    } catch (e) {
      debugPrint('⚠️ Error getting location: $e');

      // Fallback: try last known position one more time
      try {
        final fallbackPos = await Geolocator.getLastKnownPosition();
        if (fallbackPos != null && mounted) {
          final pos = LatLng(fallbackPos.latitude, fallbackPos.longitude);
          setState(() {
            _currentPosition = pos;
            _markers = _buildAllMarkers();
          });
          if (_isMapReady) {
            _mapController.move(pos, _currentZoom);
          }
        }
      } catch (e) {
        debugPrint('⚠️ Fallback also failed: $e');
      }
    }
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, from, to);
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
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingLocations = false;
          });
          debugPrint('⚠️ Failed to load stores: ${response.error}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading store locations: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  Future<void> _refreshLocations() async {
    await _loadStoreLocations();
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ Location services disabled');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('⚠️ Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('⚠️ Location permission permanently denied');
      return false;
    }

    return true;
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

      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        setState(() {
          _currentPosition = newPos;
          _markers = _buildAllMarkers();
        });

        if (_isTracking && _isMapReady) {
          _mapController.move(newPos, _currentZoom);
        }
      });
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

  void _showStoreListBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
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
                    Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

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
                              showValueIndicator: ShowValueIndicator.never,
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '1 km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '10 km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Text(
                                '50 km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

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
                                      setModalState(() => _distanceFilter = 50);
                                      setState(
                                        () => _markers = _buildAllMarkers(),
                                      );
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

  double _getSliderValue(double distance) {
    const intervals = [1.0, 5.0, 10.0, 20.0, 30.0, 40.0, 50.0];
    for (int i = 0; i < intervals.length; i++) {
      if (distance <= intervals[i]) return i.toDouble();
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

  void _navigateToLocation(LatLng position) {
    if (_isMapReady) {
      setState(() => _isTracking = false);
      _mapController.move(position, 16.0);
    }
  }

  Future<void> _openDirections(LatLng destination) async {
    if (_currentPosition == null) {
      final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${destination.latitude},${destination.longitude}',
      );
      if (await canLaunchUrl(url))
        await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }

    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_currentPosition!.latitude},${_currentPosition!.longitude}'
      '&destination=${destination.latitude},${destination.longitude}'
      '&travelmode=driving',
    );

    try {
      if (await canLaunchUrl(url))
        await launchUrl(url, mode: LaunchMode.externalApplication);
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
      setState(() => _isTracking = true);
      _mapController.move(_currentPosition!, _currentZoom);
    }
  }

  void _zoomIn() {
    if (_isMapReady && _currentZoom < 19.0) {
      setState(() => _currentZoom = (_currentZoom + 1).clamp(5.0, 19.0));
      final center = _mapController.camera.center;
      _mapController.move(center, _currentZoom);
    }
  }

  void _zoomOut() {
    if (_isMapReady && _currentZoom > 5.0) {
      setState(() => _currentZoom = (_currentZoom - 1).clamp(5.0, 19.0));
      final center = _mapController.camera.center;
      _mapController.move(center, _currentZoom);
    }
  }

  Future<void> _launchCopyright() async {
    final uri = Uri.parse('https://www.openstreetmap.org/copyright');
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.backgroundColor,
      appBar: BackAppBar(
        title: 'Map Service',
        actions: [
          if (_isLoadingLocations)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshLocations,
              tooltip: 'Refresh store locations',
            ),
        ],
      ),
      body: Stack(
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
                  initialCenter: _currentPosition ?? _defaultCenter,
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
                    setState(() => _isMapReady = true);
                    if (_currentPosition != null) {
                      _mapController.move(_currentPosition!, _currentZoom);
                    }
                  },
                  onPositionChanged: (position, hasGesture) {
                    if (hasGesture && _isTracking) {
                      setState(() => _isTracking = false);
                    }
                    if (hasGesture) {
                      setState(() => _currentZoom = position.zoom);
                    }
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'app.agrhi.com',
                    maxZoom: 19,
                    tileProvider: CachedTileProvider(
                      cacheManager: customCacheManager,
                      headers: {'User-Agent': 'app.agrhi.com'},
                    ),
                    keepBuffer: 2,
                    tileSize: 256,
                    retinaMode: false,
                  ),
                  MarkerLayer(markers: _markers),
                ],
              ),
            ),
          ),

          // Controls on the right side
          Positioned(
            bottom: 24,
            right: 16,
            child: Column(
              children: [
                // Store badge
                if (_locations.isNotEmpty)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _showStoreListBottomSheet,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.store,
                              color: Colors.white,
                              size: 22,
                            ),
                            if (_filteredLocations.length != _locations.length)
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  child: Text(
                                    '${_filteredLocations.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_locations.isNotEmpty) const SizedBox(height: 12),

                _buildControlButton(Icons.add, _zoomIn, isTop: true),
                Container(height: 1, width: 44, color: AppColors.tertiaryGreen),
                _buildControlButton(Icons.remove, _zoomOut, isBottom: true),
                const SizedBox(height: 12),
                _buildRecenterButton(),
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
                  _buildInfoBadge(
                    '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                    margin: const EdgeInsets.only(bottom: 6),
                  ),
                GestureDetector(
                  onTap: _launchCopyright,
                  child: _buildInfoBadge('© OpenStreetMap'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    VoidCallback onTap, {
    bool isTop = false,
    bool isBottom = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.only(
          topLeft: isTop ? const Radius.circular(10) : Radius.zero,
          topRight: isTop ? const Radius.circular(10) : Radius.zero,
          bottomLeft: isBottom ? const Radius.circular(10) : Radius.zero,
          bottomRight: isBottom ? const Radius.circular(10) : Radius.zero,
        ),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen,
            borderRadius: BorderRadius.only(
              topLeft: isTop ? const Radius.circular(10) : Radius.zero,
              topRight: isTop ? const Radius.circular(10) : Radius.zero,
              bottomLeft: isBottom ? const Radius.circular(10) : Radius.zero,
              bottomRight: isBottom ? const Radius.circular(10) : Radius.zero,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _buildRecenterButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _recenterMap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isTracking ? AppColors.secondaryGreen : Colors.white,
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
            color: _isTracking ? Colors.white : AppColors.primaryGreen,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String text, {EdgeInsets? margin}) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }
}

// Helper for unawaited futures
void unawaited(Future<void> future) {}

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
      if (parsed != null && parsed.abs() <= 180) return parsed;
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
}

enum LocationType { retailer, farm, warehouse, other }
