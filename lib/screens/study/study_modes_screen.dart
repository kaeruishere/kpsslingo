import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import 'package:go_router/go_router.dart';

class StudyModesScreen extends StatelessWidget {
  const StudyModesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma Modları')),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.p16),
        children: [
          _ModeCard(
            title: 'Rastgele Soru Çöz',
            subtitle: 'Tüm konulardan ve derslerden karma sorular.',
            icon: Icons.shuffle_rounded,
            onTap: () => context.push(
              AppRoutes.studyLoop,
              extra: {
                'mode': 'random', 
                'ids': <String>[],
                'title': 'Genel Tekrar'
              },
            ),
          ),
          SizedBox(height: AppSizes.p16),
          _ModeCard(
            title: 'Ders Bazlı Çalışma',
            subtitle: 'Sadece belirlediğiniz dersin sorularını çözün.',
            icon: Icons.auto_stories_rounded,
            onTap: () => context.go(AppRoutes.studySelect, extra: {'isLessonMode': true}),
          ),
          SizedBox(height: AppSizes.p16),
          _ModeCard(
            title: 'Konu Bazlı Çalışma',
            subtitle: 'Spesifik zayıf olduğunuz konulara odaklanın.',
            icon: Icons.fact_check_rounded,
            onTap: () => context.go(AppRoutes.studySelect, extra: {'isLessonMode': false}),
          ),
          SizedBox(height: AppSizes.p16),
          _ModeCard(
            title: 'Genel Deneme',
            subtitle: 'Gerçek sınav simülasyonu ile kendinizi test edin.',
            icon: Icons.school_rounded,
            onTap: () => context.push(
              AppRoutes.studyLoop, 
              extra: {
                'mode': 'random', 
                'ids': <String>[],
                'title': 'Deneme Modu'
              }
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: AppSizes.defaultBorderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSizes.defaultBorderRadius,
        child: Padding(
          padding: EdgeInsets.all(AppSizes.p20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSizes.p12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: Theme.of(context).colorScheme.onPrimaryContainer),
              ),
              SizedBox(width: AppSizes.p16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    SizedBox(height: AppSizes.p4),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
