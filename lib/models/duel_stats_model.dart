class DuelStatsModel {
  final int totalDuels;
  final int wins;
  final int losses;
  final int draws;
  final double winRate;

  const DuelStatsModel({
    this.totalDuels = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.winRate = 0.0,
  });

  factory DuelStatsModel.fromJson(Map<String, dynamic> json) {
    return DuelStatsModel(
      totalDuels: json['totalDuels'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      winRate: (json['winRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalDuels': totalDuels,
      'wins': wins,
      'losses': losses,
      'draws': draws,
      'winRate': winRate,
    };
  }
}
