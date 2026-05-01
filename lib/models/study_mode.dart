enum StudyMode {
  random,
  subject,
  topic,
}

extension StudyModeX on StudyMode {
  String get name {
    switch (this) {
      case StudyMode.random:
        return 'random';
      case StudyMode.subject:
        return 'subject';
      case StudyMode.topic:
        return 'topic';
    }
  }

  static StudyMode fromString(String value) {
    switch (value) {
      case 'random':
        return StudyMode.random;
      case 'subject':
        return StudyMode.subject;
      case 'topic':
      default:
        return StudyMode.topic;
    }
  }
}
