import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/push_notification_model.dart';
import '../services/local_notification_storage.dart';
import 'notification_provider.dart';

final localNotificationStorageProvider = FutureProvider<LocalNotificationStorage>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return LocalNotificationStorage(prefs);
});

class PushNotificationsNotifier extends AsyncNotifier<List<PushNotificationModel>> {
  late LocalNotificationStorage _storage;

  @override
  Future<List<PushNotificationModel>> build() async {
    _storage = await ref.watch(localNotificationStorageProvider.future);
    return _storage.getNotifications();
  }

  Future<void> addNotification(PushNotificationModel notification) async {
    await _storage.saveNotification(notification);
    state = AsyncData(await _storage.getNotifications());
  }

  Future<void> markAsRead(String id) async {
    await _storage.markAsRead(id);
    state = AsyncData(await _storage.getNotifications());
  }

  Future<void> markAllAsRead() async {
    await _storage.markAllAsRead();
    state = AsyncData(await _storage.getNotifications());
  }

  Future<void> deleteNotification(String id) async {
    await _storage.deleteNotification(id);
    state = AsyncData(await _storage.getNotifications());
  }

  Future<void> deleteAll() async {
    await _storage.deleteAll();
    state = const AsyncData(<PushNotificationModel>[]);
  }
}

final pushNotificationsProvider = AsyncNotifierProvider<PushNotificationsNotifier, List<PushNotificationModel>>(() {
  return PushNotificationsNotifier();
});

final totalUnreadBadgeProvider = Provider<int>((ref) {
  final pushState = ref.watch(pushNotificationsProvider);
  final unreadPushCount = pushState.value?.where((n) => !n.isRead).length ?? 0;

  final friendRequestsCount = ref.watch(unreadNotificationsCountProvider).value ?? 0;

  return unreadPushCount + friendRequestsCount;
});
