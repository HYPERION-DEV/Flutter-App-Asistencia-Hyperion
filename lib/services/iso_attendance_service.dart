import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';

class IsoAttendanceService {
  static const String baseUrl = 'http://192.168.1.171:3000/api/v1';
  static final LocalAuthentication _localAuth = LocalAuthentication();

  static Future<bool> marcarConBiometriaISO({
    required String userId,
    required String attendanceType,
    required String signatureBase64,
  }) async {
    // 1. Autenticación biométrica local usando la firma estándar compatible de local_auth
    bool autenticado = false;
    try {
      autenticado = await _localAuth.authenticate(
        localizedReason: 'Confirme su identidad para registrar asistencia',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      // Fallback para versiones de local_auth con parámetros directos
      autenticado = await _localAuth.authenticate(
        localizedReason: 'Confirme su identidad para registrar asistencia',
      );
    }

    if (!autenticado) {
      throw Exception('Autenticación biométrica fallida o cancelada.');
    }

    String biometricToken = 'HW_SECURE_TOKEN_${DateTime.now().millisecondsSinceEpoch}';

    // 2. Captura de GPS puntual
    Position pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    // 3. Envío seguro al backend
    final response = await http.post(
      Uri.parse('$baseUrl/attendance'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': userId,
        'type': attendanceType,
        'lat': pos.latitude,
        'lng': pos.longitude,
        'signature': signatureBase64,
        'biometricToken': biometricToken,
      }),
    );

    if (response.statusCode == 200) {
      return true;
    } else {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'Error registrando marcación.');
    }
  }
}