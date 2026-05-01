import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/study_providers.dart';
import '../../models/study_mode.dart';

class SubjectSelectScreen extends ConsumerWidget {
  final bool isLessonMode;
  const SubjectSelectScreen({super.key, this.isLessonMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonsWithProgressProvider);
    final selectedIds  = ref.watch(selectedStudyIdsProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(isLessonMode ? 'Ders Seçimi' : 'Konu Seçimi'),
        centerTitle: true,
        actions: [
          if (selectedIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => ref.read(selectedStudyIdsProvider.notifier).clear(),
              icon: const Icon(Icons.clear_all),
              label: const Text('Temizle'),
            ),
        ],
      ),
      floatingActionButton: selectedIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                final ids = selectedIds.toList();
                context.push(AppRoutes.studyLoop, extra: {
                  'mode': isLessonMode ? StudyMode.subject.name : StudyMode.topic.name,
                  'ids': ids,
                  'title': isLessonMode ? 'Ders Çalışması' : 'Konu Çalışması',
                });
                // Seçimleri temizle
                ref.read(selectedStudyIdsProvider.notifier).clear();
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('${selectedIds.length} ${isLessonMode ? 'Ders' : 'Konu'} Başlat'),
            )
          : null,
      body: lessonsAsync.when(
        data: (lessons) {
          if (lessons.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                   const SizedBox(height: 16),
                   const Text('Henüz ders eklenmemiş veya yüklenemedi.'),
                   const SizedBox(height: 8),
                   ElevatedButton(
                     onPressed: () => ref.invalidate(lessonsProvider),
                     child: const Text('Dersleri Yenile'),
                   ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(lessonsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSizes.p16),
              itemCount: lessons.length,
              itemBuilder: (context, index) => _LessonCard(
                data: lessons[index],
                isLessonMode: isLessonMode,
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Dersler yüklenemedi.'),
              TextButton(
                onPressed: () => ref.invalidate(lessonsProvider),
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonCard extends ConsumerWidget {
  final LessonWithProgress data;
  final bool isLessonMode;
  const _LessonCard({required this.data, required this.isLessonMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = ref.watch(selectedStudyIdsProvider).contains(data.lesson.id);
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.p24),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.r24),
        side: BorderSide(
          color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? cs.primaryContainer.withValues(alpha: 0.05) : null,
      child: ExpansionTile(
        key: ValueKey('lesson_${data.lesson.id}'),
        backgroundColor: cs.surfaceContainerLowest,
        collapsedBackgroundColor: cs.surface,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.p8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSizes.r12),
              ),
              child: Icon(Icons.menu_book_rounded, color: cs.primary, size: 28),
            ),
            const SizedBox(width: AppSizes.p12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.lesson.name,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  _buildLessonStats(context),
                ],
              ),
            ),
            if (isLessonMode)
              IconButton(
                icon: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, 
                  color: isSelected ? cs.primary : cs.secondary, 
                  size: 32,
                ),
                onPressed: () {
                  ref.read(selectedStudyIdsProvider.notifier).toggle(data.lesson.id);
                },
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSizes.p12, bottom: AppSizes.p4),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.r12),
                child: LinearProgressIndicator(
                  value: data.progress,
                  minHeight: 10,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    data.progress >= 0.99 ? Colors.green : cs.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Genel İlerleme',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  Text(
                    '${(data.progress * 100).toInt()}%',
                    style: tt.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: data.progress >= 0.99 ? Colors.green : cs.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p12, vertical: AppSizes.p8),
        children: data.subjects.asMap().entries.map((entry) {
          return _SubjectItem(
            item: entry.value,
            index: entry.key + 1,
            isLessonMode: isLessonMode,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLessonStats(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _miniStat(context, Icons.list_alt_rounded, '${data.totalSubjects} Konu'),
          _miniStat(context, Icons.info_outline_rounded, '${data.totalFlashcards} Kart'),
          _miniStat(context, Icons.quiz_outlined, '${data.totalTests} Test'),
          _miniStat(context, Icons.edit_note_rounded, '${data.totalFills} Boşluk'),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String label) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 2),
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class _SubjectItem extends ConsumerWidget {
  final SubjectWithProgress item;
  final int index;
  final bool isLessonMode;
  const _SubjectItem({required this.item, required this.index, required this.isLessonMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = ref.watch(selectedStudyIdsProvider).contains(item.subject.id);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p8),
      child: InkWell(
        onTap: isLessonMode ? null : () {
          HapticFeedback.lightImpact();
          ref.read(selectedStudyIdsProvider.notifier).toggle(item.subject.id);
        },
        borderRadius: BorderRadius.circular(AppSizes.r16),
        child: Container(
          padding: const EdgeInsets.all(AppSizes.p12),
          decoration: BoxDecoration(
            color: isSelected ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surface,
            borderRadius: BorderRadius.circular(AppSizes.r16),
            border: Border.all(
              color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.3),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: isSelected ? cs.primary : cs.primary.withValues(alpha: 0.1),
                    child: isSelected 
                      ? Icon(Icons.check, size: 14, color: cs.onPrimary)
                      : Text(
                          '$index',
                          style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                        ),
                  ),
                  const SizedBox(width: AppSizes.p12),
                  Expanded(
                    child: Text(
                      item.subject.name,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: item.progress >= 0.99 ? Colors.green.withValues(alpha: 0.1) : cs.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${(item.progress * 100).toInt()}%',
                      style: tt.labelSmall?.copyWith(
                        color: item.progress >= 0.99 ? Colors.green : cs.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _subjectTypeStat(context, '🃏 ${item.subject.flashcardCount}'),
                  _subjectTypeStat(context, '🎯 ${item.subject.testCount}'),
                  _subjectTypeStat(context, '✏️ ${item.subject.fillCount}'),
                  const Spacer(),
                  Text(
                    '${item.completedQuestions}/${item.totalQuestions} Soru',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.p8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.progress,
                  minHeight: 6,
                  backgroundColor: cs.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    item.progress >= 0.99 ? Colors.green : cs.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjectTypeStat(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
