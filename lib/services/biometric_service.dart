import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> autenticarUsuario() async {
    try {
      // Verificar si el dispositivo soporta biometría
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        return false;
      }

      // Solicitar la huella / rostro
      return await _auth.authenticate(
        localizedReason: 'Autentíquese para registrar su asistencia',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }
}