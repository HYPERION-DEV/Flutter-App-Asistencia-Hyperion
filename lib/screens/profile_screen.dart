// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main.dart';
import 'create_permission_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;
  final String userName;

  const ProfileScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  Future<void> _cerrarSesion(BuildContext context) async {
    final storage = const FlutterSecureStorage();

    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Está seguro de que desea cerrar sesión en este dispositivo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await storage.deleteAll();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DniLoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil de Empleado'),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.indigo,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('ID/DNI: $userId', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            const Divider(),

            // Información Laboral
            const ListTile(
              leading: Icon(Icons.business, color: Colors.indigo),
              title: Text('Empresa'),
              subtitle: Text('Hyperion Digital Security S.A.C.'),
            ),
            const ListTile(
              leading: Icon(Icons.schedule, color: Colors.indigo),
              title: Text('Horario de Trabajo'),
              subtitle: Text('09:00 AM - 06:00 PM (1h Refrigerio)'),
            ),

            const Divider(),

            // 🎯 NUEVO: OPCIÓN PARA SOLICITAR PERMISOS Y PAPELETAS
            Card(
              elevation: 0,
              color: const Color(0xFF005F87).withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF005F87), width: 1),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF005F87),
                  child: Icon(Icons.assignment_add, color: Colors.white, size: 20),
                ),
                title: const Text(
                  'Solicitar Permiso / Papeleta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF005F87)),
                ),
                subtitle: const Text('Descansos médicos, papeletas de salida y licencias con firma digital'),
                trailing: const Icon(Icons.chevron_right, color: Color(0xFF005F87)),
                onTap: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreatePermissionScreen(userId: userId),
                    ),
                  );

                  if (result == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Solicitud y papeleta enviada a RRHH correctamente.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 30),

            // Botón de Cerrar Sesión
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _cerrarSesion(context),
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Cerrar Sesión del Dispositivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}