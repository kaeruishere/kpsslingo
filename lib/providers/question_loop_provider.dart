import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/progress_service.dart';

enum AnswerResult { correct, wrong, skipped }

class QuestionLoopState {
  final int currentIndex;
  final int correctCount;
  final int wrongCount;
  final String slideDirection; // 'none', 'left', 'right', 'up'
  final bool isAnimating;
  final int streak;
  final Set<String> reportedQuestions;

  QuestionLoopState({
    this.currentIndex = 0,
    this.correctCount = 0,
    this.wrongCount = 0,
    this.slideDirection = 'none',
    this.isAnimating = false,
    this.streak = 0,
    this.reportedQuestions = const {},
  });

  QuestionLoopState copyWith({
    int? currentIndex,
    int? correctCount,
    int? wrongCount,
    String? slideDirection,
    bool? isAnimating,
    int? streak,
    Set<String>? reportedQuestions,
  }) {
    return QuestionLoopState(
      currentIndex: currentIndex ?? this.currentIndex,
      correctCount: correctCount ?? this.correctCount,
      wrongCount: wrongCount ?? this.wrongCount,
      slideDirection: slideDirection ?? this.slideDirection,
      isAnimating: isAnimating ?? this.isAnimating,
      streak: streak ?? this.streak,
      reportedQuestions: reportedQuestions ?? this.reportedQuestions,
    );
  }
}

class QuestionLoopNotifier extends Notifier<QuestionLoopState> {
  @override
  QuestionLoopState build() {
    return QuestionLoopState();
  }

  void setAnimating(bool animating, [String direction = 'none']) {
    state = state.copyWith(isAnimating: animating, slideDirection: direction);
  }

  void recordAnswer(AnswerResult result) {
    int newCorrect = state.correctCount;
    int newWrong = state.wrongCount;
    int newStreak = state.streak;

    if (result == AnswerResult.correct) {
      newCorrect++;
      newStreak++;
    } else if (result == AnswerResult.wrong) {
      newWrong++;
      newStreak = 0; // Yanlışta streak sıfırlanır
    }

    state = state.copyWith(
      correctCount: newCorrect,
      wrongCount: newWrong,
      streak: newStreak,
    );
  }

  void reportQuestion(String questionId) {
    final nextState = Set<String>.from(state.reportedQuestions)..add(questionId);
    state = state.copyWith(reportedQuestions: nextState);
  }

  void nextQuestion(String konuId, String dersId) {
    final nextIndex = state.currentIndex + 1;
    state = state.copyWith(
      currentIndex: nextIndex,
      isAnimating: false,
      slideDirection: 'none',
    );
    // Asynchronously save resume state to Firestore
    ref.read(progressServiceProvider).updateSubjectResumePoint(konuId, dersId, nextIndex);
  }

  void setStartIndex(int index) {
    state = state.copyWith(currentIndex: index);
  }

  void reset() {
    state = QuestionLoopState();
  }
}

final questionLoopProvider = NotifierProvider.autoDispose<QuestionLoopNotifier, QuestionLoopState>(() {
  return QuestionLoopNotifier();
});
