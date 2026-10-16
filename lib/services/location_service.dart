// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:safe_device/safe_device.dart';

class LocationService {
  static Future<Position> obtenerUbicacionActual() async {
    // 1. Anti-Fraud: Detectar aplicaciones de Fake GPS / Mock Location
    bool isMockLocation = await SafeDevice.isMockLocation;
    if (isMockLocation) {
      throw Exception('Se detectó simulación de ubicación (Fake GPS). Desactive estas apps para continuar.');
    }

    // 2. Verificar que el sensor GPS físico esté encendido
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El GPS está desactivado. Actívelo en la barra de notificaciones.');
    }

    // 3. Permisos de Ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Se requiere permiso de ubicación para registrar su marcación.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permiso de GPS denegado permanentemente. Actívelo desde los Ajustes del sistema.');
    }

    // 4. Obtención de Coordenadas Físicas Frescas con Tiempo Límite de 10 Segundos
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10), // 👈 Previene que la app se quede congelada si el satélite no engancha
      ),
    );
  }
}