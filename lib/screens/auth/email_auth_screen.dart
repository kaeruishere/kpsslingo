import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../services/auth_service.dart';
import '../../providers/profile_provider.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final auth = ref.read(authServiceProvider);
      if (_isRegisterMode) {
        await auth.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        await auth.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      }
      
      if (mounted) {
        // Wait a bit for auth state to propagate and ProfileProvider to react
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Decide manually where to go
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
    } catch (e) {
      setState(() { _errorMessage = AppStrings.loginErrorGeneric; });
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = _isRegisterMode ? AppStrings.emailAuthRegister : AppStrings.emailAuthSignIn;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.p24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSizes.p16),

                // Error banner
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSizes.p12),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: AppSizes.defaultBorderRadius,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                  const SizedBox(height: AppSizes.p16),
                ],

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: AppStrings.emailAuthEmail,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => (v?.isEmpty ?? true) ? 'E-posta gerekli' : null,
                ),
                const SizedBox(height: AppSizes.p16),

                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: AppStrings.emailAuthPassword,
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) => (v?.length ?? 0) < 6 ? 'En az 6 karakter' : null,
                ),
                const SizedBox(height: AppSizes.p24),

                // Submit
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _submit,
                        child: Text(title),
                      ),

                const SizedBox(height: AppSizes.p8),

                // Toggle
                TextButton(
                  onPressed: () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(
                    _isRegisterMode
                        ? AppStrings.emailAuthToggleToSignIn
                        : AppStrings.emailAuthToggleToRegister,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
