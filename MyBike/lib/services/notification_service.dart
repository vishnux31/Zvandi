import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_service.dart';

/// Thin, defensive wrapper around flutter_local_notifications.
///
/// Everything is guarded so that a missing platform capability never crashes
/// the app; notifications are a nice-to-have on top of the in-app reminders.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'service_reminders';
  static const _channelName = 'Service Reminders';

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings();
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: darwin),
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Upcoming and overdue bike maintenance',
              importance: Importance.high,
            ),
          );
      _ready = true;
    } catch (e) {
      debugPrint('NotificationService init failed: $e');
    }
  }

  Future<void> requestPermissions() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('NotificationService permission request failed: $e');
    }
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Re-schedules date-based reminders for all items with an upcoming due date.
  Future<void> syncReminders(List<ReminderInfo> reminders) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      for (final r in reminders) {
        final due = r.item.nextDueDate;
        if (due == null) continue;
        // Notify a week before the due date (or now if already within a week).
        var when = due.subtract(const Duration(days: 7));
        if (when.isBefore(now)) {
          if (due.isBefore(now)) continue; // already overdue, shown in-app
          when = now.add(const Duration(seconds: 5));
        }
        await _plugin.zonedSchedule(
          r.item.id.hashCode & 0x7fffffff,
          '${r.item.name} due soon',
          '${r.bike.name}: ${r.item.type.label} is due on '
              '${due.day}/${due.month}/${due.year}',
          tz.TZDateTime.from(when, tz.local),
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('NotificationService sync failed: $e');
    }
  }
}
