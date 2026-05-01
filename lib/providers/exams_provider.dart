import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/exam_model.dart';

final examsProvider = StreamProvider<List<ExamModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('exams')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(ExamModel.fromFirestore).toList());
});
