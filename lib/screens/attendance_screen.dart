import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:nfc_manager/nfc_manager.dart';

import '../services/biometric_service.dart';
import '../services/location_service.dart';
import 'face_scanner_screen.dart';
import 'qr_scanner_screen.dart';
import 'register_home_screen.dart';

class AttendanceScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const AttendanceScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isLoading = false;

  // Estado para la acción seleccionada: CHECK_IN, CHECK_OUT, LUNCH_START, LUNCH_END
  String _selectedActionType = 'CHECK_IN';

  // URL Base de tu API Next.js en la red local
  final String baseUrl = 'http://192.168.1.171:3000/api/v1';

  // ---------------------------------------------------------
  // Método centralizado para procesar la marcación
  // ---------------------------------------------------------
  Future<void> _procesarMarcacion({
    required String type,
    String? qrContent,
    String? biometricToken,
  }) async {
    setState(() => _isLoading = true);

    try {
      Position pos = await LocationService.obtenerUbicacionActual();

      final response = await http.post(
        Uri.parse('$baseUrl/attendance'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'type': type,
          'actionType': _selectedActionType, // 👈 Se envía dinámicamente la acción
          'lat': pos.latitude,
          'lng': pos.longitude,
          'qrContent': qrContent,
          'biometricToken': biometricToken,
        }),
      );

      final resData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarMensaje('¡Marcación Registrada!\n${resData['message']}', Colors.green);
      } else {
        _mostrarMensaje(resData['error'] ?? 'Error al procesar la marcación', Colors.red);
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión con el servidor', Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------
  // Opciones de Marcación
  // ---------------------------------------------------------

  // 1. Escanear QR Oficina
  Future<void> _marcarConQR() async {
    final qrResultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );

    if (qrResultado != null && qrResultado.isNotEmpty) {
      await _procesarMarcacion(type: 'PRESENTIAL_QR', qrContent: qrResultado);
    }
  }

  // 2. Tarjeta NFC Oficina
  Future<void> _marcarConNFC() async {
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _mostrarMensaje(
        'El Lector NFC no está activo en este dispositivo.',
        Colors.orange,
      );
      return;
    }

    _mostrarMensaje(
      'Aproxime la tarjeta o tag NFC al reverso del celular...',
      Colors.blue,
    );

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        await _procesarMarcacion(type: 'PRESENTIAL_NFC');
      },
    );
  }

  // 3. Marcación por Huella Dactilar
  Future<void> _marcarConHuella() async {
    bool autenticado = await BiometricService.autenticarUsuario();
    if (autenticado) {
      await _procesarMarcacion(
        type: 'BIOMETRIC_FINGERPRINT',
        biometricToken: 'fingerprint_ok',
      );
    } else {
      _mostrarMensaje('Autenticación por huella fallida', Colors.orange);
    }
  }

  // 4. Marcación por Reconocimiento Facial (Cámara Frontal)
  Future<void> _marcarConRostro() async {
    final fotoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const FaceScannerScreen()),
    );

    if (fotoPath != null && fotoPath.isNotEmpty) {
      await _procesarMarcacion(
        type: 'FACIAL_RECOGNITION',
        biometricToken: 'facial_verified_ok',
      );
    }
  }

  // 5. Marcación Remota (Home Office)
  Future<void> _marcarHomeOffice() async {
    await _procesarMarcacion(type: 'HOME_OFFICE');
  }

  void _mostrarMensaje(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bienvenido, ${widget.userName}'),
        backgroundColor: Colors.indigo.shade800,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -------------------------------------------------------
            // SELECTOR DE TIPO DE ACCIÓN (ENTRADA / SALIDA)
            // -------------------------------------------------------
            const Text(
              'Tipo de Marcación:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'CHECK_IN',
                  label: Text('Entrada'),
                  icon: Icon(Icons.login),
                ),
                ButtonSegment<String>(
                  value: 'CHECK_OUT',
                  label: Text('Salida'),
                  icon: Icon(Icons.logout),
                ),
              ],
              selected: {_selectedActionType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedActionType = newSelection.first;
                });
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(WidgetState.selected)) {
                      return _selectedActionType == 'CHECK_IN'
                          ? Colors.green.shade700
                          : Colors.red.shade700;
                    }
                    return Colors.grey.shade200;
                  },
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color>(
                      (states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return Colors.black87;
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),

            const Text(
              'Métodos de Marcación Disponibles:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            // Botón 1: Escanear QR Oficina
            ElevatedButton.icon(
              onPressed: _marcarConQR,
              icon: const Icon(Icons.qr_code_scanner),
              label: Text('Escanear QR ($_selectedActionType)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Botón 2: Marcación por Tarjeta NFC
            ElevatedButton.icon(
              onPressed: _marcarConNFC,
              icon: const Icon(Icons.nfc),
              label: Text('Tarjeta NFC ($_selectedActionType)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Botón 3: Huella Dactilar
            ElevatedButton.icon(
              onPressed: _marcarConHuella,
              icon: const Icon(Icons.fingerprint),
              label: Text('Huella Dactilar ($_selectedActionType)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Botón 4: Reconocimiento Facial
            ElevatedButton.icon(
              onPressed: _marcarConRostro,
              icon: const Icon(Icons.face),
              label: Text('Reconocimiento Facial ($_selectedActionType)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: Colors.purple.shade700,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),

            // Botón 5: Marcar Home Office
            ElevatedButton.icon(
              onPressed: _marcarHomeOffice,
              icon: const Icon(Icons.home_work),
              label: Text('Home Office ($_selectedActionType)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 10),

            // Botón 6: Registrar Nuevo Domicilio
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RegisterHomeScreen(userId: widget.userId),
                  ),
                );
              },
              icon: const Icon(Icons.add_location_alt),
              label: const Text(
                'Registrar Nuevo Domicilio (Home Office)',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}