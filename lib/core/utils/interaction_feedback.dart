import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class InteractionFeedback {
  static final AudioPlayer _correctPlayer = AudioPlayer();
  static final AudioPlayer _wrongPlayer = AudioPlayer();
  static final AudioPlayer _flipPlayer = AudioPlayer();

  static Future<void> init() async {
    try {
      // Global ayarlar: iOS sessiz modda çalma ve Android odak yönetimi
      await AudioPlayer.global.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.assistanceSonification,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));
      
      // Kaynakları önceden ayarla (Opsiyonel ama hızlı tetikleme için iyi)
      await _correctPlayer.setSource(AssetSource('sounds/correct.mp3'));
      await _wrongPlayer.setSource(AssetSource('sounds/wrong.mp3'));
      await _flipPlayer.setSource(AssetSource('sounds/flip.mp3'));
    } catch (e) {
      print('Audio init error: $e');
    }
  }

  static Future<void> correct(bool soundEnabled, bool vibrationEnabled) async {
    if (soundEnabled) {
      try {
        await _correctPlayer.stop();
        await _correctPlayer.play(AssetSource('sounds/correct.mp3'));
      } catch (e) {
        debugPrint('Correct sound error: $e');
      }
    }
    if (vibrationEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  static Future<void> wrong(bool soundEnabled, bool vibrationEnabled) async {
    if (soundEnabled) {
      try {
        await _wrongPlayer.stop();
        await _wrongPlayer.play(AssetSource('sounds/wrong.mp3'));
      } catch (e) {
        debugPrint('Wrong sound error: $e');
      }
    }
    if (vibrationEnabled) {
      HapticFeedback.heavyImpact();
    }
  }

  static Future<void> flip(bool soundEnabled, bool vibrationEnabled) async {
    if (soundEnabled) {
      try {
        await _flipPlayer.stop();
        await _flipPlayer.play(AssetSource('sounds/flip.mp3'));
      } catch (e) {
        debugPrint('Flip sound error: $e');
      }
    }
    if (vibrationEnabled) {
      HapticFeedback.selectionClick();
    }
  }
}
