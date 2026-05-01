import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_progress_model.dart';
import '../models/subject_progress_model.dart';
import '../providers/question_loop_provider.dart';
import 'auth_service.dart';
import '../providers/profile_provider.dart';

final progressServiceProvider = Provider<ProgressService>((ref) {
  return ProgressService(
    FirebaseFirestore.instance, 
    ref.watch(authServiceProvider),
    ref,
  );
});

class ProgressService {
  final FirebaseFirestore _firestore;
  final AuthService _authService;
  final Ref _ref;

  ProgressService(this._firestore, this._authService, this._ref);

  String? get currentUserId => _authService.currentUser?.uid;

  Future<void> saveAnswer(String soruId, String konuId, AnswerResult result, String tip) async {
    final uid = currentUserId;
    if (uid == null) return;

    // Trigger Gamification (XP & Level Tracker)
    int points = 0;
    if (result == AnswerResult.correct) {
      points = tip == 'fill_blank' ? 15 : 10;
    } else if (result == AnswerResult.wrong) {
      points = -2;
    }
    
    if (points != 0) {
      _ref.read(profileProvider.notifier).updateXp(points);
    }

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .doc(soruId);

    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);

      final int isCorrect = result == AnswerResult.correct ? 1 : 0;
      final int isWrong = result == AnswerResult.wrong ? 1 : 0;
      final int isSkipped = result == AnswerResult.skipped ? 1 : 0;

      if (!snapshot.exists) {
        final newProgress = UserProgressModel(
          soruId: soruId,
          konuId: konuId,
          dogruSayisi: isCorrect,
          yanlisSayisi: isWrong,
          pasSayisi: isSkipped,
          sonGorulme: DateTime.now(),
          ustePuani: 0.0, 
        );
        transaction.set(docRef, newProgress.toJson());
      } else {
        final currentProgress = UserProgressModel.fromJson({'soruId': snapshot.id, ...snapshot.data()!});
        final updatedProgress = UserProgressModel(
          soruId: currentProgress.soruId,
          konuId: konuId, // Ensure it's set or updated
          dogruSayisi: currentProgress.dogruSayisi + isCorrect,
          yanlisSayisi: currentProgress.yanlisSayisi + isWrong,
          pasSayisi: currentProgress.pasSayisi + isSkipped,
          sonGorulme: DateTime.now(),
          ustePuani: currentProgress.ustePuani,
        );
        transaction.update(docRef, updatedProgress.toJson());
      }
    });
  }

  Future<void> updateSubjectResumePoint(String konuId, String dersId, int lastIndex) async {
    final uid = currentUserId;
    if (uid == null) return;

    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('subject_progress')
        .doc(konuId);

    final model = SubjectProgressModel(
      konuId: konuId,
      dersId: dersId,
      lastIndex: lastIndex,
      lastUpdated: DateTime.now(),
    );

    await docRef.set(model.toJson(), SetOptions(merge: true));
  }

  Future<SubjectProgressModel?> getSubjectResumePoint(String konuId) async {
    final uid = currentUserId;
    if (uid == null) return null;

    final doc = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subject_progress')
        .doc(konuId)
        .get();

    if (!doc.exists) return null;
    return SubjectProgressModel.fromJson(doc.data()!);
  }

  Future<SubjectProgressModel?> getLastPlayedSubject() async {
    final uid = currentUserId;
    if (uid == null) return null;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('subject_progress')
        .orderBy('lastUpdated', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return SubjectProgressModel.fromJson(snapshot.docs.first.data());
  }

  Stream<SubjectProgressModel?> getLastPlayedSubjectStream() {
    final uid = currentUserId;
    if (uid == null) return Stream.value(null);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('subject_progress')
        .orderBy('lastUpdated', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) => snapshot.docs.isEmpty ? null : SubjectProgressModel.fromJson(snapshot.docs.first.data()));
  }

  Future<List<UserProgressModel>> getAllProgress() async {
    final uid = currentUserId;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('progress')
        .get();

    return snapshot.docs.map((doc) => UserProgressModel.fromJson({'soruId': doc.id, ...doc.data()})).toList();
  }

  Future<List<String>> getWeakSubjects() async {
    // Placeholder logic for weak subjects
    // Returns a list of konuId strings
    return [];
  }
}
