import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../shared/disclaimer_banner.dart';
import '../../../src/services/language_service.dart';
import '../../../src/services/farm_store_service.dart';


class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _selectedPosition;
  bool _isMapReady = false;
  bool _isLoadingLocation = false;
  // ignore: unused_field
  bool _hasAcknowledged = false;
  String _currentAddress = '';
  bool _isLoadingAddress = false;
  final double _currentZoom = 17.0;
  final double _maxAdjustmentRadius = 100.0;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadTranslations();
    });
  }

  Future<void> _preloadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    await languageService.preloadTexts([
      'Farm Store Setup',
      'Set Your Selling Location',
      'To sell products, we need your exact selling location. Consumers will use this to:',
      'Calculate distance',
      'Visit your location',
      'Contact for delivery',
      'Be at your exact selling area before clicking "Get Location"',
      'Get My Exact Location',
      'Getting Location...',
      'Tap on map to adjust location (within 100m)',
      'Refresh',
      'Confirm Location',
      'Important',
      'This will be your permanent selling location',
      'Consumers will see this location to find you',
      'They can calculate distance and plan visits',
      'Contact you for delivery arrangements',
      'Make sure you are at your selling area before setting location',
      'I\'ll Come Back',
      'I Understand',
      'This location will be visible to consumers:',
      'Adjusted',
      'from GPS position',
      'Remember: This is permanent and cannot be changed easily.',
      'Review',
      'Confirm',
      'Location services are disabled. Please enable them.',
      'Location permission denied',
      'Location permission permanently denied. Enable in settings.',
      'Location acquired successfully',
      'Failed to get location. Please try again.',
      'Please get your current location first',
      'Please set your location first',
      'Location confirmed successfully!',
      'Your Selling Location',
      'Loading address...',
      'Address not available',
      'Saving location...',
      'Failed to save location',
      'No internet connection. Please try again.',
      'Session expired. Please login again.',
    ], highPriority: true);
  }

  void _logLocationDetails(LatLng position, {String label = 'LOCATION'}) {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('📍 $label DETAILS');
    debugPrint('═══════════════════════════════════════════');
    debugPrint('Latitude: ${position.latitude}');
    debugPrint('Longitude: ${position.longitude}');
    debugPrint('═══════════════════════════════════════════\n');
  }

  Future<void> _getAddressFromCoordinates(LatLng position) async {
    setState(() => _isLoadingAddress = true);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        String fullAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((element) => element != null && element.isNotEmpty).join(', ');

        setState(() {
          _currentAddress = fullAddress.isNotEmpty
              ? fullAddress
              : 'Address not available';
          _isLoadingAddress = false;
        });

        debugPrint('═══════════════════════════════════════════');
        debugPrint('📍 LOCATION WITH ADDRESS');
        debugPrint('═══════════════════════════════════════════');
        debugPrint('Latitude: ${position.latitude}');
        debugPrint('Longitude: ${position.longitude}');
        debugPrint('───────────────────────────────────────────');
        debugPrint('Full Address: $fullAddress');
        debugPrint('═══════════════════════════════════════════\n');
      } else {
        setState(() {
          _currentAddress = 'Address not available';
          _isLoadingAddress = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error getting address: $e');
      setState(() {
        _currentAddress = 'Address not available';
        _isLoadingAddress = false;
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar(
        'Location services are disabled. Please enable them.',
        isError: true,
      );
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permission denied', isError: true);
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar(
        'Location permission permanently denied. Enable in settings.',
        isError: true,
      );
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation) return;

    setState(() => _isLoadingLocation = true);

    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final currentPos = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = currentPos;
          _selectedPosition = currentPos;
          _isLoadingLocation = false;
        });

        if (_isMapReady) {
          _mapController.move(currentPos, _currentZoom);
        }

        _logLocationDetails(currentPos, label: 'GPS ACQUIRED');
        await _getAddressFromCoordinates(currentPos);
        _showSnackBar('Location acquired successfully', isError: false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        _showSnackBar(
          'Failed to get location. Please try again.',
          isError: true,
        );
      }
      debugPrint('Error getting location: $e');
    }
  }

  double _calculateDistance(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Meter, from, to);
  }

  void _onMapTap(TapPosition tapPosition, LatLng tappedPoint) {
    if (_currentPosition == null) {
      _showSnackBar('Please get your current location first', isError: true);
      return;
    }

    final distance = _calculateDistance(_currentPosition!, tappedPoint);

    if (distance <= _maxAdjustmentRadius) {
      setState(() => _selectedPosition = tappedPoint);

      _logLocationDetails(tappedPoint, label: 'ADJUSTED LOCATION');
      debugPrint('Distance from original: ${distance.toStringAsFixed(2)}m\n');

      _getAddressFromCoordinates(tappedPoint);
    }
  }

  void _showAcknowledgmentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.info_outline,
                color: AppColors.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: SmartReTranslator(
                text: 'Important',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SmartReTranslator(
                text: 'This will be your permanent selling location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildDialogInfoPoint(
                Icons.location_on,
                'Consumers will see this location to find you',
              ),
              const SizedBox(height: 12),
              _buildDialogInfoPoint(
                Icons.straighten,
                'They can calculate distance and plan visits',
              ),
              const SizedBox(height: 12),
              _buildDialogInfoPoint(
                Icons.local_shipping,
                'Contact you for delivery arrangements',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: SmartReTranslator(
                        text:
                            'Make sure you are at your selling area before setting location',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const SmartReTranslator(
              text: 'I\'ll Come Back',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _hasAcknowledged = true);
              _getCurrentLocation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const SmartReTranslator(
              text: 'I Understand',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogInfoPoint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primaryGreen),
        const SizedBox(width: 10),
        Expanded(
          child: SmartReTranslator(
            text: text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPoint(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryGreen),
        const SizedBox(width: 10),
        Expanded(
          child: SmartReTranslator(
            text: text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SmartReTranslator(
          text: message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError
            ? AppColors.errorColor
            : AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  List<CircleMarker> _buildCircles() {
    List<CircleMarker> circles = [];

    if (_currentPosition != null) {
      circles.add(
        CircleMarker(
          point: _currentPosition!,
          radius: _maxAdjustmentRadius,
          useRadiusInMeter: true,
          color: AppColors.primaryGreen.withOpacity(0.15),
          borderStrokeWidth: 3,
          borderColor: AppColors.primaryGreen,
        ),
      );
    }

    return circles;
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    if (_selectedPosition != null) {
      markers.add(
        Marker(
          point: _selectedPosition!,
          width: 50,
          height: 50,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.agriculture,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Container(
                width: 4,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(2),
                    bottomRight: Radius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  void _confirmLocation() {
    if (_selectedPosition == null) {
      _showSnackBar('Please set your location first', isError: true);
      return;
    }

    _logLocationDetails(_selectedPosition!, label: 'FINAL CONFIRMED LOCATION');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const SmartReTranslator(
          text: 'Confirm Location',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SmartReTranslator(
              text: 'This location will be visible to consumers:',
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_currentPosition != null &&
                      _selectedPosition != _currentPosition) ...[
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.straighten,
                          size: 18,
                          color: AppColors.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SmartReTranslator(
                            text:
                                'Adjusted ${_calculateDistance(_currentPosition!, _selectedPosition!).toStringAsFixed(1)}m from GPS position',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: SmartReTranslator(
                      text:
                          'Remember: This is permanent and cannot be changed easily.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const SmartReTranslator(
              text: 'Review',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => _saveLocationToBackend(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const SmartReTranslator(
              text: 'Confirm',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveLocationToBackend(BuildContext dialogContext) async {
    Navigator.pop(dialogContext);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primaryGreen),
                SizedBox(height: 16),
                Text(
                  'Saving location...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final result = await FarmStoreService.addFarmerShopPlace(
      latitude: _selectedPosition!.latitude,
      longitude: _selectedPosition!.longitude,
    );

    if (mounted) {
      Navigator.pop(context);

      if (result['success'] == true) {
        await _storage.write(key: 'has_shop_place', value: 'true');
        await _storage.write(
          key: 'shop_place_data',
          value: jsonEncode(result['shopPlace']),
        );

        debugPrint('✅ Shop place flag updated in storage');

        _showSnackBar('Location confirmed successfully!', isError: false);

        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        String errorMessage = 'Failed to save location';

        if (result['isOffline'] == true) {
          errorMessage = 'No internet connection. Please try again.';
        } else if (result['needsAuth'] == true) {
          errorMessage = 'Session expired. Please login again.';
        } else {
          errorMessage = result['message'] ?? errorMessage;
        }

        _showSnackBar(errorMessage, isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: const BackAppBar(title: 'Farm Store Setup'),
      body: Column(
        children: [
          if (_currentPosition == null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: SmartReTranslator(
                          text: 'Set Your Selling Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const SmartReTranslator(
                    text:
                        'To sell products, we need your exact selling location. Consumers will use this to:',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoPoint(Icons.straighten, 'Calculate distance'),
                  const SizedBox(height: 6),
                  _buildInfoPoint(Icons.directions_walk, 'Visit your location'),
                  const SizedBox(height: 6),
                  _buildInfoPoint(Icons.call, 'Contact for delivery'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: SmartReTranslator(
                            text:
                                'Be at your exact selling area before clicking "Get Location"',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          DisclaimerBanner(
            'Your selling location is visible to nearby users and cannot be changed later. Set it carefully — AGRHI is not responsible for consequences of sharing your location.',
          ),
          const SizedBox(height: 16),
          if (_currentPosition == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton.icon(
                onPressed: _isLoadingLocation
                    ? null
                    : _showAcknowledgmentDialog,
                icon: _isLoadingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location),
                label: SmartReTranslator(
                  text: _isLoadingLocation
                      ? 'Getting Location...'
                      : 'Get My Exact Location',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryGreen.withOpacity(
                    0.6,
                  ),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),

          if (_currentPosition != null)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.touch_app,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SmartReTranslator(
                              text:
                                  'Tap on map to adjust location (within 100m)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 300,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _currentPosition!,
                            initialZoom: _currentZoom,
                            minZoom: _currentZoom,
                            maxZoom: _currentZoom,
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                            onMapReady: () =>
                                setState(() => _isMapReady = true),
                            onTap: _onMapTap,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'app.agrhi.com',
                              maxZoom: 19,
                            ),
                            CircleLayer(circles: _buildCircles()),
                            MarkerLayer(markers: _buildMarkers()),
                          ],
                        ),
                      ),
                    ),

                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: AppColors.primaryGreen,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: SmartReTranslator(
                                  text: 'Your Selling Location',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_isLoadingAddress)
                            const Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                SizedBox(width: 10),
                                SmartReTranslator(
                                  text: 'Loading address...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              _currentAddress.isEmpty
                                  ? 'Address not available'
                                  : _currentAddress,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (_selectedPosition != null)
                            Text(
                              '${_selectedPosition!.latitude.toStringAsFixed(6)}, ${_selectedPosition!.longitude.toStringAsFixed(6)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: AppColors.textSecondary.withOpacity(0.7),
                              ),
                            ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isLoadingLocation
                                  ? null
                                  : _getCurrentLocation,
                              icon: const Icon(Icons.refresh, size: 20),
                              label: const SmartReTranslator(
                                text: 'Refresh',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                disabledForegroundColor: AppColors.primaryGreen
                                    .withOpacity(0.5),
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: _confirmLocation,
                              icon: const Icon(Icons.check_circle, size: 20),
                              label: const SmartReTranslator(
                                text: 'Confirm Location',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
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
