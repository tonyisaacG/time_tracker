import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationAction {
  final String actionId;
  final String? payload;

  NotificationAction({required this.actionId, this.payload});
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  final StreamController<NotificationAction> _actionController = StreamController<NotificationAction>.broadcast();
  Stream<NotificationAction> get onActionClick => _actionController.stream;

  Future<void> init() async {
    // 1. Initialize timezone database
    tz.initializeTimeZones();
    final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // 2. Configure Android & iOS settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}, actionId: ${response.actionId}");
        if (response.actionId != null) {
          _actionController.add(NotificationAction(
            actionId: response.actionId!,
            payload: response.payload,
          ));
        } else {
          _actionController.add(NotificationAction(
            actionId: 'select',
            payload: response.payload,
          ));
        }
      },
    );

    // Create android notification channel
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      'schedule_reminders_channel',
      'Reminders & Meetings',
      description: 'Notifications for scheduled courses, meetings and appointments',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]), // Custom vibration pattern
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> requestPermissions() async {
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<NotificationAppLaunchDetails?> getLaunchDetails() {
    return _localNotifications.getNotificationAppLaunchDetails();
  }

  // Generate unique integer ID based on UUID/String hash
  int _generateNotificationId(String id) {
    return id.hashCode & 0x7FFFFFFF;
  }

  Future<void> scheduleAppointment({
    required String id,
    required String title,
    required String body,
    required DateTime startTime,
    required String recurrenceType, // 'once', 'weekly', 'monthly'
    required List<int> recurrenceDays, // ISO weekdays [1..7] (1 = Monday, 7 = Sunday)
  }) async {
    final int notifyId = _generateNotificationId(id);

    // Cancel existing reminder if any
    await cancelNotification(id);

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(startTime, tz.local);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'schedule_reminders_channel',
      'Reminders & Meetings',
      channelDescription: 'Notifications for scheduled courses, meetings and appointments',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'start_tracking',
          'Start Tracking Now',
          icon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          showsUserInterface: true,
        ),
      ],
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (recurrenceType == 'once') {
      if (scheduledDate.isAfter(now)) {
        try {
          await _localNotifications.zonedSchedule(
            notifyId,
            title,
            body,
            scheduledDate,
            platformDetails,
            payload: id,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {
          await _localNotifications.zonedSchedule(
            notifyId,
            title,
            body,
            scheduledDate,
            platformDetails,
            payload: id,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    } else if (recurrenceType == 'weekly') {
      // For weekly recurring on specific days, schedule a notification for each day
      for (final day in recurrenceDays) {
        final dayNotifyId = _generateNotificationId('$id-$day');
        
        // Find next occurrence of this weekday
        tz.TZDateTime firstSchedule = _nextInstanceOfWeekdayAndTime(
          scheduledDate.hour,
          scheduledDate.minute,
          day,
        );

        try {
          await _localNotifications.zonedSchedule(
            dayNotifyId,
            title,
            body,
            firstSchedule,
            platformDetails,
            payload: id,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (_) {
          await _localNotifications.zonedSchedule(
            dayNotifyId,
            title,
            body,
            firstSchedule,
            platformDetails,
            payload: id,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    } else if (recurrenceType == 'monthly') {
      // Schedule monthly recurring notification
      tz.TZDateTime firstSchedule = scheduledDate;
      if (firstSchedule.isBefore(now)) {
        // Find next month's instance
        firstSchedule = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          scheduledDate.day,
          scheduledDate.hour,
          scheduledDate.minute,
        );
        if (firstSchedule.isBefore(now)) {
          firstSchedule = firstSchedule.add(const Duration(days: 30)); // Rough estimate, zonedSchedule handles it monthly
        }
      }

      try {
        await _localNotifications.zonedSchedule(
          notifyId,
          title,
          body,
          firstSchedule,
          platformDetails,
          payload: id,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      } catch (_) {
        await _localNotifications.zonedSchedule(
          notifyId,
          title,
          body,
          firstSchedule,
          platformDetails,
          payload: id,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        );
      }
    }
  }

  Future<void> cancelNotification(String id) async {
    // Cancel the main notification ID
    await _localNotifications.cancel(_generateNotificationId(id));

    // Cancel all day-specific sub-notifications for weekly repeats
    for (int day = 1; day <= 7; day++) {
      await _localNotifications.cancel(_generateNotificationId('$id-$day'));
    }
  }

  // Calculate next instance of specific weekday (1 = Monday, 7 = Sunday) at specific hour/minute
  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int hour, int minute, int weekday) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> scheduleTaskReminder({
    required String id,
    required String title,
    required DateTime reminderTime,
  }) async {
    final int notifyId = _generateNotificationId('task-$id');
    await cancelTaskReminder(id);

    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    if (!scheduledDate.isAfter(now)) return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'schedule_reminders_channel',
      'Reminders & Meetings',
      channelDescription: 'Notifications for scheduled courses, meetings and appointments',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _localNotifications.zonedSchedule(
        notifyId,
        'تذكير بالمهمة: $title',
        'حان الموعد المحدد لهذه المهمة!',
        scheduledDate,
        platformDetails,
        payload: id,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _localNotifications.zonedSchedule(
        notifyId,
        'تذكير بالمهمة: $title',
        'حان الموعد المحدد لهذه المهمة!',
        scheduledDate,
        platformDetails,
        payload: id,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTaskReminder(String id) async {
    await _localNotifications.cancel(_generateNotificationId('task-$id'));
  }

  // Schedule a weekly notification on Sunday at 6 PM listing neglected target activities
  Future<void> scheduleWeeklyReportSummaryReminder({
    required List<String> neglectedNames,
  }) async {
    const int notifyId = 999999; // Unique static ID for weekly neglected reminder
    await _localNotifications.cancel(notifyId);

    if (neglectedNames.isEmpty) return;

    // Schedule next Sunday at 6 PM
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 18, 0); // 6:00 PM

    // If it's already past 6 PM Sunday, schedule for next Sunday
    while (scheduledDate.weekday != DateTime.sunday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'schedule_reminders_channel',
      'Reminders & Meetings',
      channelDescription: 'Notifications for scheduled courses, meetings and appointments',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final String neglectedListStr = neglectedNames.join(', ');
    final String body = 'Don\'t forget your targets! You haven\'t spent any time on: $neglectedListStr this week.';

    try {
      await _localNotifications.zonedSchedule(
        notifyId,
        'Neglected Activities Alert ⚠️',
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    } catch (_) {
      await _localNotifications.zonedSchedule(
        notifyId,
        'Neglected Activities Alert ⚠️',
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }
}
