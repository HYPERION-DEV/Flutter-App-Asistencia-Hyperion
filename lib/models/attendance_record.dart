enum AttendanceType { qr, nfc, homeOffice }

class AttendanceRecord {
  final DateTime timestamp;
  final AttendanceType type;
  final String deviceId;

  AttendanceRecord({
    required this.timestamp,
    required this.type,
    required this.deviceId,
  });
}