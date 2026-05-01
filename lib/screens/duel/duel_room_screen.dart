import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../models/duel_room_model.dart';
import '../../providers/duel_providers.dart';
import '../../providers/profile_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/loading_indicator.dart';

class DuelRoomScreen extends ConsumerWidget {
  final String roomId;

  const DuelRoomScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roomAsync = ref.watch(currentRoomProvider(roomId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return roomAsync.when(
      loading: () => const Scaffold(body: Center(child: LoadingIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('Hata: $e'))),
      data: (room) {
        if (room == null) {
          return const Scaffold(body: Center(child: Text('Oda bulunamadı.')));
        }

        final currentUser = ref.watch(authServiceProvider).currentUser;
        final isHost = room.hostId == currentUser?.uid;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Oda: ${room.code}'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(AppSizes.p24),
            child: Column(
              children: [
                const SpacerBy(height: AppSizes.p32),
                Text(
                  room.status == DuelRoomStatus.waiting 
                      ? 'Rakip Bekleniyor...' 
                      : 'Rakip Bulundu!',
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppSizes.p8),
                Text(
                  room.status == DuelRoomStatus.waiting 
                      ? 'Arkadaşına kodu göndererek onu davet edebilirsin.'
                      : 'Düello başlamak üzere...',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSizes.p48),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _PlayerAvatar(uid: room.hostId, label: 'Kurucu'),
                    const Icon(Icons.bolt_rounded, size: 48, color: Colors.amber),
                    room.opponentId != null 
                        ? _PlayerAvatar(uid: room.opponentId!, label: 'Rakip')
                        : _WaitingAvatar(),
                  ],
                ),
                
                const SizedBox(height: AppSizes.p64),
                if (room.status == DuelRoomStatus.waiting)
                  _RoomCodeCard(code: room.code),
                  
                const Spacer(),
                if (room.status == DuelRoomStatus.active)
                  FilledButton.icon(
                    onPressed: () {
                      context.pushNamed(AppRoutes.duelGame, pathParameters: {'roomId': room.id});
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.p20, horizontal: AppSizes.p48),
                    ),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('BAŞLAT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                const SizedBox(height: AppSizes.p32),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PlayerAvatar extends ConsumerWidget {
  final String uid;
  final String label;

  const _PlayerAvatar({required this.uid, required this.label});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ideally we'd have a provider that fetches user by UID
    // For now we'll just show a placeholder
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          child: const Text('👤', style: TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: 8),
        Text(label, style: tt.labelSmall),
        Text('Yükleniyor...', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _WaitingAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.surfaceContainerHigh,
          child: const CircularProgressIndicator(),
        ),
        const SizedBox(height: 8),
        Text('Bekleniyor', style: tt.labelSmall),
        Text('...', style: tt.titleSmall),
      ],
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  final String code;

  const _RoomCodeCard({required this.code});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSizes.p24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: AppSizes.defaultBorderRadius,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Text('ODA KODU', style: tt.labelMedium?.copyWith(letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(
            code,
            style: tt.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              // Copy to clipboard
            },
            icon: const Icon(Icons.copy_rounded),
            label: const Text('Kodu Kopyala'),
          ),
        ],
      ),
    );
  }
}

class SpacerBy extends StatelessWidget {
  final double? width;
  final double? height;
  const SpacerBy({super.key, this.width, this.height});
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}
