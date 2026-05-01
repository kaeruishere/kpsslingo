import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/duel_providers.dart';
import '../../providers/profile_provider.dart';
import '../../models/duel_room_model.dart';

class DuelMatchmakingScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DuelMatchmakingScreen({super.key, required this.roomId});

  @override
  ConsumerState<DuelMatchmakingScreen> createState() => _DuelMatchmakingScreenState();
}

class _DuelMatchmakingScreenState extends ConsumerState<DuelMatchmakingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  late Timer _countdownTimer;
  int _secondsRemaining = 30;
  final List<String> _tips = [
    "Soruları kaydederek profil sayfanızdan soru çözümlerine ulaşabilirsiniz.",
    "Hızlı cevap vererek ek puan kazanabilirsin!",
    "Düello sonunda kazandığın XP ile liderlik tablosunda yükselebilirsin.",
    "Yanlış cevaplar puanını düşürmez ama zaman kaybettirir."
  ];
  late String _currentTip;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _currentTip = _tips[Random().nextInt(_tips.length)];
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _countdownTimer.cancel();
        _onTimeout();
      }
    });
  }

  void _onTimeout() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rakip bulunamadı. Lütfen tekrar deneyin.')),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _countdownTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomProvider(widget.roomId));
    final profile = ref.watch(profileProvider).value;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Listen for opponent joining
    ref.listen(currentRoomProvider(widget.roomId), (previous, next) {
      if (next.value?.opponentId != null && next.value?.status == DuelRoomStatus.active) {
        context.go(AppRoutes.duelGame, extra: widget.roomId);
      }
    });

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back, color: cs.onSurface),
        ),
        title: Text('Eşleşme', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSizes.p24),
            // Exam Capsule
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flash_on_rounded, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  roomAsync.when(
                    data: (room) => Text(room?.lessonId?.toUpperCase() ?? 'KPSS', style: tt.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                    loading: () => Text('...', style: tt.labelMedium?.copyWith(color: cs.primary)),
                    error: (_, __) => Text('KPSS', style: tt.labelMedium?.copyWith(color: cs.primary)),
                  ),
                ],
              ),
            ),
            const Spacer(),
            
            // Radar Animation
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _radarController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: const Size(280, 280),
                      painter: RadarPainter(_radarController.value, cs.primary),
                    );
                  },
                ),
                // User & Searching Nodes
                SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sen (Left)
                      Positioned(
                        left: 40,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
                              child: CircleAvatar(
                                radius: 30,
                                backgroundColor: cs.surfaceContainerLow,
                                child: Text(profile?.avatarEmoji ?? '👤', style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('SEN', style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      // Arıyor (Right)
                      Positioned(
                        right: 40,
                        child: Column(
                          children: [
                            Opacity(
                                opacity: 0.3,
                                child: CircleAvatar(
                                  radius: 34,
                                  backgroundColor: cs.surfaceContainerLow,
                                  child: Icon(Icons.fingerprint_rounded, color: cs.onSurface, size: 30),
                                ),
                            ),
                            const SizedBox(height: 8),
                            Text('ARANIYOR', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      // Center Icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.compare_arrows_rounded, color: cs.onSurfaceVariant, size: 28),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Spacer(),
            
            // Tip Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.onSurface.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_outline_rounded, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentTip,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.p32),
            
            // Matchmaking Status & Progress
            Text('Rakip aranıyor...', style: tt.titleSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.p48),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: _secondsRemaining / 30,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DÜELLOYA SON', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                      Text('${_secondsRemaining}s', style: tt.labelSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            TextButton(
              onPressed: () => context.pop(),
              child: Text('İptal', style: tt.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(height: AppSizes.p24),
          ],
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double value;
  final Color primaryColor;
  RadarPainter(this.value, this.primaryColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = primaryColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw circles
    canvas.drawCircle(center, size.width / 2, paint);
    canvas.drawCircle(center, size.width / 3, paint);
    canvas.drawCircle(center, size.width / 6, paint);

    // Draw scanning sweep
    final sweepPaintFill = Paint()
      ..shader = SweepGradient(
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.3),
        ],
        stops: const [0.75, 1.0],
        transform: GradientRotation(value * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: size.width / 2))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, size.width / 2, sweepPaintFill);
    
    // Draw scanning line
    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
      
    final angle = value * 2 * pi;
    final lineEnd = Offset(
      center.dx + (size.width / 2) * cos(angle),
      center.dy + (size.width / 2) * sin(angle),
    );
    canvas.drawLine(center, lineEnd, linePaint);
  }

  @override
  bool shouldRepaint(RadarPainter oldDelegate) => true;
}
