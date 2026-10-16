// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);
  }

  /// Programa una alarma cuando falten 10 minutos para concluir la hora de descanso
  static Future<void> programarAlertaFinRefrigerio() async {
    const androidDetails = AndroidNotificationDetails(
      'refrigerio_channel',
      'Control de Refrigerio',
      channelDescription: 'Alertas de tiempo de descanso reglamentario de la jornada',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    // Suena a los 50 minutos (alerta preventiva) y a los 60 minutos
    await _notifications.zonedSchedule(
      101,
      '🍱 ¡Atención: Refrigerio por culminar!',
      'Le quedan 10 minutos para cumplir su hora de descanso y retornar a sus labores.',
      tz.TZDateTime.now(tz.local).add(const Duration(minutes: 50)),
      const NotificationDetails(android: androidDetails),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}