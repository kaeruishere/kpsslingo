class SubjectProgressModel {
  final String konuId;
  final String dersId;
  final int lastIndex;
  final DateTime lastUpdated;

  SubjectProgressModel({
    required this.konuId,
    required this.dersId,
    required this.lastIndex,
    required this.lastUpdated,
  });

  factory SubjectProgressModel.fromJson(Map<String, dynamic> json) {
    return SubjectProgressModel(
      konuId: json['konuId'] as String? ?? '',
      dersId: json['dersId'] as String? ?? '',
      lastIndex: json['lastIndex'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'konuId': konuId,
      'dersId': dersId,
      'lastIndex': lastIndex,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}
