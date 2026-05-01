class KonuModel {
  final String id;
  final String dersId;
  final String name;
  final int sira;
  final int testCount;
  final int flashcardCount;
  final int fillCount;

  KonuModel({
    required this.id,
    required this.dersId,
    required this.name,
    this.sira = 0,
    this.testCount = 0,
    this.flashcardCount = 0,
    this.fillCount = 0,
  });

  int get soruSayisi => testCount + flashcardCount + fillCount;

  factory KonuModel.fromJson(Map<String, dynamic> json) {
    return KonuModel(
      id: json['id'] as String? ?? '',
      dersId: json['dersId'] as String? ?? '',
      name: json['baslik'] as String? ?? json['name'] as String? ?? '',
      sira: json['sira'] as int? ?? 0,
      testCount: json['testCount'] as int? ?? json['soru_sayisi_test'] as int? ?? 0,
      flashcardCount: json['flashcardCount'] as int? ?? json['soru_sayisi_flashcard'] as int? ?? 0,
      fillCount: json['fillCount'] as int? ?? json['soru_sayisi_fill'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dersId': dersId,
      'baslik': name,
      'sira': sira,
      'testCount': testCount,
      'flashcardCount': flashcardCount,
      'fillCount': fillCount,
    };
  }
}
