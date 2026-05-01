import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../services/auth_service.dart';
import '../../providers/profile_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleGoogle() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
      
      if (mounted) {
        // Wait a bit for auth state to propagate and ProfileProvider to react
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Decide manually where to go, with a timeout to prevent infinite hang
          final profile = await ref.read(profileProvider.future).timeout(
            const Duration(seconds: 2),
            onTimeout: () => const UserProfile(),
          );
          
          if (mounted) {
            if (!profile.hasCompletedSetup) {
              context.go(AppRoutes.setupProfile);
            } else {
              context.go(AppRoutes.home);
            }
          }
        }
      }
    } on Exception catch (e) {
      debugPrint('Google sign-in error: $e');
      setState(() { _errorMessage = AppStrings.loginErrorGeneric; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _handleGuest() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      await ref.read(authServiceProvider).signInAnonymously();
      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      debugPrint('Guest login error: $e');
      setState(() { _errorMessage = AppStrings.loginErrorGeneric; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Decorative background
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [cs.primaryContainer, cs.surface],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSizes.p64),

                  // Branding
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.p24),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.school_rounded, size: 80, color: cs.primary),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p32),
                  Text(
                    AppStrings.loginTitle,
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.p12),
                  Text(
                    AppStrings.loginSubtitle,
                    style: tt.bodyLarge?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const Spacer(),

                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.p16),
                      child: Text(
                        _errorMessage!,
                        style: tt.bodySmall?.copyWith(color: cs.error),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Login Actions
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else ...[
                    // Google Button
                    FilledButton.icon(
                      onPressed: _handleGoogle,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r16),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(AppStrings.loginGoogle),
                    ),
                    const SizedBox(height: AppSizes.p16),

                    // Email Button
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.emailAuth),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.p16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.r16),
                        ),
                      ),
                      icon: const Icon(Icons.email_outlined),
                      label: const Text(AppStrings.loginEmail),
                    ),
                  ],

                  const SizedBox(height: AppSizes.p32),

                  // Guest Login
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _handleGuest,
                      child: Text(
                        AppStrings.loginGuest,
                        style: tt.labelLarge?.copyWith(
                          color: cs.secondary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSizes.p48),
                  
                  // Privacy
                  Text(
                    AppStrings.loginPrivacy,
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.p16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
