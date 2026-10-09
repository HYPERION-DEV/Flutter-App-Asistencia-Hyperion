// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:safe_device/safe_device.dart';

class LocationService {
  /// Obtiene la posición GPS real actual del dispositivo
  static Future<Position> obtenerUbicacionActual() async {
    // 1. Protección Anti-Fraud: Detectar si el usuario simula el GPS
    bool isMockLocation = await SafeDevice.isMockLocation;
    if (isMockLocation) {
      throw Exception('Se detectó el uso de GPS Falso / Mock Location. Desactive las aplicaciones de simulación para marcar.');
    }

    // 2. Verificar que el sensor GPS esté encendido
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('El GPS está desactivado. Por favor, actívelo en las configuraciones de su teléfono.');
    }

    // 3. Verificar y solicitar permisos de ubicación
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Se requieren permisos de ubicación para validar su marcación.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Los permisos de GPS están denegados permanentemente. Habilítelos desde los Ajustes del dispositivo.');
    }

    // 4. Retornar las coordenadas actuales con alta precisión
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }
}