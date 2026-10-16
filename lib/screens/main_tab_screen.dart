// lib/screens/main_tab_screen.dart
import 'package:flutter/material.dart';
import 'attendance_screen.dart';
import 'create_permission_screen.dart';
import 'profile_screen.dart';

class MainTabScreen extends StatefulWidget {
  final String userId;
  final String userName;

  const MainTabScreen({
    Key? key,
    required this.userId,
    required this.userName,
  }) : super(key: key);

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Inicializar la lista de vistas una sola vez para mantener vivos sus State
    _pages = [
      AttendanceScreen(userId: widget.userId, userName: widget.userName),
      CreatePermissionScreen(
        userId: widget.userId,
        onSuccess: () {
          if (mounted) {
            setState(() => _currentIndex = 0); // Cambiar a pestaña Asistencia
          }
        },
      ),
      ProfileScreen(userId: widget.userId, userName: widget.userName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.indigo.shade800,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.touch_app),
            label: 'Asistencia',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_add),
            label: 'Permisos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Mi Perfil',
          ),
        ],
      ),
    );
  }
}