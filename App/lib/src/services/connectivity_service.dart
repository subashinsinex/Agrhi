// lib/src/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetConnection = InternetConnection();

  /// Check if device has internet connection
  Future<bool> hasInternetConnection() async {
    try {
      // Check connectivity status
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        return false;
      }

      // Verify actual internet access
      final hasInternet = await _internetConnection.hasInternetAccess;
      return hasInternet;
    } catch (e) {
      return false;
    }
  }

  /// Stream to listen to connectivity changes
  Stream<bool> get onConnectivityChanged {
    return _internetConnection.onStatusChange.map((status) {
      return status == InternetStatus.connected;
    });
  }
}
