import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart'; // PAKETİ EKLEDİK
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_providers.dart';
import 'services/auth_service.dart';
import 'core/utils/interaction_feedback.dart';
import 'widgets/duel_challenge_listener.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Arka plan mesajı alındı: ${message.messageId}");
  await NotificationService.saveNotificationToLocal(message);
}

void main() async {
  // 1. Splash ekranını Flutter tamamen hazır olana kadar KİLİTLE
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Bu işlemler arkada yapılırken kullanıcı hala o pürüzsüz splash ekranını görecek
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService.initialize();

  await AuthService.initializeGoogleSignIn();
  await initializeDateFormatting('tr_TR', null);
  InteractionFeedback.init();

  runApp(
    const ProviderScope(
      child: KaeruKpssApp(),
    ),
  );
}

class KaeruKpssApp extends ConsumerWidget {
  const KaeruKpssApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(authStateListenerProvider, (previous, next) {});
    
    final router        = ref.watch(appRouterProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      data: (settings) {
        // 2. Ayarlar yüklendi ve ilk ekran çizilmeye hazır! Splash'i KALDIR
        FlutterNativeSplash.remove();

        final themeMode = settings.themeMode;
        final isPlatformDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final useDarkMode = themeMode == ThemeMode.dark || (themeMode == ThemeMode.system && isPlatformDark);
        
        final initTheme = useDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme;
        debugPrint('[KaeruKpssApp] Initializing with ${useDarkMode ? "Dark" : "Light"} theme');

        return ThemeProvider(
          initTheme: initTheme,
          duration: const Duration(milliseconds: 500),
          builder: (_, myTheme) => MaterialApp.router(
            title: AppStrings.appName,
            theme: myTheme,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
            builder: (ctx, child) => DuelChallengeListener(
              child: ThemeSwitcher.switcher(
                builder: (ctx2, _) => ThemeSwitchingArea(
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      // Yükleme sırasında artık ekranda spinner görünmeyecek çünkü altında splash ekranı bekliyor olacak.
      loading: () => const SizedBox.shrink(), 
      error: (e, st) {
        FlutterNativeSplash.remove(); // Hata olursa da kaldır ki hatayı görebilelim
        return MaterialApp(
          home: Scaffold(body: Center(child: Text('Hata: $e'))),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}