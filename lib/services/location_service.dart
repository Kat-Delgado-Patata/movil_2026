import 'package:geolocator/geolocator.dart';

class LocationException implements Exception {
  LocationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Envuelve `geolocator` con mensajes en español listos para mostrar en la UI.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  /// Ubicación actual del dispositivo, pidiendo permiso si todavía no se otorgó.
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationException('Activa el GPS de tu dispositivo para continuar.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Otorga permiso de ubicación a AsistApp para continuar.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
        'El permiso de ubicación está bloqueado. Habilítalo desde los ajustes del sistema.',
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)),
      );
    } catch (_) {
      throw LocationException('No se pudo obtener tu ubicación. Intenta nuevamente.');
    }
  }

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();

  double distanceInMeters({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }
}
