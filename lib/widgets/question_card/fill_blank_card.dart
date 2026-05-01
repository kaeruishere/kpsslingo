import 'package:flutter/material.dart';

import '../../../models/soru_model.dart';
import '../../../core/constants/app_constants.dart';

import '../../../providers/question_loop_provider.dart';

class FillBlankCard extends StatefulWidget {
  final SoruModel question;
  final void Function(AnswerResult result) onAnswer;

  const FillBlankCard({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<FillBlankCard> createState() => _FillBlankCardState();
}

class _FillBlankCardState extends State<FillBlankCard> {
  final _controller = TextEditingController();
  bool _isAnswered = false;
  bool _isCorrect = false;

  void _checkAnswer() {
    if (_controller.text.trim().isEmpty) return;

    final input = _controller.text.trim().toLowerCase();
    final correctAnswer = widget.question.answer.toLowerCase();
    final alternatives = {...(widget.question.alternatifCevaplar ?? [])}
        .map((e) => e.toLowerCase())
        .toSet();

    bool correct = false;
    if (input == correctAnswer || alternatives.contains(input)) {
      correct = true;
    }

    setState(() {
      _isAnswered = true;
      _isCorrect = correct;
    });
  }

  void _submit() {
    widget.onAnswer(_isCorrect ? AnswerResult.correct : AnswerResult.wrong);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSizes.r24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isAnswered)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => widget.onAnswer(AnswerResult.skipped),
                icon: const Icon(Icons.keyboard_double_arrow_up_rounded, size: 20),
                label: const Text('Pas Geç'),
                style: TextButton.styleFrom(
                  foregroundColor: cs.secondary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          // Soru Metni
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.p24),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSizes.r16),
            ),
            child: Text(
              widget.question.text,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: AppSizes.p32),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Input Area
                  Text('Cevabınız:', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: AppSizes.p8),
                  TextField(
                    controller: _controller,
                    enabled: !_isAnswered,
                    decoration: InputDecoration(
                      hintText: 'Buraya yazın...',
                      filled: true,
                      fillColor: _isAnswered
                          ? (_isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1))
                          : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r16),
                        borderSide: BorderSide(
                          color: _isAnswered
                              ? (_isCorrect ? Colors.green : Colors.red)
                              : cs.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r16),
                        borderSide: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r16),
                        borderSide: BorderSide(color: cs.primary, width: 2),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.r16),
                        borderSide: BorderSide(
                          color: _isAnswered ? (_isCorrect ? Colors.green : Colors.red) : cs.outlineVariant,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _checkAnswer(),
                  ),
                  const SizedBox(height: AppSizes.p24),

                  // Sonuç ve Açıklama
                  if (_isAnswered) ...[
                    if (!_isCorrect) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSizes.p16),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.r12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.green),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Doğru Cevap:', style: TextStyle(color: Colors.green, fontSize: 12)),
                                  Text(
                                    widget.question.answer,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.p16),
                    ],
                    if (widget.question.description.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSizes.p16),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppSizes.r16),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline_rounded, color: cs.primary, size: 20),
                                const SizedBox(width: 8),
                                Text('Açıklama', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(widget.question.description),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.p24),
                    ],
                  ],
                ],
              ),
            ),
          ),
          
          if (_isAnswered)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _checkAnswer,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Kontrol Et', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }
}
