import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tzdata.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );
  }

  static Future<void> scheduleAppointmentReminder({
    required int id,
    required String doctorName,
    required String purpose,
    required DateTime appointmentTime,
    required int minutesBefore,
  }) async {
    final reminderTime = appointmentTime.subtract(Duration(minutes: minutesBefore));
    if (reminderTime.isBefore(DateTime.now())) return;

    final String timeLabel = minutesBefore == 60 ? '1 hour' : '1 day';

    await _plugin.zonedSchedule(
      id: id,
      title: 'Upcoming Appointment',
      body: '$timeLabel reminder: $purpose with $doctorName',
      scheduledDate: tz.TZDateTime.from(reminderTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointments_channel',
          'Appointment Reminders',
          channelDescription: 'Reminders for upcoming appointments',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  static Future<void> cancelReminder(int id) async {
    await _plugin.cancel(id: id);
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static int notificationIdFromAppointmentId(int appointmentId) {
    return appointmentId % 100000;
  }
}
