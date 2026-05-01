import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_routes.dart';
import '../core/router/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/push_notification_model.dart';
import 'local_notification_storage.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Android ve iOS (13+) için bildirim izni iste
    await requestPermission();

    // Tüm kullanıcılara gönderilen kampanyaları almak için 'all' topic'ine abone ol
    await _messaging.subscribeToTopic('all');

    // Android için kanal (channel) ayarı ve yerel bildirim init ayarları
    await _initLocalNotifications();

    // Ön planda bildirim ayarları (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Cihazın benzersiz FCM token'ını al (Test için konsolda bu token kullanılabilir)
    final token = await getToken();
    if (kDebugMode) {
      print('====================================');
      print('FCM TOKEN: $token');
      print('====================================');
    }

    // Uygulama açıkken (foreground) gelen mesajları dinle
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Yeni foreground mesajı alındı: ${message.messageId}');
      }
      saveNotificationToLocal(message);
      _showLocalNotification(message);
    });

    // Kullanıcı bildirime tıkladığında (uygulama arka plandayken)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('Bildirime tıklandı (App in Background): ${message.messageId}');
      }
      _handleMessageRoute(message);
    });

    // Uygulama tamamen kapalıysa (terminated) ve bildirimden açılmışsa
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('Bildirime tıklandı (App Terminated): ${initialMessage.messageId}');
      }
      // UI'ın render olmasını beklemek için küçük bir bekleme ekliyoruz
      Future.delayed(const Duration(milliseconds: 600), () {
        _handleMessageRoute(initialMessage);
      });
    }
  }

  static void _handleMessageRoute(RemoteMessage message) {
    if (message.data.containsKey('contentId')) {
      final contentId = message.data['contentId'];
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        context.push('${AppRoutes.notificationDetail}/$contentId');
      } else {
        if (kDebugMode) {
          print('Yönlendirme yapılamadı: rootNavigatorKey.currentContext null.');
        }
      }
    }
  }

  static Future<void> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (kDebugMode) {
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('Bildirim İzni: Verildi');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('Bildirim İzni: Geçici (Provisional) Verildi');
      } else {
        print('Bildirim İzni: Reddedildi veya henüz verilmedi.');
      }
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      if (kDebugMode) {
        print('FCM Token alınırken hata oluştu: $e');
      }
      return null;
    }
  }

  static Future<void> _initLocalNotifications() async {
    const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (kDebugMode) {
          print('Foreground Local Notification Tıklandı: ${details.payload}');
        }
        if (details.payload != null && details.payload!.isNotEmpty) {
          final context = rootNavigatorKey.currentContext;
          if (context != null) {
            context.push('${AppRoutes.notificationDetail}/${details.payload}');
          }
        }
      },
    );

    // Android 8.0+ için yüksek öncelikli bildirim kanalı (Heads-up için gerekli)
    const channel = AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'Bağlantı ve genel yüksek öncelikli bildirimler.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static void _showLocalNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null && android != null) {
      // Payload olarak contentId geçiyoruz ki tıklandığında yönlendirme yapılabilsin
      final payload = message.data['contentId']?.toString();

      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        payload: payload,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: 'Bağlantı ve genel yüksek öncelikli bildirimler.',
            icon: '@mipmap/ic_launcher',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
    }
  }

  static Future<void> saveNotificationToLocal(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null && message.data.isEmpty) return; // ignore completely empty

    final prefs = await SharedPreferences.getInstance();
    final storage = LocalNotificationStorage(prefs);

    final pushNotif = PushNotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: notification?.title ?? message.data['title'] ?? 'Yeni Bildirim',
      body: notification?.body ?? message.data['body'] ?? '',
      contentId: message.data['contentId']?.toString() ?? '',
      type: message.data['type']?.toString() ?? '',
      createdAt: message.sentTime ?? DateTime.now(),
    );

    await storage.saveNotification(pushNotif);
  }
}
