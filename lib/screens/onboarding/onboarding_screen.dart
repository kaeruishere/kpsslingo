import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/settings_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardData> _slides = [
    const _OnboardData(
      title: AppStrings.onboarding1Title,
      body: AppStrings.onboarding1Body,
      icon: '📚',
      color: Color(0xFF6366F1), // Indigo
    ),
    const _OnboardData(
      title: AppStrings.onboarding2Title,
      body: AppStrings.onboarding2Body,
      icon: '⚔️',
      color: Color(0xFFF43F5E), // Rose
    ),
    const _OnboardData(
      title: AppStrings.onboarding3Title,
      body: AppStrings.onboarding3Body,
      icon: '🏆',
      color: Color(0xFF10B981), // Emerald
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _complete();
    }
  }

  void _complete() {
    ref.read(settingsProvider.notifier).setSeenOnboarding(true);
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _slides[_currentPage].color.withValues(alpha: 0.2),
                  cs.surface,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: TextButton(
                    onPressed: _complete,
                    child: const Text(AppStrings.onboardingSkip),
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _slides.length,
                    itemBuilder: (context, index) {
                      final slide = _slides[index];
                      return Padding(
                        padding: const EdgeInsets.all(AppSizes.p32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              slide.icon,
                              style: const TextStyle(fontSize: 100),
                            ),
                            const SizedBox(height: AppSizes.p48),
                            Text(
                              slide.title,
                              style: tt.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: cs.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSizes.p16),
                            Text(
                              slide.body,
                              style: tt.bodyLarge?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.all(AppSizes.p32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(
                          _slides.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: AppSizes.p8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _slides[_currentPage].color
                                  : cs.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next Button
                      FilledButton(
                        onPressed: _onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: _slides[_currentPage].color,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.p32,
                            vertical: AppSizes.p16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.r16),
                          ),
                        ),
                        child: Text(
                          _currentPage == _slides.length - 1
                              ? AppStrings.onboardingStart
                              : AppStrings.onboardingNext,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardData {
  final String title;
  final String body;
  final String icon;
  final Color color;
  const _OnboardData({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });
}
