import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/profile_provider.dart';
import '../../providers/exams_provider.dart';
import '../../providers/study_providers.dart';
import '../../providers/notification_provider.dart';
import '../../providers/push_notifications_provider.dart';
import '../../models/exam_model.dart';
import '../../models/subject_progress_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileProvider.notifier).updateLoginTimestamp();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: cs.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const _GreetingHeader(),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final unreadCount = ref.watch(totalUnreadBadgeProvider);
              return IconButton(
                icon: unreadCount > 0
                    ? Badge(
                        label: Text(unreadCount.toString()),
                        child: const Icon(Icons.notifications_rounded),
                      )
                    : const Icon(Icons.notifications_none_rounded),
                onPressed: () => context.push(AppRoutes.notifications),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(examsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Hero Card ──────────────────────────────────
                const _HeroCard(),
                const SizedBox(height: AppSizes.p20),

                // ── 2. Kaldığın Yerden Devam Et ────────────────────
                const _ResumeCard(),

                // ── 3. Sınav Geri Sayımı ──────────────────────────
                const _ExamCountdownCard(),
                const SizedBox(height: AppSizes.p20),

                // ── 4. Çalışma Modu ────────────────────────────────
                const _SectionTitle(title: 'Çalışma Modu'),
                const SizedBox(height: AppSizes.p8),
                const _StudyModesGrid(),
                const SizedBox(height: AppSizes.p32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Section Title
// ═══════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.02,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Greeting Header
// ═══════════════════════════════════════════════════════════════

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return AppStrings.dashGreetingMorning;
    if (hour >= 12 && hour < 18) return AppStrings.dashGreetingAfternoon;
    return AppStrings.dashGreetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final profile = ref.watch(profileProvider);

    return profile.when(
      data: (p) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => context.push(AppRoutes.profile),
            child: Container(
              margin: const EdgeInsets.only(right: AppSizes.p12),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(p.avatarEmoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_getGreeting(), style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(
                  p.displayName.isEmpty ? AppStrings.dashLoading : p.displayName,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
      loading: () => const _ShimmerBlock(width: 200, height: 44),
      error: (err, st) => const Text('Hata!'),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 1. Hero Card
// ═══════════════════════════════════════════════════════════════

class _HeroCard extends ConsumerWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return profileAsync.when(
      data: (p) {
        final cs        = Theme.of(context).colorScheme;
        final tt        = Theme.of(context).textTheme;
        final xpInLevel  = p.totalXp % 1000;
        final progress   = xpInLevel / 1000;
        final overallP   = ref.watch(overallProgressProvider).value ?? 0.0;
        final successRate = '%${(overallP * 100).toInt()}';

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(AppSizes.p20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst etiket
              Text(
                'Genel Durum',
                style: tt.labelSmall?.copyWith(color: cs.onPrimary.withValues(alpha: 0.65)),
              ),
              const SizedBox(height: 6),

              // Streak başlık
              Text(
                '${p.streak} günlük seri 🔥',
                style: tt.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
                ),
              ),
              Text(
                'Bugün de devam et, serini kırma!',
                style: tt.bodySmall?.copyWith(
                  color: cs.onPrimary.withValues(alpha: 0.65),
                ),
              ),
              const SizedBox(height: AppSizes.p16),

              // Stats row
              IntrinsicHeight(
                child: Row(
                  children: [
                    _HeroStatChip(
                      value: '${p.totalXp}',
                      label: 'Toplam XP',
                      textColor: cs.onPrimary,
                    ),
                    VerticalDivider(
                      color: cs.onPrimary.withValues(alpha: 0.25),
                      width: AppSizes.p20,
                    ),
                    _HeroStatChip(
                      value: 'Sv. ${p.level}',
                      label: 'Seviye',
                      textColor: cs.onPrimary,
                    ),
                    VerticalDivider(
                      color: cs.onPrimary.withValues(alpha: 0.25),
                      width: AppSizes.p20,
                    ),
                    _HeroStatChip(
                      value: successRate,
                      label: 'Başarı',
                      textColor: cs.onPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.p16),

              // XP progress bar
              LinearProgressIndicator(
                value: progress,
                backgroundColor: cs.onPrimary.withValues(alpha: 0.2),
                color: cs.onPrimary.withValues(alpha: 0.9),
                minHeight: 5,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 5),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$xpInLevel / 1.000 XP',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.55),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Seviye ${p.level}',
                      style: tt.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const _ShimmerBlock(height: 190),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  final String value;
  final String label;
  final Color  textColor;
  const _HeroStatChip({
    required this.value,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: textColor.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// 3. Resume Card
// ═══════════════════════════════════════════════════════════════

class _ResumeCard extends ConsumerWidget {
  const _ResumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumeAsync = ref.watch(lastPlayedSubjectProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return resumeAsync.when(
      data: (resume) {
        if (resume == null || (resume as dynamic).konuId.isEmpty) {
          return const SizedBox.shrink();
        }

        final subjectProgress = resume as SubjectProgressModel;
        final konuAsync = ref.watch(konuByPathProvider((dersId: subjectProgress.dersId, konuId: subjectProgress.konuId)));

        return konuAsync.when(
          data: (konu) {
            if (konu == null) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.p20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(title: AppStrings.dashResumeTitle),
                  const SizedBox(height: AppSizes.p8),
                  InkWell(
                    onTap: () {
                      context.push(AppRoutes.studyLoop, extra: {
                        'mode': 'topic',
                        'ids': <String>[resume.konuId],
                        'title': konu.name,
                        'startIndex': resume.lastIndex,
                      });
                    },
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        border: Border(
                          left: BorderSide(color: cs.secondary, width: 3),
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: 13),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.play_arrow_rounded, color: cs.onSecondaryContainer, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: cs.secondaryContainer,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Kaldığın Konu',
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSecondaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(konu.name,
                                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                                  Text('Soru ${resume.lastIndex + 1}\'den devam et',
                                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(bottom: AppSizes.p20),
            child: _ShimmerBlock(height: 66),
          ),
          error: (_, __) => const SizedBox.shrink(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.only(bottom: AppSizes.p20),
        child: _ShimmerBlock(height: 66),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 4. Study Modes Grid
// ═══════════════════════════════════════════════════════════════

class _StudyModesGrid extends StatelessWidget {
  const _StudyModesGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final modes = [
      _ModeCardData(
        icon: Icons.shuffle_rounded,
        iconBg: cs.primaryContainer,
        iconColor: cs.onPrimaryContainer,
        title: 'Rastgele Soru',
        subtitle: 'Karışık çöz',
        onTap: () => context.push(
          AppRoutes.studyLoop,
          extra: {
            'mode': 'random', 
            'ids': <String>[],
            'title': 'Genel Tekrar'
          },
        ),
      ),
      _ModeCardData(
        icon: Icons.menu_book_rounded,
        iconBg: cs.secondaryContainer,
        iconColor: cs.onSecondaryContainer,
        title: 'Ders Bazlı',
        subtitle: 'Derse göre çalış',
        onTap: () => context.push(AppRoutes.studySelect, extra: {'isLessonMode': true}),
      ),
      _ModeCardData(
        icon: Icons.topic_rounded,
        iconBg: cs.tertiaryContainer,
        iconColor: cs.onTertiaryContainer,
        title: 'Konu Bazlı',
        subtitle: 'Konuya odaklan',
        onTap: () => context.push(AppRoutes.studySelect, extra: {'isLessonMode': false}),
      ),
      _ModeCardData(
        icon: Icons.apps_rounded,
        iconBg: cs.surfaceContainerHighest,
        iconColor: cs.onSurface,
        title: 'Tüm Modlar',
        subtitle: 'Hepsini gör',
        onTap: () => context.push(AppRoutes.studyModes),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.55,
      children: modes.map((m) => _ModeCard(data: m)).toList(),
    );
  }
}

class _ModeCardData {
  final IconData      icon;
  final Color         iconBg;
  final Color         iconColor;
  final String        title;
  final String        subtitle;
  final VoidCallback  onTap;
  const _ModeCardData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _ModeCard extends StatelessWidget {
  final _ModeCardData data;
  const _ModeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(data.icon, color: data.iconColor, size: 18),
              ),
              const Spacer(),
              Text(data.title, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(data.subtitle, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Exam Countdown Card
// ═══════════════════════════════════════════════════════════════

class _ExamCountdownCard extends ConsumerWidget {
  const _ExamCountdownCard();

  static const _weekdays = [
    'Pazartesi', 'Salı', 'Çarşamba',
    'Perşembe', 'Cuma', 'Cumartesi', 'Pazar',
  ];
  static const _months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);
    final examsAsync   = ref.watch(examsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (!examsAsync.hasValue) return const _ShimmerBlock(height: 76);

    final selectedId = profileAsync.value?.selectedExam;
    final list       = examsAsync.value!;
    final filtered   = (selectedId != null && selectedId.isNotEmpty)
        ? list.where((e) => e.id == selectedId).toList()
        : list;

    if (filtered.isEmpty) return const SizedBox.shrink();

    final exam    = filtered.first;
    final dateStr = '${exam.date.day} ${_months[exam.date.month - 1]} '
        '${exam.date.year}, ${_weekdays[exam.date.weekday - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: AppStrings.dashCountdownTitle),
        const SizedBox(height: AppSizes.p8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.p16,
            vertical: AppSizes.p16,
          ),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${exam.daysLeft}',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                      height: 1,
                    ),
                  ),
                  Text(
                    'GÜN',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Shimmer
// ═══════════════════════════════════════════════════════════════

class _ShimmerBlock extends StatelessWidget {
  final double? width;
  final double height;
  const _ShimmerBlock({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
