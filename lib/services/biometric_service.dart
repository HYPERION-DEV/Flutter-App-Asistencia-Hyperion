// lib/services/biometric_service.dart
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> autenticarUsuario() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Confirme su identidad biométrica para registrar su asistencia',
        options: const AuthenticationOptions(
          biometricOnly: true, // Forzar uso estricto de huella/rostro
          stickyAuth: true,     // Mantiene el diálogo si la app pasa a segundo plano brevemente
        ),
      );
    } catch (e) {
      return false;
    }
  }
}