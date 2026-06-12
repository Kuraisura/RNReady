import 'mcq_models.dart';

/// One graded response. [response] holds whatever the player produced for this
/// question's type:
///   • MCQ            → int? (option index)
///   • Identification → String
///   • Enumeration    → `List<String>`
///   • Matching       → `Map<int,int>` (leftIndex → rightIndex)
class AnsweredQuestion {
  final QuizQuestion question;
  final Object? response;
  AnsweredQuestion(this.question, this.response);

  double get earned => question.grade(response);

  /// Fully correct (full marks). Used for the green/red review icon.
  bool get isCorrect => earned >= question.points;

  /// Partially correct — some but not all points (enumeration/matching).
  bool get isPartial => earned > 0 && earned < question.points;
}

class QuizResult {
  final List<AnsweredQuestion> answers;
  final Duration timeSpent;
  QuizResult(this.answers, this.timeSpent);

  int get totalQuestions => answers.length;
  int get correctCount => answers.where((a) => a.isCorrect).length;
  double get earnedPoints => answers.fold(0.0, (s, a) => s + a.earned);
  int get totalPoints => answers.fold(0, (s, a) => s + a.question.points);
  double get percent => totalPoints == 0 ? 0 : earnedPoints / totalPoints;
  bool get passed => percent >= 0.75; // typical nursing pass mark
}
