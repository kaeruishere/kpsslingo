import 'package:flutter/material.dart';

import '../../../models/soru_model.dart';
import '../../../core/constants/app_constants.dart';

import '../../../providers/question_loop_provider.dart';

class MultipleChoiceCard extends StatefulWidget {
  final SoruModel question;
  final void Function(AnswerResult result) onAnswer;

  const MultipleChoiceCard({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  State<MultipleChoiceCard> createState() => _MultipleChoiceCardState();
}

class _MultipleChoiceCardState extends State<MultipleChoiceCard> {
  String? _selectedOption;
  bool _isAnswered = false;

  void _handleSelect(String key) {
    if (_isAnswered) return;

    setState(() {
      _selectedOption = key;
      _isAnswered = true;
    });
  }

  void _submit() {
    if (!_isAnswered || _selectedOption == null) return;
    final isCorrect = _selectedOption == widget.question.answer;
    widget.onAnswer(isCorrect ? AnswerResult.correct : AnswerResult.wrong);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final secenekler = widget.question.secenekler ?? {};

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
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: AppSizes.p24),

          // Şıklar
          Expanded(
            child: Scrollbar(
              child: ListView(
                children: [
                  for (final entry in secenekler.entries)
                    Builder(
                      builder: (context) {
                        final key = entry.key; // A, B, C...
                        final text = entry.value;

                        Color? bgColor;
                        Color? borderColor;
                        IconData? trailingIcon;
                        Color? textColor;

                        if (_isAnswered) {
                          if (key == widget.question.answer) {
                            bgColor = Colors.green.withValues(alpha: 0.1);
                            borderColor = Colors.green;
                            trailingIcon = Icons.check_circle_rounded;
                            textColor = Colors.green;
                          } else if (key == _selectedOption) {
                            bgColor = Colors.red.withValues(alpha: 0.1);
                            borderColor = Colors.red;
                            trailingIcon = Icons.cancel_rounded;
                            textColor = Colors.red;
                          } else {
                            bgColor = cs.surfaceContainerLowest;
                            borderColor = cs.outlineVariant.withValues(alpha: 0.3);
                          }
                        } else {
                          if (key == _selectedOption) {
                            bgColor = cs.primaryContainer;
                            borderColor = cs.primary;
                          } else {
                            bgColor = cs.surfaceContainerLowest;
                            borderColor = cs.outlineVariant.withValues(alpha: 0.5);
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSizes.p12),
                          child: InkWell(
                            onTap: () => _handleSelect(key),
                            borderRadius: BorderRadius.circular(AppSizes.r16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p16),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(AppSizes.r16),
                                border: Border.all(color: borderColor, width: 2),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isAnswered && key == widget.question.answer
                                          ? Colors.green
                                          : (_isAnswered && key == _selectedOption
                                              ? Colors.red
                                              : cs.surfaceContainerHighest),
                                    ),
                                    child: Text(
                                      key,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isAnswered && (key == widget.question.answer || key == _selectedOption)
                                            ? Colors.white
                                            : cs.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.p16),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: _selectedOption == key ? FontWeight.bold : FontWeight.normal,
                                            color: textColor,
                                          ),
                                    ),
                                  ),
                                  if (trailingIcon != null) ...[
                                    const SizedBox(width: 12),
                                    Icon(trailingIcon, color: textColor),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // Açıklama alanı ve geçiş butonu
          if (_isAnswered) ...[
            if (widget.question.description.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(AppSizes.p16),
                margin: const EdgeInsets.only(bottom: AppSizes.p16),
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
                        Text('Çözüm', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(widget.question.description),
                  ],
                ),
              ),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Devam Et', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else const SizedBox(height: 56), // Placeholder for button height so layout doesn't jump
        ],
      ),
    );
  }
}
