// lib/services/permission_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PermissionService {
  /// Obtener historial de permisos del colaborador
  static Future<List<dynamic>> getUserPermissions(String userId) async {
    try {
      final response = await http
          .get(
        Uri.parse('${ApiConfig.baseUrl}/hr/permissions?userId=$userId'),
        headers: {'Content-Type': 'application/json'},
      )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['permissions'] ?? [];
      }
      return [];
    } catch (e) {
      print('Error en PermissionService.getUserPermissions: $e');
      return [];
    }
  }

  /// Registrar solicitud con firma Base64
  static Future<Map<String, dynamic>> createPermission({
    required String userId,
    required String type,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
    required String signatureBase64,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/hr/permissions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'type': type,
          'reason': reason,
          'startDate': startDate.toIso8601String(),
          'endDate': endDate.toIso8601String(),
          'signatureBase64': signatureBase64,
        }),
      )
          .timeout(const Duration(seconds: 12));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'permission': data['permission']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Error registrando el permiso (${response.statusCode})'
        };
      }
    } on TimeoutException {
      return {
        'success': false,
        'error': 'Tiempo de espera agotado. Verifique la IP en ApiConfig.baseUrl.'
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'No se pudo conectar con el servidor ($e)'
      };
    }
  }
}