class SoruModel {
  final String id;
  final String konuId;
  final String dersId;
  final String text;
  final String answer;
  final String description;
  final String type; // e.g. "multiple_choice", "fill_blank", "flashcard"
  final int zorluk; // 1, 2, or 3
  final Map<String, String>? secenekler;
  final List<String>? alternatifCevaplar;

  SoruModel({
    required this.id,
    required this.konuId,
    required this.dersId,
    required this.text,
    required this.answer,
    required this.description,
    required this.type,
    required this.zorluk,
    this.secenekler,
    this.alternatifCevaplar,
  });

  factory SoruModel.fromJson(Map<String, dynamic> json) {
    return SoruModel(
      id: json['id'] as String? ?? '',
      konuId: json['konu_id'] as String? ?? json['konuId'] as String? ?? '',
      dersId: json['ders_id'] as String? ?? json['dersId'] as String? ?? '',
      text: json['soru'] as String? ?? json['text'] as String? ?? '',
      answer: json['cevap'] as String? ?? json['answer'] as String? ?? '',
      description: json['aciklama'] as String? ?? json['description'] as String? ?? '',
      type: json['type'] as String? ?? '',
      zorluk: json['zorluk'] as int? ?? 1,
      secenekler: json['secenekler'] != null 
          ? Map<String, String>.from(json['secenekler']) 
          : null,
      alternatifCevaplar: json['alternatif_cevaplar'] != null 
          ? List<String>.from(json['alternatif_cevaplar']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'konu_id': konuId,
      'ders_id': dersId,
      'soru': text,
      'cevap': answer,
      'aciklama': description,
      'type': type,
      'zorluk': zorluk,
      if (secenekler != null) 'secenekler': secenekler,
      if (alternatifCevaplar != null) 'alternatif_cevaplar': alternatifCevaplar,
    };
  }
}
