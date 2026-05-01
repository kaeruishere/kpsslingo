import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/settings_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/auth_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // 1. Force delay
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // 2. Wait for settings & profile to initialize
    final settings = await ref.read(settingsProvider.future);
    final user = ref.read(authServiceProvider).currentUser;

    if (!mounted) return;

    // 3. Manual Decider
    if (!settings.hasSeenOnboarding) {
      context.go(AppRoutes.onboarding);
      return;
    }

    if (user == null) {
      context.go(AppRoutes.login);
      return;
    }

    // Authenticated users check for setup
    if (!user.isAnonymous) {
      final profile = await ref.read(profileProvider.future);
      if (mounted && !profile.hasCompletedSetup) {
        context.go(AppRoutes.setupProfile);
        return;
      }
    }

    // Default go home
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.p24),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school_rounded, size: 80, color: cs.primary),
            ),
            const SizedBox(height: AppSizes.p32),
            const CircularProgressIndicator(),
            const SizedBox(height: AppSizes.p16),
            Text(
              AppStrings.splashLoading,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            )
          ],
        ),
      ),
    );
  }
}
