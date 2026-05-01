import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/profile_provider.dart';
import '../services/auth_service.dart';

class SocialService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Ref _ref;

  SocialService(this._ref);

  Future<void> sendFriendRequest(String toUid) async {
    final fromUid = _ref.read(authServiceProvider).currentUser?.uid;
    if (fromUid == null || fromUid == toUid) return;

    await _db.collection('friend_requests').doc('${fromUid}_$toUid').set({
      'from_uid': fromUid,
      'to_uid': toUid,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptFriendRequest(String requestId, String fromUid, String toUid) async {
    // Update request status
    await _db.collection('friend_requests').doc(requestId).update({'status': 'accepted'});

    // Add as friends in both profiles
    await _db.collection('users').doc(fromUid).update({
      'friends': FieldValue.arrayUnion([toUid])
    });
    await _db.collection('users').doc(toUid).update({
      'friends': FieldValue.arrayUnion([fromUid])
    });
  }

  Future<List<({String uid, UserProfile profile})>> searchUsersByUsername(String username) async {
    final query = username.trim().toLowerCase().replaceAll('@', '');
    if (query.isEmpty) return [];
    
    final snapshot = await _db
        .collection('users')
        .where('username', isEqualTo: query)
        .limit(1)
        .get();

    return snapshot.docs.map((doc) => (uid: doc.id, profile: UserProfile.fromMap(doc.data()))).toList();
  }

  Future<List<({String uid, UserProfile profile})>> getUsersByIds(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    // Firestore whereIn supports up to 30 items
    final snapshot = await _db
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .get();

    return snapshot.docs.map((doc) => (uid: doc.id, profile: UserProfile.fromMap(doc.data()))).toList();
  }
}

final socialServiceProvider = Provider((ref) => SocialService(ref));

class FriendRequest {
  final String id;
  final String fromUid;
  final String toUid;
  final String status;

  FriendRequest({required this.id, required this.fromUid, required this.toUid, required this.status});

  factory FriendRequest.fromMap(String id, Map<String, dynamic> map) {
    return FriendRequest(
      id: id,
      fromUid: map['from_uid'] as String? ?? '',
      toUid: map['to_uid'] as String? ?? '',
      status: map['status'] as String? ?? 'pending',
    );
  }
}

final friendRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('friend_requests')
      .where('to_uid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((snap) => snap.docs.map((doc) => FriendRequest.fromMap(doc.id, doc.data())).toList());
});
