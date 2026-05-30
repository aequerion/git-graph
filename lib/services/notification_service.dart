import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../services/github_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _reminderEnabledKey = 'reminder_enabled';
  static const int _morningReminderId = 1;
  static const int _eveningReminderId = 2;

  // Fixed notification times
  static const int _morningHour = 7;
  static const int _morningMinute = 0;
  static const int _eveningHour = 23; // 11 PM
  static const int _eveningMinute = 0;

  /// Initialize the notification service
  static Future<void> initialize() async {
    // Initialize timezone
    tz.initializeTimeZones();
    String timeZoneName = await FlutterTimezone.getLocalTimezone();
    
    // Handle legacy timezone names
    if (timeZoneName == 'Asia/Calcutta') {
      timeZoneName = 'Asia/Kolkata';
    }
    
    try {
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // Fallback to UTC if timezone not found
      debugPrint('Timezone $timeZoneName not found, using UTC');
      tz.setLocalLocation(tz.UTC);
    }

    // Android initialization settings with custom notification icon
    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');

    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    // App will open when notification is tapped
    debugPrint('Notification tapped: ${response.payload}');
  }

  /// Request notification permissions (Android 13+)
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Check if reminders are enabled
  static Future<bool> isReminderEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_reminderEnabledKey) ?? false;
  }

  /// Save reminder settings
  static Future<void> saveReminderSettings({required bool enabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reminderEnabledKey, enabled);

    if (enabled) {
      await scheduleDailyReminders();
    } else {
      await cancelAllReminders();
    }
  }

  /// Schedule both daily reminder notifications (7 AM and 11 PM)
  static Future<void> scheduleDailyReminders() async {
    // Cancel any existing reminders first
    await cancelAllReminders();

    // Schedule morning reminder (7:00 AM)
    await _scheduleMorningReminder();

    // Schedule evening reminder (11:00 PM)
    await _scheduleEveningReminder();

    debugPrint('Daily reminders scheduled: 7:00 AM and 11:00 PM');
  }

  /// Schedule morning reminder at 7:00 AM with positive message
  static Future<void> _scheduleMorningReminder() async {
    const androidDetails = AndroidNotificationDetails(
      'morning_reminder',
      'Morning Contribution Reminder',
      channelDescription: 'Morning reminder to start your day with contributions',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFF238636),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = _getNextScheduledTime(_morningHour, _morningMinute);
    final message = _getRandomMorningMessage();

    await _notifications.zonedSchedule(
      _morningReminderId,
      'Start Your Day Right',
      message,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'morning_reminder',
    );
  }

  /// Schedule evening reminder at 11:00 PM with urgent message
  /// This notification will only be shown if the user has NOT contributed today
  static Future<void> _scheduleEveningReminder() async {
    // Skip scheduling if the user has already contributed today
    final hasContributed = await GitHubService.hasContributedToday();
    if (hasContributed) {
      debugPrint('Evening reminder not scheduled - user already contributed today');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'evening_reminder',
      'Evening Contribution Reminder',
      channelDescription: 'Evening reminder before midnight to maintain your streak',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFFf85149), // Red color for urgency
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = _getNextScheduledTime(_eveningHour, _eveningMinute);
    final message = _getRandomEveningMessage();

    await _notifications.zonedSchedule(
      _eveningReminderId,
      'Time is Running Out',
      message,
      scheduledDate,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'evening_reminder',
    );
  }

  /// Cancel tonight's evening reminder if the user has already contributed today.
  /// Call this after refreshing contribution data.
  static Future<void> cancelEveningReminderIfContributed() async {
    final enabled = await isReminderEnabled();
    if (!enabled) return;
    final hasContributed = await GitHubService.hasContributedToday();
    if (hasContributed) {
      await _notifications.cancel(_eveningReminderId);
      debugPrint('Evening reminder cancelled - user has already contributed today');
    }
  }

  /// Check if evening notification should be shown (only if no contributions today)
  /// This method should be called at 11 PM to conditionally show the notification
  static Future<void> checkAndShowEveningNotification() async {
    final enabled = await isReminderEnabled();
    if (!enabled) return;

    // Check if user has contributed today
    final hasContributed = await GitHubService.hasContributedToday();
    
    if (!hasContributed) {
      // User hasn't contributed today, show the reminder
      await showEveningReminderNow();
      debugPrint('Evening reminder shown - no contributions today');
    } else {
      debugPrint('Evening reminder skipped - user has already contributed today');
    }
  }

  /// Show evening reminder notification immediately
  static Future<void> showEveningReminderNow() async {
    const androidDetails = AndroidNotificationDetails(
      'evening_reminder',
      'Evening Contribution Reminder',
      channelDescription: 'Evening reminder before midnight to maintain your streak',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFFf85149),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _eveningReminderId,
      'Time is Running Out',
      _getRandomEveningMessage(),
      notificationDetails,
      payload: 'evening_reminder',
    );
  }

  /// Get the next occurrence of the scheduled time
  static tz.TZDateTime _getNextScheduledTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// Cancel all reminders
  static Future<void> cancelAllReminders() async {
    await _notifications.cancel(_morningReminderId);
    await _notifications.cancel(_eveningReminderId);
    debugPrint('All daily reminders cancelled');
  }

  /// Show an immediate test notification (morning style)
  static Future<void> showTestMorningNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_notification',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFF238636),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Start Your Day Right',
      _getRandomMorningMessage(),
      notificationDetails,
    );
  }

  /// Show an immediate test notification (evening style)
  static Future<void> showTestEveningNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'test_notification',
      'Test Notifications',
      channelDescription: 'Test notification channel',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      color: Color(0xFFf85149),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Time is Running Out',
      _getRandomEveningMessage(),
      notificationDetails,
    );
  }

  /// Get a random positive morning message (no emojis)
  static String _getRandomMorningMessage() {
    final messages = [
      'Good morning! Start fresh and make your first contribution today.',
      'A new day, a new opportunity to code. Let\'s build something great!',
      'Rise and shine! Your GitHub graph is waiting for some green.',
      'Morning! Time to write some code and keep your streak alive.',
      'Start your day with a commit. Small steps lead to big achievements.',
      'Good morning! Every contribution counts. Make yours today.',
      'A fresh start awaits. Open your IDE and create something amazing.',
      'Morning motivation: Your future self will thank you for coding today.',
      'Wake up and code! Consistency is the key to success.',
      'Good morning! Today is a perfect day to contribute.',
    ];
    
    final index = DateTime.now().day % messages.length;
    return messages[index];
  }

  /// Get a random urgent evening message (no emojis)
  static String _getRandomEveningMessage() {
    final messages = [
      'Only 1 hour left! Don\'t break your streak - contribute now.',
      'Midnight is approaching. Make your contribution before the day ends.',
      'Time is running out. Your streak depends on today\'s contribution.',
      'Final reminder: You have less than an hour to contribute today.',
      'Don\'t let your streak end tonight. Make a quick contribution now.',
      'The clock is ticking. Secure your contribution before midnight.',
      'Last chance today! A small commit is all it takes to keep your streak.',
      'Urgent: Your GitHub streak needs attention before the day ends.',
      'One hour until midnight. Don\'t forget to push your code.',
      'Final call: Make your contribution now or lose your streak.',
    ];
    
    final index = DateTime.now().day % messages.length;
    return messages[index];
  }

  /// Reschedule reminders after device reboot
  static Future<void> rescheduleReminderIfEnabled() async {
    final enabled = await isReminderEnabled();
    if (enabled) {
      await scheduleDailyReminders();
    }
  }

  /// Update evening notification based on today's contribution status
  /// Call this method when contribution data is refreshed
  static Future<void> updateEveningNotificationBasedOnContributions() async {
    final enabled = await isReminderEnabled();
    if (!enabled) return;

    try {
      final hasContributed = await GitHubService.hasContributedToday();
      
      if (hasContributed) {
        // User has already contributed today, cancel the evening reminder
        await _notifications.cancel(_eveningReminderId);
        debugPrint('Evening notification cancelled - user has already contributed today');
      } else {
        // User hasn't contributed, make sure evening reminder is scheduled
        await _scheduleEveningReminder();
        debugPrint('Evening notification scheduled - user has not contributed today');
      }
    } catch (e) {
      debugPrint('Error updating evening notification: $e');
    }
  }

  /// Cancel only the evening reminder
  static Future<void> cancelEveningReminder() async {
    await _notifications.cancel(_eveningReminderId);
    debugPrint('Evening reminder cancelled');
  }
}
