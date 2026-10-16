// lib/services/iso_attendance_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class IsoAttendanceService {
  /// 1. Consulta el estado del ciclo de hoy para habilitar/deshabilitar botones
  static Future<Map<String, dynamic>> getTodayStatus(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/attendance/today?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final isJson = response.headers['content-type']?.contains('application/json') ?? false;
      if (isJson && response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'data': null};
    } catch (e) {
      return {'success': false, 'data': null};
    }
  }

  /// 2. Envío inalterable de la marcación (Garantizando latitud/longitud en String)
  static Future<Map<String, dynamic>> postAttendance({
    required String userId,
    required String type,
    required String actionType,
    required double lat,
    required double lng,
    String? signature,
    String? qrContent,
    String? biometricToken,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/attendance');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'type': type,
          'actionType': actionType,
          'lat': lat.toString(), // 👈 Evita errores de tipo numérico en Next.js
          'lng': lng.toString(),
          'signature': signature,
          'qrContent': qrContent,
          'biometricToken': biometricToken,
        }),
      );

      final isJson = response.headers['content-type']?.contains('application/json') ?? false;

      if (isJson) {
        final data = jsonDecode(response.body);
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, 'message': data['message'] ?? 'Marcación registrada con éxito', 'data': data};
        } else {
          return {'success': false, 'message': data['error'] ?? 'Error en la solicitud'};
        }
      } else {
        return {
          'success': false,
          'message': 'Respuesta no válida del servidor (${response.statusCode}). Verifique la conexión con Next.js.'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error de conexión o red: ${e.toString().replaceAll('Exception: ', '')}'};
    }
  }
}