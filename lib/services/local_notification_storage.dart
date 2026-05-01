import 'package:shared_preferences/shared_preferences.dart';
import '../models/push_notification_model.dart';

class LocalNotificationStorage {
  static const String _storageKey = 'push_notifications_v1';
  final SharedPreferences _prefs;

  LocalNotificationStorage(this._prefs);

  Future<void> saveNotification(PushNotificationModel notification) async {
    final notifications = getNotifications();
    notifications.insert(0, notification);
    await _saveAll(notifications);
  }

  List<PushNotificationModel> getNotifications() {
    final list = _prefs.getStringList(_storageKey) ?? <String>[];
    return list.map((item) => PushNotificationModel.fromJson(item)).toList();
  }

  Future<void> markAsRead(String id) async {
    final notifications = getNotifications();
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index] = notifications[index].copyWith(isRead: true);
      await _saveAll(notifications);
    }
  }

  Future<void> markAllAsRead() async {
    final notifications = getNotifications();
    final updated = notifications.map((n) => n.copyWith(isRead: true)).toList();
    await _saveAll(updated);
  }

  Future<void> deleteNotification(String id) async {
    final notifications = getNotifications();
    notifications.removeWhere((n) => n.id == id);
    await _saveAll(notifications);
  }

  Future<void> deleteAll() async {
    await _prefs.remove(_storageKey);
  }

  Future<void> _saveAll(List<PushNotificationModel> notifications) async {
    final encodedList = notifications.map((n) => n.toJson()).toList();
    await _prefs.setStringList(_storageKey, encodedList);
  }
}
