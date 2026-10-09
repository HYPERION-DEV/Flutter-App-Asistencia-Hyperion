import 'package:flutter/material.dart';
import '../models/attendance_record.dart';

class AttendanceProvider extends ChangeNotifier {
  int _homeOfficeRemaining = 4;
  final List<AttendanceRecord> _records = [];

  int get homeOfficeRemaining => _homeOfficeRemaining;
  List<AttendanceRecord> get records => List.unmodifiable(_records);

  bool registerHomeOffice() {
    if (_homeOfficeRemaining > 0) {
      _homeOfficeRemaining--;
      _records.add(
        AttendanceRecord(
          timestamp: DateTime.now(),
          type: AttendanceType.homeOffice,
          deviceId: 'DEV-8829-MOCK',
        ),
      );
      notifyListeners();
      return true;
    }
    return false;
  }

  void registerPresential(AttendanceType type) {
    _records.add(
      AttendanceRecord(
        timestamp: DateTime.now(),
        type: type,
        deviceId: 'DEV-8829-MOCK',
      ),
    );
    notifyListeners();
  }
}