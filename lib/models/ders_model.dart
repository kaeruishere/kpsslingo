class DersModel {
  final String id;
  final String name;
  final int sira;

  DersModel({
    required this.id,
    required this.name,
    this.sira = 0,
  });

  factory DersModel.fromJson(Map<String, dynamic> json) {
    return DersModel(
      id: json['id'] as String? ?? '',
      name: json['baslik'] as String? ?? json['name'] as String? ?? '',
      sira: json['sira'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'baslik': name,
      'sira': sira,
    };
  }
}
