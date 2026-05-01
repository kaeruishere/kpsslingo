import 'dart:math';

class LevelManager {
  /// Mevcut XP'ye göre olması gereken seviyeyi hesaplar
  /// Formül: Level = (XP / 100)^(1/1.5) -> Tersten hesaplama
  static int calculateLevel(int totalXp) {
    if (totalXp < 100) return 1;
    return (pow((totalXp / 100), (1 / 1.5))).floor() + 1;
  }

  /// Bir sonraki seviye için gereken toplam XP
  static int xpForLevel(int level) {
    if (level <= 1) return 0;
    return (100 * pow(level - 1, 1.5)).round();
  }
}
