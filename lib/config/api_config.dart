// lib/config/api_config.dart
class ApiConfig {
  // Reemplaza por la IP actual que te dio ipconfig
  static const String _host = '192.168.1.37'; // 👈 Coloca tu IP aquí
  static const String _port = '3000';

  static String get baseUrl => 'http://$_host:$_port/api/v1';
}