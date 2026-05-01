import 'package:cloud_firestore/cloud_firestore.dart';

enum DuelRoomStatus { waiting, active, finished }

class DuelRoomModel {
  final String id;
  final String code;
  final String hostId;
  final String? opponentId;
  final String? lessonId;
  final String? subjectId;
  final DuelRoomStatus status;
  final DateTime createdAt;
  
  // Gameplay fields
  final int hostScore;
  final int opponentScore;
  final List<String> questionIds;
  final int currentQuestionIndex;
  final Map<String, dynamic> hostAnswers;
  final Map<String, dynamic> opponentAnswers;
  final DateTime? lastActivity;

  // Sync fields
  final bool hostReady;
  final bool opponentReady;
  final List<String>? questionTypes;

  DuelRoomModel({
    required this.id,
    required this.code,
    required this.hostId,
    this.opponentId,
    this.lessonId,
    this.subjectId,
    this.status = DuelRoomStatus.waiting,
    required this.createdAt,
    this.hostScore = 0,
    this.opponentScore = 0,
    this.questionIds = const [],
    this.currentQuestionIndex = 0,
    this.hostAnswers = const {},
    this.opponentAnswers = const {},
    this.lastActivity,
    this.hostReady = false,
    this.opponentReady = false,
    this.questionTypes,
  });

  factory DuelRoomModel.fromMap(String id, Map<String, dynamic> map) {
    return DuelRoomModel(
      id: id,
      code: map['code'] as String? ?? '',
      hostId: map['host_id'] as String? ?? '',
      opponentId: map['opponent_id'] as String?,
      lessonId: map['lesson_id'] as String?,
      subjectId: map['subject_id'] as String?,
      status: DuelRoomStatus.values.firstWhere(
        (e) => e.name == (map['status'] as String? ?? 'waiting'),
        orElse: () => DuelRoomStatus.waiting,
      ),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      hostScore: map['host_score'] as int? ?? 0,
      opponentScore: map['opponent_score'] as int? ?? 0,
      questionIds: List<String>.from(map['question_ids'] as List? ?? []),
      currentQuestionIndex: map['current_question_index'] as int? ?? 0,
      hostAnswers: map['host_answers'] as Map<String, dynamic>? ?? {},
      opponentAnswers: map['opponent_answers'] as Map<String, dynamic>? ?? {},
      lastActivity: (map['last_activity'] as Timestamp?)?.toDate(),
      hostReady: map['host_ready'] as bool? ?? false,
      opponentReady: map['opponent_ready'] as bool? ?? false,
      questionTypes: (map['question_types'] as List?)?.map((e) => e as String).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'host_id': hostId,
      'opponent_id': opponentId,
      'lesson_id': lessonId,
      'subject_id': subjectId,
      'status': status.name,
      'created_at': Timestamp.fromDate(createdAt),
      'host_score': hostScore,
      'opponent_score': opponentScore,
      'question_ids': questionIds,
      'current_question_index': currentQuestionIndex,
      'host_answers': hostAnswers,
      'opponent_answers': opponentAnswers,
      'last_activity': lastActivity != null ? Timestamp.fromDate(lastActivity!) : null,
      'host_ready': hostReady,
      'opponent_ready': opponentReady,
      'question_types': questionTypes,
    };
  }
}
