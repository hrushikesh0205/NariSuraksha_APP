import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocationService
// ─────────────────────────────────────────────────────────────────────────────

/// Sealed result for a location permission check.
sealed class LocationPermissionResult {
  const LocationPermissionResult();
}

class LocationPermissionGranted extends LocationPermissionResult {
  const LocationPermissionGranted();
}

class LocationPermissionDenied extends LocationPermissionResult {
  const LocationPermissionDenied({this.forever = false});
  final bool forever;
}

class LocationServiceDisabled extends LocationPermissionResult {
  const LocationServiceDisabled();
}

// ─────────────────────────────────────────────────────────────────────────────

/// Application-level wrapper around [Geolocator].
///
/// Responsibilities:
/// - Permission checking and requesting.
/// - Fetching current device location with appropriate accuracy.
/// - Checking whether the device location service is enabled.
class LocationService {
  // ── Permission ─────────────────────────────────────────────────────────────

  /// Checks the current location permission state without requesting it.
  Future<LocationPermissionResult> checkPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationServiceDisabled();

    final permission = await Geolocator.checkPermission();
    switch (permission) {
      case LocationPermission.denied:
        return const LocationPermissionDenied();
      case LocationPermission.deniedForever:
        return const LocationPermissionDenied(forever: true);
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return const LocationPermissionGranted();
      default:
        return const LocationPermissionDenied();
    }
  }

  /// Requests location permission from the user.
  ///
  /// Returns [LocationPermissionGranted] only if the user grants access.
  Future<LocationPermissionResult> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return const LocationServiceDisabled();

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return const LocationPermissionGranted();
      case LocationPermission.deniedForever:
        return const LocationPermissionDenied(forever: true);
      default:
        return const LocationPermissionDenied();
    }
  }

  /// Whether the device location service is switched on.
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  // ── Location ───────────────────────────────────────────────────────────────

  /// Returns the current device position.
  ///
  /// Uses [LocationAccuracy.high] for SOS accuracy.
  /// Throws an [Exception] if permission is not granted or service is off.
  Future<Position> getCurrentPosition() async {
    final result = await requestPermission();
    if (result is! LocationPermissionGranted) {
      throw Exception(
        result is LocationServiceDisabled
            ? 'Location services are disabled.'
            : 'Location permission not granted.',
      );
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  /// Returns the last known position (fast, may be stale).
  ///
  /// Useful for quick location display without waiting for a fresh fix.
  Future<Position?> getLastKnownPosition() =>
      Geolocator.getLastKnownPosition();

  // ── Settings ───────────────────────────────────────────────────────────────

  /// Opens the device's app settings so the user can grant permission manually.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the device's location settings so the user can enable GPS.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
