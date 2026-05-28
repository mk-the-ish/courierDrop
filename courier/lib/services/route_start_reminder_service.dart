import "package:flutter_local_notifications/flutter_local_notifications.dart";
import "package:shared_preferences/shared_preferences.dart";

class RouteStartReminderService {
  RouteStartReminderService._();
  static final RouteStartReminderService instance = RouteStartReminderService._();

  static const _prefsPrefix = "route_start_notified_";
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings("@mipmap/ic_launcher");
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> notifyIfDue(List<Map<String, dynamic>> routes) async {
    await init();
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();

    for (final route in routes) {
      final routeId = route["id"]?.toString();
      final status = (route["status"]?.toString() ?? "").toUpperCase();
      final plannedStartRaw = route["planned_start_at"]?.toString();
      if (routeId == null || routeId.isEmpty || plannedStartRaw == null || plannedStartRaw.isEmpty) {
        continue;
      }
      if (status != "PLANNED") continue;
      final plannedStart = DateTime.tryParse(plannedStartRaw)?.toUtc();
      if (plannedStart == null) continue;

      final key = "$_prefsPrefix$routeId";
      if (prefs.getBool(key) == true) continue;

      if (!now.isBefore(plannedStart)) {
        await _plugin.show(
          routeId.hashCode & 0x7fffffff,
          "Start your journey",
          "Your planned route start time is now. Tap Start Route.",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              "dropcity_route_reminders",
              "Route Reminders",
              channelDescription: "Reminders for planned route start times",
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
        await prefs.setBool(key, true);
      }
    }
  }
}

