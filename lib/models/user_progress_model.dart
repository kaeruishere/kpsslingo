class UserProgressModel {
  final String soruId;
  final String konuId;
  final int dogruSayisi;
  final int yanlisSayisi;
  final int pasSayisi;
  final DateTime sonGorulme;
  final double ustePuani; 

  UserProgressModel({
    required this.soruId,
    required this.konuId,
    required this.dogruSayisi,
    required this.yanlisSayisi,
    this.pasSayisi = 0,
    required this.sonGorulme,
    required this.ustePuani,
  });

  factory UserProgressModel.fromJson(Map<String, dynamic> json) {
    return UserProgressModel(
      soruId: json['soruId'] as String? ?? '',
      konuId: json['konuId'] as String? ?? '',
      dogruSayisi: json['dogruSayisi'] as int? ?? 0,
      yanlisSayisi: json['yanlisSayisi'] as int? ?? 0,
      pasSayisi: json['pasSayisi'] as int? ?? 0,
      sonGorulme: json['sonGorulme'] != null 
          ? DateTime.parse(json['sonGorulme']) 
          : DateTime.now(),
      ustePuani: (json['ustePuani'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'soruId': soruId,
      'konuId': konuId,
      'dogruSayisi': dogruSayisi,
      'yanlisSayisi': yanlisSayisi,
      'pasSayisi': pasSayisi,
      'sonGorulme': sonGorulme.toIso8601String(),
      'ustePuani': ustePuani,
    };
  }
}
