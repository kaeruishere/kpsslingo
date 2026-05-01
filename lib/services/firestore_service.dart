import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ders_model.dart';
import '../models/konu_model.dart';
import '../models/soru_model.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(FirebaseFirestore.instance);
});

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService(this._firestore);

  Future<List<DersModel>> getDersler() async {
    final snapshot = await _firestore.collection('dersler').orderBy('sira').get();
    return snapshot.docs.map((doc) => DersModel.fromJson({'id': doc.id, ...doc.data()})).toList();
  }

  Future<List<KonuModel>> getKonular(String dersId) async {
    final snapshot = await _firestore
        .collection('dersler')
        .doc(dersId)
        .collection('konular')
        .orderBy('sira')
        .get();
    return snapshot.docs.map((doc) => KonuModel.fromJson({
      'id': doc.id,
      'dersId': dersId,
      ...doc.data(),
    })).toList();
  }

  Future<KonuModel?> getKonuByPath(String dersId, String konuId) async {
    final doc = await _firestore
        .collection('dersler')
        .doc(dersId)
        .collection('konular')
        .doc(konuId)
        .get();
        
    if (doc.exists && doc.data() != null) {
      return KonuModel.fromJson({
        'id': doc.id,
        'dersId': dersId,
        ...doc.data()!
      });
    }
    return null;
  }

  Future<List<SoruModel>> getSorular({
    required String konuId,
    String? type,
    int? zorluk,
  }) async {
    Query query = _firestore.collection('sorular').where('konu_id', isEqualTo: konuId);
    
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }
    if (zorluk != null) {
      query = query.where('zorluk', isEqualTo: zorluk);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => SoruModel.fromJson({'id': doc.id, ...doc.data() as Map<String, dynamic>})).toList();
  }

  Future<List<SoruModel>> getSorularByKonular(List<String> konuIds) async {
    if (konuIds.isEmpty) return [];
    // Firestore whereIn supports up to 30 items. 
    // If more are needed, we chunk it.
    final snapshot = await _firestore.collection('sorular').where('konu_id', whereIn: konuIds).get();
    return snapshot.docs.map((doc) => SoruModel.fromJson({'id': doc.id, ...doc.data() as Map<String, dynamic>})).toList();
  }

  Future<List<SoruModel>> getSorularByDersler(List<String> dersIds) async {
    if (dersIds.isEmpty) return [];
    final snapshot = await _firestore.collection('sorular').where('ders_id', whereIn: dersIds).get();
    return snapshot.docs.map((doc) => SoruModel.fromJson({'id': doc.id, ...doc.data() as Map<String, dynamic>})).toList();
  }

  Future<List<SoruModel>> getAllSorular() async {
    final snapshot = await _firestore.collection('sorular').get();
    return snapshot.docs.map((doc) => SoruModel.fromJson({'id': doc.id, ...doc.data() as Map<String, dynamic>})).toList();
  }


  Future<SoruModel?> getSoru(String soruId) async {
    final doc = await _firestore.collection('sorular').doc(soruId).get();
    if (doc.exists && doc.data() != null) {
      return SoruModel.fromJson({'id': doc.id, ...doc.data()!});
    }
    return null;
  }

  Future<List<SoruModel>> getDuelQuestions({String? lessonId, String? subjectId, List<String>? questionTypes, int limit = 10}) async {
    Query query = _firestore.collection('sorular');
    if (lessonId != null && lessonId != 'all') {
      query = query.where('ders_id', isEqualTo: lessonId);
    }
    if (subjectId != null) {
      query = query.where('konu_id', isEqualTo: subjectId);
    }
    if (questionTypes != null && questionTypes.isNotEmpty) {
      query = query.where('type', whereIn: questionTypes);
    }
    
    final snapshot = await query.limit(limit * 2).get(); // Fetch double and shuffle
    final list = snapshot.docs.map((doc) => SoruModel.fromJson({'id': doc.id, ...doc.data() as Map<String, dynamic>})).toList();
    list.shuffle();
    return list.take(limit).toList();
  }
}
