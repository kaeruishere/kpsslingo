import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/soru_model.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/question_loop_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/utils/interaction_feedback.dart';

class FlashcardCard extends ConsumerStatefulWidget {
  final SoruModel question;
  final void Function(AnswerResult result) onAnswer;

  const FlashcardCard({
    super.key,
    required this.question,
    required this.onAnswer,
  });

  @override
  ConsumerState<FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends ConsumerState<FlashcardCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;

  double _dragDX = 0;
  double _dragDY = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flipCard() {
    final settings = ref.read(settingsProvider).value;
    InteractionFeedback.flip(settings?.sound ?? true, settings?.vibration ?? true);

    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _submitAnswer(AnswerResult result) {
    setState(() {
      _dragDX = 0;
      _dragDY = 0;
    });
    widget.onAnswer(result);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isFront ? _flipCard : null, // Sadece ön yüzdeyken tıklandığında dönsün
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final val = _animation.value;
          final isFrontNow = val < 0.5;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(val * 3.1415926535897932);

          return Transform(
            transform: transform,
            alignment: FractionalOffset.center,
            child: isFrontNow
                ? _buildFront(context)
                : Transform(
                    transform: Matrix4.identity()..rotateY(3.1415926535897932),
                    alignment: FractionalOffset.center,
                    child: _buildSwipeableBack(context),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront(BuildContext context) {
    return _buildCardBase(
      context,
      Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.touch_app_rounded, size: 48, color: Colors.grey),
                const SizedBox(height: AppSizes.p24),
                Text(
                  widget.question.text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSizes.p32),
                Text(
                  'Cevabı görmek için karta dokun',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton.filledTonal(
              onPressed: () => _submitAnswer(AnswerResult.skipped),
              icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
              tooltip: 'Pas Geç',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeableBack(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    // Add dynamic colors / hints when dragging
    Color borderColor = cs.outlineVariant.withValues(alpha: 0.5);
    Color overlayColor = Colors.transparent;
    
    if (_dragDX > 50) {
      borderColor = Colors.green;
      overlayColor = Colors.green.withValues(alpha: 0.05);
    } else if (_dragDX < -50) {
      borderColor = Colors.red;
      overlayColor = Colors.red.withValues(alpha: 0.05);
    } else if (_dragDY < -50) {
      borderColor = Colors.orange;
      overlayColor = Colors.orange.withValues(alpha: 0.05);
    }

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _dragDX += details.delta.dx;
          _dragDY += details.delta.dy;
        });
      },
      onPanEnd: (details) {
        if (_dragDX > 100) {
          _submitAnswer(AnswerResult.correct);
        } else if (_dragDX < -100) {
          _submitAnswer(AnswerResult.wrong);
        } else if (_dragDY < -100) {
          _submitAnswer(AnswerResult.skipped);
        } else {
          // snap back
          setState(() {
            _dragDX = 0;
            _dragDY = 0;
          });
        }
      },
      child: Transform.translate(
        offset: Offset(_dragDX, _dragDY),
        child: Transform.rotate(
           angle: _dragDX * 0.002, // slight rotation mimicking Tinder
           child: _buildCardBase(
             context,
             Column(
               children: [
                 Expanded(
                   child: SingleChildScrollView(
                     child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          const SizedBox(height: AppSizes.p48),
                          Text(
                           'Cevap',
                           style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                 color: cs.primary,
                                 fontWeight: FontWeight.bold,
                               ),
                         ),
                         const SizedBox(height: AppSizes.p16),
                         Text(
                           widget.question.answer,
                           textAlign: TextAlign.center,
                           style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                 fontWeight: FontWeight.bold,
                                 color: Colors.green,
                               ),
                         ),
                         if (widget.question.description.isNotEmpty) ...[
                           const SizedBox(height: AppSizes.p32),
                           const Divider(),
                           const SizedBox(height: AppSizes.p24),
                           Text(
                             widget.question.description,
                             textAlign: TextAlign.center,
                             style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
                           ),
                         ],
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(height: AppSizes.p16),
                 Text('Kaydır ya da Seç', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.grey)),
                 const SizedBox(height: AppSizes.p16),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                   children: [
                     _buildRoundButton(context, Icons.close_rounded, Colors.red, () => _submitAnswer(AnswerResult.wrong)),
                     _buildRoundButton(context, Icons.check_rounded, Colors.green, () => _submitAnswer(AnswerResult.correct)),
                   ],
                 ),
               ],
             ),
             customBorderColor: borderColor,
             customOverlayColor: overlayColor,
           ),
        ),
      ),
    );
  }

  Widget _buildRoundButton(BuildContext context, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.p16),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.1),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: Icon(icon, color: color, size: 32),
      ),
    );
  }

  Widget _buildCardBase(BuildContext context, Widget child, {Color? customBorderColor, Color? customOverlayColor}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: customOverlayColor == null ? cs.surfaceContainerHighest : Color.alphaBlend(customOverlayColor, cs.surfaceContainerHighest),
        borderRadius: BorderRadius.circular(AppSizes.r24),
        border: Border.all(color: customBorderColor ?? cs.outlineVariant.withValues(alpha: 0.5), width: customBorderColor != null ? 3 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
