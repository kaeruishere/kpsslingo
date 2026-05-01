import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/duel_providers.dart';
import '../core/constants/app_routes.dart';
import '../core/router/app_router.dart';
import '../services/duel_service.dart';
import '../providers/profile_provider.dart';

class DuelChallengeListener extends ConsumerWidget {
  final Widget child;
  const DuelChallengeListener({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(duelChallengesProvider, (previous, next) {
      final challenges = next.value ?? [];
      if (challenges.isNotEmpty && (previous?.value?.isEmpty ?? true)) {
        final challenge = challenges.first;
        final roomId = challenge['room_id'] as String;
        final fromUid = challenge['from_uid'] as String;
        
        // Fetch sender's name before showing SnackBar
        FirebaseFirestore.instance.collection('users').doc(fromUid).get().then((snap) {
          if (!snap.exists) return;
          final profile = UserProfile.fromMap(snap.data()!);
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Text(profile.avatarEmoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${profile.displayName} seni düelloya davet etti!',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        ref.read(duelServiceProvider).rejectChallenge(roomId);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                      child: const Text('REDDET', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ),
                  ],
                ),
                duration: const Duration(seconds: 15),
                backgroundColor: const Color(0xFF6B5CF6),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                action: SnackBarAction(
                  label: 'KABUL ET',
                  textColor: Colors.white,
                  onPressed: () {
                    ref.read(appRouterProvider).push(AppRoutes.duelGame, extra: roomId);
                  },
                ),
              ),
            );
          }
        });
      }
    });

    return child;
  }
}
