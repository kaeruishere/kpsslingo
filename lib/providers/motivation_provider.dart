import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final motivationProvider = StreamProvider<String>((ref) {
  return FirebaseFirestore.instance
      .collection('motivation')
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return 'Başarı için çalışmaya devam et!';
        final docs = snapshot.docs;
        // Selection logic can be more complex, but for now simple random or first
        return docs.first.data()['text'] ?? 'Başarı için çalışmaya devam et!';
      });
});
