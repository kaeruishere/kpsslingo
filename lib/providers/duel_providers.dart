import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/duel_room_model.dart';
import '../services/duel_service.dart';
import '../services/auth_service.dart';
import 'profile_provider.dart';
import 'auth_providers.dart';

final globalLeaderboardProvider = StreamProvider<List<UserProfile>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('total_xp', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => UserProfile.fromMap(doc.data())).toList());
});

final currentRoomProvider = StreamProvider.family<DuelRoomModel?, String>((ref, roomId) {
  return ref.watch(duelServiceProvider).listenToRoom(roomId);
});

final duelChallengesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('duel_challenges')
      .where('to_uid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .orderBy('created_at', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
});
