import 'package:cloud_firestore/cloud_firestore.dart';

class ExamModel {
  final String id;
  final String name;
  final DateTime date;

  ExamModel({
    required this.id,
    required this.name,
    required this.date,
  });

  factory ExamModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExamModel(
      id: doc.id,
      name: data['name'] ?? '',
      date: DateTime.parse(data['date'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'date': date.toIso8601String(),
  };

  Duration get timeLeft => date.difference(DateTime.now());
  int get daysLeft => timeLeft.inDays;
}
