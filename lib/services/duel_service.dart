import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/duel_room_model.dart';
import 'auth_service.dart';
import 'firestore_service.dart';

class DuelService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Ref _ref;

  DuelService(this._ref);

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // Avoid O, 0, I, 1
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<DuelRoomModel?> createRoom({String? lessonId, String? subjectId, List<String>? questionTypes}) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) return null;

    final code = _generateRoomCode();
    final docRef = _db.collection('rooms').doc();
    
    final room = DuelRoomModel(
      id: docRef.id,
      code: code,
      hostId: user.uid,
      lessonId: lessonId,
      subjectId: subjectId,
      status: DuelRoomStatus.waiting,
      createdAt: DateTime.now(),
      questionTypes: questionTypes,
    );

    await docRef.set(room.toMap());
    return room;
  }

  Future<DuelRoomModel?> sendChallenge(String toUid, {
    String? lessonId, 
    String? subjectId, 
    List<String>? questionTypes
  }) async {
    final fromUid = _ref.read(authServiceProvider).currentUser?.uid;
    if (fromUid == null) return null;

    final code = _generateRoomCode();
    final docRef = _db.collection('rooms').doc();
    
    final room = DuelRoomModel(
      id: docRef.id,
      code: code,
      hostId: fromUid,
      opponentId: toUid,
      lessonId: lessonId,
      subjectId: subjectId,
      status: DuelRoomStatus.waiting,
      createdAt: DateTime.now(),
      questionTypes: questionTypes,
    );

    await docRef.set({
      ...room.toMap(),
      'is_challenge': true,
      'created_at': FieldValue.serverTimestamp(),
    });

    // 1. Create a notification for the opponent
    await _db.collection('duel_challenges').doc(docRef.id).set({
      'from_uid': fromUid,
      'to_uid': toUid,
      'room_id': docRef.id,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });

    // 2. IMPORTANT: Pre-fetch questions so the match is ready to start
    await startMatch(docRef.id);
    
    return room;
  }

  Future<void> setReady(String roomId, String userId, bool isReady) async {
    final roomDoc = _db.collection('rooms').doc(roomId);
    final roomSnap = await roomDoc.get();
    if (!roomSnap.exists) return;
    
    final room = DuelRoomModel.fromMap(roomSnap.id, roomSnap.data()!);
    final isHost = room.hostId == userId;
    
    await roomDoc.update({
      isHost ? 'host_ready' : 'opponent_ready': isReady,
    });
  }

  Future<DuelRoomModel?> joinRoom(String code) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) return null;

    final snapshot = await _db
        .collection('rooms')
        .where('code', isEqualTo: code.toUpperCase())
        .where('status', isEqualTo: 'waiting')
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final doc = snapshot.docs.first;
    final roomData = doc.data();
    
    if (roomData['host_id'] == user.uid) return DuelRoomModel.fromMap(doc.id, roomData);

    await doc.reference.update({
      'opponent_id': user.uid,
    });
    
    // Auto-update notification if exists
    final challengeSnap = await _db.collection('duel_challenges').doc(doc.id).get();
    if (challengeSnap.exists) {
      await challengeSnap.reference.update({'status': 'accepted'});
    }

    // Trigger startMatch to initialize questions but stay in waiting until ready
    await startMatch(doc.id);

    final updatedDoc = await doc.reference.get();
    return DuelRoomModel.fromMap(updatedDoc.id, updatedDoc.data()!);
  }

  Future<DuelRoomModel?> findRandomMatch({String? lessonId}) async {
    final user = _ref.read(authServiceProvider).currentUser;
    if (user == null) return null;

    // First attempt to find a waiting room
    var query = _db
        .collection('rooms')
        .where('status', isEqualTo: 'waiting')
        .where('host_id', isNotEqualTo: user.uid)
        .where('opponent_id', isNull: true);

    if (lessonId != null && lessonId != 'all') {
      query = query.where('lesson_id', isEqualTo: lessonId);
    }

    final snapshot = await query.limit(1).get();

    if (snapshot.docs.isEmpty) {
      // No match found, create a new room
      return createRoom(lessonId: lessonId);
    }

    final doc = snapshot.docs.first;
    await doc.reference.update({
      'opponent_id': user.uid,
    });

    // Trigger startMatch to initialize questions
    await startMatch(doc.id);

    final updatedDoc = await doc.reference.get();
    return DuelRoomModel.fromMap(updatedDoc.id, updatedDoc.data()!);
  }

  Future<void> startMatch(String roomId) async {
    final roomDoc = _db.collection('rooms').doc(roomId);
    final roomSnap = await roomDoc.get();
    if (!roomSnap.exists) return;
    
    final room = DuelRoomModel.fromMap(roomSnap.id, roomSnap.data()!);
    // Don't set active yet, just initialize questions if not already done
    if (room.questionIds.isNotEmpty) return;

    final questions = await _ref.read(firestoreServiceProvider).getDuelQuestions(
      lessonId: room.lessonId,
      subjectId: room.subjectId,
      questionTypes: room.questionTypes,
      limit: 10,
    );
    
    await roomDoc.update({
      'question_ids': questions.map((q) => q.id).toList(),
      'last_activity': FieldValue.serverTimestamp(),
    });
  }

  // When both are ready, game screen can trigger activateMatch
  Future<void> activateMatch(String roomId) async {
    await _db.collection('rooms').doc(roomId).update({
      'status': DuelRoomStatus.active.name,
      'last_activity': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitAnswer(String roomId, String userId, String answer, bool isCorrect, double secondsTaken) async {
    final roomDoc = _db.collection('rooms').doc(roomId);
    final roomSnap = await roomDoc.get();
    if (!roomSnap.exists) return;
    
    final room = DuelRoomModel.fromMap(roomSnap.id, roomSnap.data()!);
    final isHost = room.hostId == userId;
    
    // Calculate points
    int points = 0;
    if (isCorrect) {
      const basePoints = 100;
      double bonus = 0;
      if (secondsTaken <= 10) {
        bonus = 100;
      } else if (secondsTaken <= 30) {
        bonus = (30 - secondsTaken) * 5;
      }
      points = basePoints + bonus.toInt();
    }

    final answerData = {
      'answer': answer,
      'time': secondsTaken,
      'is_correct': isCorrect,
      'points': points,
    };

    final updateData = {
      isHost ? 'host_answers.${room.currentQuestionIndex}' : 'opponent_answers.${room.currentQuestionIndex}': answerData,
      isHost ? 'host_score' : 'opponent_score': FieldValue.increment(points),
      'last_activity': FieldValue.serverTimestamp(),
    };

    await roomDoc.update(updateData);
    
    // Check if both answered to advance question
    final updatedSnap = await roomDoc.get();
    final updatedRoom = DuelRoomModel.fromMap(updatedSnap.id, updatedSnap.data()!);
    final qIndex = updatedRoom.currentQuestionIndex.toString();
    
    if (updatedRoom.hostAnswers.containsKey(qIndex) && updatedRoom.opponentAnswers.containsKey(qIndex)) {
      if (updatedRoom.currentQuestionIndex < 9) {
        await roomDoc.update({
          'current_question_index': FieldValue.increment(1),
        });
      } else {
        await roomDoc.update({
          'status': 'finished',
        });
      }
    }
  }

  Stream<DuelRoomModel?> listenToRoom(String roomId) {
    return _db.collection('rooms').doc(roomId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return DuelRoomModel.fromMap(doc.id, doc.data()!);
    });
  }

  Future<void> rejectChallenge(String roomId) async {
    // 1. Update challenge status
    await _db.collection('duel_challenges').doc(roomId).update({'status': 'rejected'});
    // 2. Update room status to finished/cancelled
    await _db.collection('rooms').doc(roomId).update({'status': 'finished'});
  }
}

final duelServiceProvider = Provider((ref) => DuelService(ref));
