import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/duel_providers.dart';
import '../../models/duel_room_model.dart';
import '../../core/constants/app_constants.dart'; // added if needed

class DuelInvitationScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DuelInvitationScreen({super.key, required this.roomId});

  @override
  ConsumerState<DuelInvitationScreen> createState() => _DuelInvitationScreenState();
}

class _DuelInvitationScreenState extends ConsumerState<DuelInvitationScreen> {
  late Timer _timer;
  int _secondsLeft = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft > 0) {
        setState(() => _secondsLeft--);
      } else {
        _timer.cancel();
        context.pop();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomProvider(widget.roomId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Listen for opponent
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
        leading: IconButton(onPressed: () => context.pop(), icon: Icon(Icons.arrow_back, color: cs.onSurface)),
        title: Text('Davet', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
      ),
      body: roomAsync.when(
        data: (room) {
          if (room == null) return Center(child: Text('Oda bulunamadı', style: TextStyle(color: cs.onSurface)));
          
          final codeChars = room.code.split('');

          return SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Text('Davet Kodu', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),
                
                // Code Boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: codeChars.map((char) => Container(
                    width: 45,
                    height: 55,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(char, style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                  )).toList(),
                ),
                
                const SizedBox(height: 32),
                
                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: room.code));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kod kopyalandı!')));
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: cs.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.copy_rounded, color: cs.primary, size: 18),
                          label: Text('Kodu Kopyala', style: TextStyle(color: cs.primary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            // TODO: Share logic
                          },
                          padding: const EdgeInsets.all(12),
                          icon: Icon(Icons.share_outlined, color: cs.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Spacer(),
                
                // Status
                Icon(Icons.hourglass_empty_rounded, color: cs.primary, size: 48),
                const SizedBox(height: 16),
                Text('Rakip bekleniyor...', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                const SizedBox(height: 8),
                Text(
                  _formatTime(_secondsLeft),
                  style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.primary),
                ),
                Text('Süre dolunca oda otomatik kapanır', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                
                const Spacer(),
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text('İptal Et', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Hata: $e', style: TextStyle(color: cs.error))),
      ),
    );
  }
}
