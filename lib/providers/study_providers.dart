import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ders_model.dart';
import '../models/konu_model.dart';
import '../models/user_progress_model.dart';
import '../services/firestore_service.dart';
import '../services/progress_service.dart';
import '../models/soru_model.dart';
import '../models/subject_progress_model.dart';
import '../models/study_mode.dart';

/// Fetches all lessons (Dersler)
final lessonsProvider = FutureProvider<List<DersModel>>((ref) async {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.getDersler();
});

/// Fetches subjects (Konular) for a given lesson ID
final subjectsProvider = FutureProvider.family<List<KonuModel>, String>((ref, dersId) async {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.getKonular(dersId);
});

/// Fetches all progress for the current user
final allProgressProvider = FutureProvider<List<UserProgressModel>>((ref) async {
  final progressService = ref.watch(progressServiceProvider);
  return progressService.getAllProgress();
});

final lastPlayedSubjectProvider = StreamProvider<SubjectProgressModel?>((ref) {
  final progressService = ref.watch(progressServiceProvider);
  return progressService.getLastPlayedSubjectStream();
});

final konuByPathProvider = FutureProvider.family<KonuModel?, ({String dersId, String konuId})>((ref, path) async {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.getKonuByPath(path.dersId, path.konuId);
});

/// Fetches all questions for a given subject ID
final sorularProvider = FutureProvider.family<List<SoruModel>, String>((ref, konuId) async {
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.getSorular(konuId: konuId);
});

final sorularByModeProvider = FutureProvider.family<List<SoruModel>, ({StudyMode mode, List<String>? ids})>((ref, params) async {
  final firestore = ref.watch(firestoreServiceProvider);
  
  List<SoruModel> questions;
  
  switch (params.mode) {
    case StudyMode.random:
      questions = await firestore.getAllSorular();
      questions.shuffle();
      break;
    case StudyMode.subject:
      if (params.ids == null || params.ids!.isEmpty) return [];
      questions = await firestore.getSorularByDersler(params.ids!);
      questions.shuffle();
      break;
    case StudyMode.topic:
      if (params.ids == null || params.ids!.isEmpty) return [];
      questions = await firestore.getSorularByKonular(params.ids!);
      break;
  }
  
  return questions;
});

/// Model for joining subject with its progress and counts
class SubjectWithProgress {
  final KonuModel subject;
  final double progress; // 0.0 to 1.0
  final int completedQuestions;
  final int totalQuestions;

  SubjectWithProgress({
    required this.subject,
    required this.progress,
    required this.completedQuestions,
    required this.totalQuestions,
  });
}

/// Model for lesson-level progress and aggregates
class LessonWithProgress {
  final DersModel lesson;
  final List<SubjectWithProgress> subjects;
  final int totalSubjects;
  final int totalTests;
  final int totalFlashcards;
  final int totalFills;
  final double progress; // Average of subjects

  LessonWithProgress({
    required this.lesson,
    required this.subjects,
    required this.totalSubjects,
    required this.totalTests,
    required this.totalFlashcards,
    required this.totalFills,
    required this.progress,
  });
}

/// Combines subjects and progress to calculate percentages
final subjectsWithProgressProvider = FutureProvider.family<List<SubjectWithProgress>, String>((ref, dersId) async {
  final subjects = await ref.watch(subjectsProvider(dersId).future);
  final progressList = await ref.watch(allProgressProvider.future);

  return subjects.map((subject) {
    final topicProgress = progressList.where((p) => p.konuId == subject.id).toList();
    
    final completed = topicProgress.length;
    final total = subject.soruSayisi > 0 ? subject.soruSayisi : 1; 
    
    return SubjectWithProgress(
      subject: subject,
      progress: (completed / total).clamp(0.0, 1.0),
      completedQuestions: completed,
      totalQuestions: subject.soruSayisi,
    );
  }).toList();
});

/// Aggregate provider for all lessons with their full statistics
final lessonsWithProgressProvider = FutureProvider<List<LessonWithProgress>>((ref) async {
  final lessons = await ref.watch(lessonsProvider.future);
  
  final List<LessonWithProgress> results = [];
  
  for (final lesson in lessons) {
    final subjectsWP = await ref.watch(subjectsWithProgressProvider(lesson.id).future);
    
    int tTests = 0;
    int tFlash = 0;
    int tFills = 0;
    double sumProgress = 0;

    for (final s in subjectsWP) {
      tTests += s.subject.testCount;
      tFlash += s.subject.flashcardCount;
      tFills += s.subject.fillCount;
      sumProgress += s.progress;
    }

    results.add(LessonWithProgress(
      lesson: lesson,
      subjects: subjectsWP,
      totalSubjects: subjectsWP.length,
      totalTests: tTests,
      totalFlashcards: tFlash,
      totalFills: tFills,
      progress: subjectsWP.isEmpty ? 0.0 : (sumProgress / subjectsWP.length),
    ));
  }
  
  return results;
});

final overallProgressProvider = FutureProvider<double>((ref) async {
  final lessonsWP = await ref.watch(lessonsWithProgressProvider.future);
  
  int totalCompleted = 0;
  int totalQuestions = 0;

  for (final lesson in lessonsWP) {
    for (final s in lesson.subjects) {
      totalCompleted += s.completedQuestions;
      totalQuestions += s.totalQuestions;
    }
  }
  
  if (totalQuestions == 0) return 0.0;
  return (totalCompleted / totalQuestions).clamp(0.0, 1.0);
});

class SelectedStudyIdsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => <String>{};
  
  void toggle(String id) {
    if (state.contains(id)) {
      state = <String>{...state}..remove(id);
    } else {
      state = <String>{...state}..add(id);
    }
  }

  void clear() => state = <String>{};
}

final selectedStudyIdsProvider = NotifierProvider<SelectedStudyIdsNotifier, Set<String>>(
  SelectedStudyIdsNotifier.new,
);
