// lib/screens/attendance_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nfc_manager/nfc_manager.dart';

import '../services/biometric_service.dart';
import '../services/iso_attendance_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../theme/hyperion_colors.dart';
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

  // Acción seleccionada
  String _selectedActionType = 'CHECK_IN';

  // Control de acciones permitidas
  bool _hasCheckIn = false;
  bool _hasLunchStart = false;
  bool _hasLunchEnd = false;
  bool _hasCheckOut = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadoInicialDia();
  }

  /// Consulta al backend el estado del día para sincronizar botones si la app se reabre
  Future<void> _cargarEstadoInicialDia() async {
    setState(() => _isLoading = true);
    final res = await IsoAttendanceService.getTodayStatus(widget.userId);
    if (res['success'] == true && res['data'] != null) {
      final record = res['data']['record'];
      if (record != null) {
        setState(() {
          _hasCheckIn = record['checkIn'] != null;
          _hasLunchStart = record['lunchStart'] != null;
          _hasLunchEnd = record['lunchEnd'] != null;
          _hasCheckOut = record['checkOut'] != null;

          // Auto-seleccionar la siguiente acción lógica pendiente
          if (!_hasCheckIn) {
            _selectedActionType = 'CHECK_IN';
          } else if (!_hasLunchStart) {
            _selectedActionType = 'LUNCH_START';
          } else if (!_hasLunchEnd) {
            _selectedActionType = 'LUNCH_END';
          } else if (!_hasCheckOut) {
            _selectedActionType = 'CHECK_OUT';
          }
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  String get _actionLabel {
    switch (_selectedActionType) {
      case 'CHECK_IN': return 'Entrada';
      case 'LUNCH_START': return 'Inicio Refrigerio';
      case 'LUNCH_END': return 'Fin Refrigerio';
      case 'CHECK_OUT': return 'Salida';
      default: return 'Marcación';
    }
  }

  bool _validarAccionPermitida() {
    if (_selectedActionType != 'CHECK_IN' && !_hasCheckIn) {
      _mostrarMensaje('Debe registrar su ENTRADA antes de marcar refrigerio o salida.', Colors.orange);
      return false;
    }
    if (_selectedActionType == 'LUNCH_END' && !_hasLunchStart) {
      _mostrarMensaje('Debe registrar el INICIO DE REFRIGERIO primero.', Colors.orange);
      return false;
    }
    if (_selectedActionType == 'CHECK_OUT' && _hasLunchStart && !_hasLunchEnd) {
      _mostrarMensaje('Debe registrar el FIN DE REFRIGERIO antes de su salida.', Colors.orange);
      return false;
    }
    return true;
  }

  Future<void> _procesarMarcacion({
    required String type,
    String? qrContent,
    String? biometricToken,
  }) async {
    if (!_validarAccionPermitida()) return;

    setState(() => _isLoading = true);

    try {
      Position pos = await LocationService.obtenerUbicacionActual();

      final resultado = await IsoAttendanceService.postAttendance(
        userId: widget.userId,
        type: type,
        actionType: _selectedActionType,
        lat: pos.latitude,
        lng: pos.longitude,
        qrContent: qrContent,
        biometricToken: biometricToken,
      );

      if (resultado['success'] == true) {
        setState(() {
          if (_selectedActionType == 'CHECK_IN') _hasCheckIn = true;
          if (_selectedActionType == 'LUNCH_START') _hasLunchStart = true;
          if (_selectedActionType == 'LUNCH_END') _hasLunchEnd = true;
          if (_selectedActionType == 'CHECK_OUT') _hasCheckOut = true;
        });

        if (_selectedActionType == 'LUNCH_START') {
          await NotificationService.programarAlertaFinRefrigerio();
        }

        _mostrarMensaje('¡Marcación Registrada!\n${resultado['message']}', HyperionColors.successGreen);
      } else {
        _mostrarMensaje(resultado['message'], HyperionColors.dangerRed);
      }
    } catch (e) {
      _mostrarMensaje('Error al obtener coordenadas GPS: $e', HyperionColors.dangerRed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _marcarConQR() async {
    if (!_validarAccionPermitida()) return;
    final qrResultado = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerScreen()),
    );
    if (qrResultado != null && qrResultado.isNotEmpty) {
      await _procesarMarcacion(type: 'PRESENTIAL_QR', qrContent: qrResultado);
    }
  }

  Future<void> _marcarConNFC() async {
    if (!_validarAccionPermitida()) return;
    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      _mostrarMensaje('El Lector NFC no está activo en este dispositivo.', Colors.orange);
      return;
    }
    _mostrarMensaje('Aproxime la tarjeta o tag NFC al reverso del celular...', Colors.blue);
    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        NfcManager.instance.stopSession();
        await _procesarMarcacion(type: 'PRESENTIAL_NFC');
      },
    );
  }

  Future<void> _marcarConHuella() async {
    if (!_validarAccionPermitida()) return;
    bool autenticado = await BiometricService.autenticarUsuario();
    if (autenticado) {
      await _procesarMarcacion(type: 'BIOMETRIC_FINGERPRINT', biometricToken: 'fingerprint_ok');
    } else {
      _mostrarMensaje('Autenticación por huella fallida', Colors.orange);
    }
  }

  Future<void> _marcarConRostro() async {
    if (!_validarAccionPermitida()) return;
    final fotoPath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const FaceScannerScreen()),
    );
    if (fotoPath != null && fotoPath.isNotEmpty) {
      await _procesarMarcacion(type: 'FACIAL_RECOGNITION', biometricToken: 'facial_verified_ok');
    }
  }

  Future<void> _marcarHomeOffice() async {
    if (!_validarAccionPermitida()) return;
    await _procesarMarcacion(type: 'HOME_OFFICE');
  }

  void _mostrarMensaje(String text, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color, duration: const Duration(seconds: 4)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: HyperionColors.cyanAccent))
            : SingleChildScrollView(
          child: Column(
            children: [
              // ---------------------------------------------------
              // 1. CABECERA BRANDING HYPERION DIGITAL SECURITY
              // ---------------------------------------------------
              Container(
                padding: const EdgeInsets.all(24.0),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [HyperionColors.darkBackground, HyperionColors.primaryNavy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: HyperionColors.cyanAccent.withOpacity(0.5)),
                      ),
                      child: Image.asset(
                        'assets/images/Logo_Transparente.png',
                        height: 40,
                        width: 40,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.security, color: HyperionColors.cyanAccent, size: 36),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'HYPERION DIGITAL SECURITY',
                            style: TextStyle(
                              color: HyperionColors.cyanAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            'Hola, ${widget.userName}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ---------------------------------------------------
                    // 2. SELECTOR DE JORNADA ESTILIZADO
                    // ---------------------------------------------------
                    const Text(
                      'FASE DE LA JORNADA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: HyperionColors.primaryNavy,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 10),

                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment<String>(
                          value: 'CHECK_IN',
                          label: const Text('Entrada', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.login, size: 16),
                          enabled: !_hasCheckIn,
                        ),
                        ButtonSegment<String>(
                          value: 'LUNCH_START',
                          label: const Text('Ini. Ref', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.restaurant, size: 16),
                          enabled: _hasCheckIn && !_hasLunchStart,
                        ),
                        ButtonSegment<String>(
                          value: 'LUNCH_END',
                          label: const Text('Fin Ref', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.work_history, size: 16),
                          enabled: _hasLunchStart && !_hasLunchEnd,
                        ),
                        ButtonSegment<String>(
                          value: 'CHECK_OUT',
                          label: const Text('Salida', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          icon: const Icon(Icons.logout, size: 16),
                          enabled: _hasCheckIn && !_hasCheckOut,
                        ),
                      ],
                      selected: {_selectedActionType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => _selectedActionType = newSelection.first);
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return HyperionColors.primaryNavy;
                          }
                          return Colors.white;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                          if (states.contains(WidgetState.selected)) {
                            return HyperionColors.cyanAccent;
                          }
                          return const Color(0xFF334155);
                        }),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Text(
                      'MÉTODOS DE AUTENTICACIÓN SECURE-ID',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: HyperionColors.primaryNavy,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ---------------------------------------------------
                    // 3. TARJETAS DE MARCACIÓN HYPERION
                    // ---------------------------------------------------
                    _buildHyperionButton(
                      icon: Icons.qr_code_scanner,
                      label: 'Escanear QR Oficina',
                      sublabel: 'Acreditación presencial mediante tótem digital',
                      color: HyperionColors.primaryNavy,
                      onPressed: _marcarConQR,
                    ),
                    const SizedBox(height: 12),

                    _buildHyperionButton(
                      icon: Icons.nfc,
                      label: 'Tarjeta Smart NFC',
                      sublabel: 'Aproximación con credencial corporativa',
                      color: const Color(0xFF0F766E),
                      onPressed: _marcarConNFC,
                    ),
                    const SizedBox(height: 12),

                    _buildHyperionButton(
                      icon: Icons.fingerprint,
                      label: 'Huella Dactilar Criptográfica',
                      sublabel: 'Validación biométrica mediante sensor nativo',
                      color: const Color(0xFF0284C7),
                      onPressed: _marcarConHuella,
                    ),
                    const SizedBox(height: 12),

                    _buildHyperionButton(
                      icon: Icons.face,
                      label: 'Reconocimiento Facial + Liveness',
                      sublabel: 'Escaneo facial con detección de parpadeo',
                      color: const Color(0xFF6D28D9),
                      onPressed: _marcarConRostro,
                    ),
                    const SizedBox(height: 12),

                    _buildHyperionButton(
                      icon: Icons.home_work_rounded,
                      label: 'Home Office Remoto (Geocerca)',
                      sublabel: 'Validación GPS en vivienda autorizada',
                      color: const Color(0xFFD97706),
                      onPressed: _marcarHomeOffice,
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 10),

                    // 👈 AQUÍ ESTÁ EL CAMBIO DEL BOTÓN
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RegisterHomeScreen(userId: widget.userId),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        side: const BorderSide(color: HyperionColors.primaryNavy, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_location_alt, color: HyperionColors.primaryNavy),
                          SizedBox(width: 8),
                          Text(
                            'Registrar Nuevo Domicilio (Home Office)',
                            style: TextStyle(
                              color: HyperionColors.primaryNavy,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHyperionButton({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$label ($_actionLabel)',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: HyperionColors.darkBackground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}