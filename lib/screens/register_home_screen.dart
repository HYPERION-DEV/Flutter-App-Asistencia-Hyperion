// lib/screens/register_home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../services/location_service.dart';

class RegisterHomeScreen extends StatefulWidget {
  final String userId;

  const RegisterHomeScreen({super.key, required this.userId});

  @override
  State<RegisterHomeScreen> createState() => _RegisterHomeScreenState();
}

class _RegisterHomeScreenState extends State<RegisterHomeScreen> {
  final _aliasController = TextEditingController(text: 'Casa Principal');
  final _addressRefController = TextEditingController();
  Position? _currentPosition;
  bool _isLoadingGps = false;
  bool _isSaving = false;

  final String baseUrl = 'http://192.168.1.171:3000/api/v1';

  Future<void> _obtenerUbicacionGPS() async {
    setState(() => _isLoadingGps = true);
    try {
      Position pos = await LocationService.obtenerUbicacionActual();
      setState(() => _currentPosition = pos);
      _mostrarSnackBar('Coordenadas GPS capturadas con éxito', Colors.green);
    } catch (e) {
      _mostrarSnackBar('Error al obtener GPS: $e', Colors.red);
    } finally {
      setState(() => _isLoadingGps = false);
    }
  }

  Future<void> _guardarDomicilio() async {
    if (_currentPosition == null) {
      _mostrarSnackBar('Primero debe obtener las coordenadas GPS de su vivienda', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/home-address'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'alias': _aliasController.text.trim(),
          'lat': _currentPosition!.latitude,
          'lng': _currentPosition!.longitude,
          'addressReference': _addressRefController.text.trim(),
        }),
      );

      final resData = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarSnackBar('¡Domicilio registrado correctamente para Home Office!', Colors.green);
        if (mounted) Navigator.pop(context);
      } else {
        _mostrarSnackBar(resData['error'] ?? 'Error al registrar el domicilio', Colors.red);
      }
    } catch (e) {
      _mostrarSnackBar('Error de conexión con el servidor', Colors.red);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarSnackBar(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Domicilio Home Office'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.home_work, size: 70, color: Colors.indigo),
            const SizedBox(height: 16),
            const Text(
              'Ubicación de la Vivienda',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Asegúrese de estar FÍSICAMENTE en su vivienda al momento de presionar el botón de captura de GPS.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _aliasController,
              decoration: const InputDecoration(
                labelText: 'Alias del Domicilio',
                hintText: 'Ej: Casa Principal, Departamento',
                prefixIcon: Icon(Icons.bookmark),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _addressRefController,
              decoration: const InputDecoration(
                labelText: 'Dirección o Referencia (Opcional)',
                hintText: 'Ej: Av. San Martin 123 - Dpto 402',
                prefixIcon: Icon(Icons.map),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Tarjeta de Estado del GPS
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _currentPosition == null
                          ? 'GPS: No capturado'
                          : 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentPosition == null ? Colors.red : Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _isLoadingGps
                        ? const CircularProgressIndicator()
                        : ElevatedButton.icon(
                      onPressed: _obtenerUbicacionGPS,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Capturar GPS de Mi Casa'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _guardarDomicilio,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(15),
                backgroundColor: Colors.indigo.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('Guardar Domicilio Autorizado', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}