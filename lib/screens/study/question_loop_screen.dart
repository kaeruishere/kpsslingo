import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/study_providers.dart';
import '../../models/soru_model.dart';
import '../../services/progress_service.dart';
import '../../widgets/question_card/flashcard_card.dart';
import '../../widgets/question_card/multiple_choice_card.dart';
import '../../widgets/question_card/fill_blank_card.dart';
import '../../providers/question_loop_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/utils/interaction_feedback.dart';
import '../../models/study_mode.dart';

class QuestionLoopScreen extends ConsumerStatefulWidget {
  final StudyMode mode;
  final List<String> ids;
  final String title;
  final int startIndex;

  const QuestionLoopScreen({
    super.key,
    required this.mode,
    required this.ids,
    this.title = '',
    this.startIndex = 0,
  });

  @override
  ConsumerState<QuestionLoopScreen> createState() => _QuestionLoopScreenState();
}

class _QuestionLoopScreenState extends ConsumerState<QuestionLoopScreen> {
  bool _isLoadingResume = true;

  @override
  void initState() {
    super.initState();
    _initResume();
  }

  Future<void> _initResume() async {
    if (widget.mode != StudyMode.topic || widget.ids.isEmpty) {
      if (mounted) setState(() { _isLoadingResume = false; });
      return;
    }

    // Resume only works for a single subject at a time reliably
    if (widget.ids.length > 1) {
       if (mounted) setState(() { _isLoadingResume = false; });
       return;
    }

    if (widget.startIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(questionLoopProvider.notifier).setStartIndex(widget.startIndex);
        if (mounted) setState(() { _isLoadingResume = false; });
      });
      return;
    }

    final pService = ref.read(progressServiceProvider);
    final resumeData = await pService.getSubjectResumePoint(widget.ids.first);
    
    if (!mounted) return;

    if (resumeData != null && resumeData.lastIndex > 0) {
      ref.read(questionLoopProvider.notifier).setStartIndex(resumeData.lastIndex);
    }
    setState(() {
      _isLoadingResume = false;
    });
  }

  void _onAnswer(AnswerResult result, String questionId) async {
    final loopState = ref.read(questionLoopProvider);
    if (loopState.isAnimating) return;

    final notifier = ref.read(questionLoopProvider.notifier);

    final settings = ref.read(settingsProvider).value;
    final soundConf = settings?.sound ?? true;
    final vibConf = settings?.vibration ?? true;

    String direction = 'up';
    if (result == AnswerResult.correct) {
      direction = 'right';
    } else if (result == AnswerResult.wrong) {
      direction = 'left';
    }

    notifier.setAnimating(true, direction);

    if (result != AnswerResult.skipped) {
      notifier.recordAnswer(result);
    }
    
    // Veritabanına cevabı asenkron kaydet
    final questions = ref.read(sorularByModeProvider((mode: widget.mode, ids: widget.ids))).value ?? [];
    if (questions.isNotEmpty && loopState.currentIndex < questions.length) {
      final currentQ = questions[loopState.currentIndex];
      final currentType = currentQ.type;
      ref.read(progressServiceProvider).saveAnswer(questionId, currentQ.konuId, result, currentType);
      
      // Push Gamification Rewards Screen UI Feedback
      if (result == AnswerResult.correct) {
         InteractionFeedback.correct(soundConf, vibConf);
         _showFloatingXP(currentType == 'fill_in_the_blank' ? 15 : 10, true);
      } else if (result == AnswerResult.wrong) {
         InteractionFeedback.wrong(soundConf, vibConf);
         _showFloatingXP(-2, false);
      }
    }

    // Animasyonun bitmesini bekle
    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;
    if (loopState.currentIndex < questions.length - 1) {
      final currentQ = questions[loopState.currentIndex];
      notifier.nextQuestion(currentQ.konuId, currentQ.dersId);
    } else {
      notifier.setAnimating(false);
      // Bitiş ekranını göster
      _showCompletionSheet(questions.length);
    }
  }

  void _showFloatingXP(int amount, bool isPositive) {
    if (!mounted) return;
    
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).size.height * 0.35, // Position near the card
          left: MediaQuery.of(context).size.width / 2 - 60,
          child: TweenAnimationBuilder(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1400),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -value * 60), // Float upwards
                child: Opacity(
                  opacity: value < 0.2 ? value * 5 : (1.0 - (value - 0.2) * 1.25).clamp(0.0, 1.0), // Fade in briefly, then fade out
                  child: child,
                ),
              );
            },
            onEnd: () {
              if (entry.mounted) entry.remove();
            },
            child: Material(
              color: Colors.transparent,
              child: Text(
                isPositive ? '+$amount XP' : '$amount XP',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isPositive ? Colors.greenAccent.shade400 : Colors.redAccent.shade400,
                  shadows: const [
                    Shadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 2))
                  ]
                ),
              ),
            ),
          ),
        );
      },
    );
    
    overlay.insert(entry);
  }

  void _showReportSheet(String questionId) {
    String? selectedReason;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final cs = Theme.of(context).colorScheme;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Soruyu Bildir',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ...['Yanlış cevap', 'Yazım hatası', 'Hatalı soru', 'Uygunsuz içerik'].map((reason) {
                      return RadioListTile<String>(
                        title: Text(reason),
                        value: reason,
                        groupValue: selectedReason,
                        onChanged: (val) {
                          setState(() { selectedReason = val; });
                        },
                        contentPadding: EdgeInsets.zero,
                        activeColor: cs.primary,
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('İptal'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: selectedReason == null ? null : () {
                              ref.read(questionLoopProvider.notifier).reportQuestion(questionId);
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text('Raporunuz gönderildi.'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            },
                            child: const Text('Gönder'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCompletionSheet(int total) {
    final loopState = ref.read(questionLoopProvider);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        final answeredTotal = loopState.correctCount + loopState.wrongCount;
        final percentage = (answeredTotal > 0 ? (loopState.correctCount / answeredTotal) * 100 : 0.0);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber),
                const SizedBox(height: AppSizes.p16),
                Text(
                  'Harika İş Çıkardın!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  'Bu konudaki tüm soruları bitirdin.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: AppSizes.p24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _statItem(context, 'Doğru', '${loopState.correctCount}', Colors.green),
                    _statItem(context, 'Yanlış', '${loopState.wrongCount}', Colors.red),
                    _statItem(context, 'Başarı', '${percentage.toInt()}%', cs.primary),
                  ],
                ),
                const SizedBox(height: AppSizes.p32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      context.pop();
                      context.pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref.invalidate(allProgressProvider);
                      });
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Ana Sayfaya Dön', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statItem(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: color)),
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildQuestionCardWrapper(SoruModel soru) {
    switch (soru.type) {
      case 'flashcard':
        return FlashcardCard(
          key: ValueKey(soru.id),
          question: soru,
          onAnswer: (result) => _onAnswer(result, soru.id),
        );
      case 'multiple_choice':
        return MultipleChoiceCard(
          key: ValueKey(soru.id),
          question: soru,
          onAnswer: (result) => _onAnswer(result, soru.id),
        );
      case 'fill_in_the_blank':
        return FillBlankCard(
          key: ValueKey(soru.id),
          question: soru,
          onAnswer: (result) => _onAnswer(result, soru.id),
        );
      default:
        // Fallback for unknown type
        return Center(child: Text('Bilinmeyen soru tipi: ${soru.type}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch early to prevent autoDispose from unmounting the provider during _initResume async gaps
    final loopState = ref.watch(questionLoopProvider);

    if (_isLoadingResume) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title.isNotEmpty ? widget.title : 'Test Çözümü'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final sorularAsync = ref.watch(sorularByModeProvider((mode: widget.mode, ids: widget.ids)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title.isNotEmpty ? widget.title : 'Test Çözümü'),
        centerTitle: true,
        actions: [
          sorularAsync.when(
            data: (questions) {
              if (questions.isEmpty || loopState.currentIndex >= questions.length) {
                return const SizedBox.shrink();
              }
              final currentQId = questions[loopState.currentIndex].id;
              if (loopState.reportedQuestions.contains(currentQId)) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: const Icon(Icons.report_problem_outlined),
                tooltip: 'Soruyu Bildir',
                onPressed: () => _showReportSheet(currentQId),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: sorularAsync.when(
            data: (questions) {
              if (questions.isEmpty) return const SizedBox.shrink();
              final progress = (loopState.currentIndex + 1) / questions.length;
              return LinearProgressIndicator(
                value: progress,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (err, stack) => const SizedBox.shrink(),
          ),
        ),
      ),
      body: sorularAsync.when(
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Bu konuda henüz soru bulunmuyor.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Geri Dön'),
                  ),
                ],
              ),
            );
          }

          int currentIndex = loopState.currentIndex;

          return SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Soru ${currentIndex + 1} / ${questions.length}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 12),
                          const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text('${loopState.correctCount}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          const Icon(Icons.cancel_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Text('${loopState.wrongCount}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          if (loopState.streak > 1) ...[
                            const SizedBox(width: 12),
                            const Text('🔥', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 2),
                            Text('${loopState.streak}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ]
                      ),
                      if (currentIndex < questions.length)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(AppSizes.r16),
                          ),
                          child: Text(
                            questions[currentIndex].type.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Arka Plandaki Kart (Bir Sonraki Soru)
                      // BUG FIX: Only render background card during swipe animation to prevent glitch
                      if (currentIndex + 1 < questions.length && loopState.isAnimating)
                        Positioned.fill(
                          child: Transform.scale(
                            scale: 0.92,
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.p16),
                              child: IgnorePointer(
                                child: _buildQuestionCardWrapper(questions[currentIndex + 1]),
                              ),
                            ),
                          ),
                        ),

                      // Öndeki Kart (Güncel Soru)
                      if (currentIndex < questions.length)
                        _AnimatedQuestionCard(
                          slideDirection: loopState.slideDirection,
                          child: _buildQuestionCardWrapper(questions[currentIndex]),
                        ),
                    ],
                  ),
                ),
                // Removed the explicit Pass button below the stack per user request
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Sorular yüklenemedi: $err')),
      ),
    );
  }
}

class _AnimatedQuestionCard extends StatelessWidget {
  final Widget child;
  final String slideDirection;

  const _AnimatedQuestionCard({
    required this.child,
    required this.slideDirection,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    double leftPos = 0;
    double rightPos = 0;
    double topPos = 0;
    double bottomPos = 0;
    double angle = 0;

    if (slideDirection == 'left') {
      leftPos = -screenWidth;
      rightPos = screenWidth;
      angle = -0.15;
    } else if (slideDirection == 'right') {
      leftPos = screenWidth;
      rightPos = -screenWidth;
      angle = 0.15;
    } else if (slideDirection == 'up') {
      topPos = -screenHeight;
      bottomPos = screenHeight;
    }

    // Determine duration. Important to be Duration.zero when reverting 
    // to none to prevent snapping visual glitches
    final duration = slideDirection == 'none' ? Duration.zero : const Duration(milliseconds: 400);

    return AnimatedPositioned(
      duration: duration,
      curve: Curves.easeInBack,
      left: leftPos,
      right: rightPos,
      top: topPos,
      bottom: bottomPos,
      child: Transform.rotate(
        angle: angle,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.p16),
          child: child, // Explicit constraints removed; child is fully flexible inside Positioned
        ),
      ),
    );
  }
}
