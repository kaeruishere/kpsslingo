import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/profile_provider.dart';
import '../../core/constants/app_routes.dart';
import '../../screens/splash/splash_screen.dart';
import '../../screens/onboarding/onboarding_screen.dart';
import '../../screens/auth/setup_profile_screen.dart';
import '../../screens/main_layout/main_layout_screen.dart';
import '../../screens/home/home_screen.dart';
import '../../screens/study/subject_select_screen.dart';
import '../../screens/study/question_loop_screen.dart';
import '../../screens/study/study_modes_screen.dart';
import '../../screens/study/result_screen.dart';
import '../../models/study_mode.dart';
import '../../screens/duel/duel_screen.dart';
import '../../screens/duel/duel_room_screen.dart';
import '../../screens/duel/duel_matchmaking_screen.dart';
import '../../screens/duel/duel_invitation_screen.dart';
import '../../screens/duel/duel_game_screen.dart';
import '../../screens/profile/profile_screen.dart';

import '../../screens/social/social_screen.dart';
import '../../screens/home/notifications_screen.dart';
import '../../screens/notifications/notification_detail_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/email_auth_screen.dart';
import '../../services/auth_service.dart';

// ────────────────────────────────────────────────────────────────
// Routes that require a real (non-anonymous) account
// ────────────────────────────────────────────────────────────────
const _protectedRoutes = {AppRoutes.duel};

// ────────────────────────────────────────────────────────────────
// GoRouter needs a Listenable to react to auth state changes.
// This wraps a Firebase stream into a ChangeNotifier.
// ────────────────────────────────────────────────────────────────
class _AuthChangeNotifier extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  _AuthChangeNotifier(Stream<User?> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorSocialKey  = GlobalKey<NavigatorState>(debugLabel: 'shellSocial');
final _shellNavigatorDuelKey    = GlobalKey<NavigatorState>(debugLabel: 'shellDuel');
final _shellNavigatorHomeKey    = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorStudyKey   = GlobalKey<NavigatorState>(debugLabel: 'shellStudy');
final _shellNavigatorProfileKey = GlobalKey<NavigatorState>(debugLabel: 'shellProfile');

final appRouterProvider = Provider<GoRouter>((ref) {
  final authService = ref.watch(authServiceProvider);
  final notifier    = _AuthChangeNotifier(authService.authStateChanges);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    navigatorKey: rootNavigatorKey,
    refreshListenable: notifier,
    redirect: (context, state) async {
      final user = authService.currentUser;
      final isAnonymous = user?.isAnonymous ?? true;
      final location = state.uri.path;

      // 1. Never intercept splash or onboarding
      if (location.startsWith(AppRoutes.splash) || location.startsWith(AppRoutes.onboarding)) return null;

      // 2. Simple protection for specific pages
      if (isAnonymous && _protectedRoutes.any((r) => location.startsWith(r))) {
        return AppRoutes.login;
      }
      
      // 3. Username / Migration Check
      if (!isAnonymous && location != AppRoutes.setupProfile) {
        try {
          final profile = await ref.read(profileProvider.future);
          if (profile.username.isEmpty) {
            return AppRoutes.setupProfile;
          }
        } catch (_) {}
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.setupProfile,
        builder: (context, state) => const SetupProfileScreen(),
      ),

      // ── Auth routes (outside shell, fullscreen) ──────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
        routes: [
          GoRoute(
            path: 'email',
            builder: (context, state) => const EmailAuthScreen(),
          ),
        ],
      ),

      // ── Study Fullscreen Routes (outside shell) ──────────────
      GoRoute(
        path: AppRoutes.studyLoop,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final modeStr = extra['mode'] as String? ?? 'topic';
          final mode    = StudyModeX.fromString(modeStr);
          final ids     = extra['ids'] as List<String>? ?? <String>[];
          final title   = extra['title'] as String? ?? '';
          final startIndex = extra['startIndex'] as int? ?? 0;
          
          return QuestionLoopScreen(
            mode: mode,
            ids: ids,
            title: title,
            startIndex: startIndex,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.studyResult,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ResultScreen(),
      ),
      GoRoute(
        path: AppRoutes.studyModes,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const StudyModesScreen(),
      ),
      GoRoute(
        path: AppRoutes.duelMatchmaking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final roomId = state.extra as String? ?? '';
          return DuelMatchmakingScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.duelInvitation,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final roomId = state.extra as String? ?? '';
          return DuelInvitationScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.duelRoom,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final roomId = state.extra as String? ?? '';
          return DuelRoomScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.duelGame,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final roomId = state.extra as String? ?? '';
          return DuelGameScreen(roomId: roomId);
        },
      ),
      GoRoute(
        path: AppRoutes.duelResult,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
           final roomId = state.extra as String? ?? '';
           return Scaffold(
             backgroundColor: Theme.of(context).colorScheme.surface,
             appBar: AppBar(title: const Text('Düello Sonucu'), backgroundColor: Colors.transparent, elevation: 0),
             body: Center(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
                   const SizedBox(height: 24),
                   Text('DÜELLO TAMAMLANDI!', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                   const SizedBox(height: 16),
                   Text('Oda: $roomId', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                   const SizedBox(height: 48),
                   ElevatedButton(
                     onPressed: () => context.go(AppRoutes.duel),
                     child: const Text('Anasayfaya Dön'),
                   ),
                 ],
               ),
             ),
           );
        },
      ),


      // ── Standalone Routes (outside shell) ──────────────
      GoRoute(
        path: AppRoutes.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '${AppRoutes.notificationDetail}/:contentId',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final contentId = state.pathParameters['contentId'] ?? '';
          return NotificationDetailScreen(contentId: contentId);
        },
      ),

      // ── Persistent shell with NavigationBar ──────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainLayoutScreen(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSocialKey,
            routes: [
              GoRoute(
                path: AppRoutes.social,
                builder: (context, state) => const SocialScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorDuelKey,
            routes: [
              GoRoute(
                path: AppRoutes.duel,
                builder: (context, state) => const DuelScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorStudyKey,
            routes: [
              GoRoute(
                path: AppRoutes.studySelect,
                builder: (context, state) {
                  final extra = state.extra as Map<String, dynamic>? ?? {};
                  final isLessonMode = extra['isLessonMode'] as bool? ?? false;
                  return SubjectSelectScreen(isLessonMode: isLessonMode);
                },
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorProfileKey,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
