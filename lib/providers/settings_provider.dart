import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

// ── Keys ───────────────────────────────────────────────────────
const _kSound         = 'sound';
const _kVibration     = 'vibration';
const _kNotifications = 'notifications';
const _kThemeMode     = 'themeMode';
const _kOnboarding     = 'hasSeenOnboarding';

// ── Settings state ─────────────────────────────────────────────
class AppSettings {
  final bool sound;
  final bool vibration;
  final bool notifications;
  final ThemeMode themeMode;
  final bool hasSeenOnboarding;

  const AppSettings({
    this.sound         = true,
    this.vibration     = true,
    this.notifications = true,
    this.themeMode     = ThemeMode.system,
    this.hasSeenOnboarding = false,
  });

  AppSettings copyWith({
    bool? sound,
    bool? vibration,
    bool? notifications,
    ThemeMode? themeMode,
    bool? hasSeenOnboarding,
  }) => AppSettings(
    sound:         sound         ?? this.sound,
    vibration:     vibration     ?? this.vibration,
    notifications: notifications ?? this.notifications,
    themeMode:     themeMode     ?? this.themeMode,
    hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
  );

  factory AppSettings.fromMap(Map<String, dynamic> map) => AppSettings(
    sound:         map[_kSound]         as bool?      ?? true,
    vibration:     map[_kVibration]     as bool?      ?? true,
    notifications: map[_kNotifications] as bool?      ?? true,
    themeMode:     ThemeMode.values[map[_kThemeMode] as int? ?? 0],
    hasSeenOnboarding: map[_kOnboarding] as bool?      ?? false,
  );

  Map<String, dynamic> toMap() => {
    _kSound:         sound,
    _kVibration:     vibration,
    _kNotifications: notifications,
    _kThemeMode:     themeMode.index,
    _kOnboarding:    hasSeenOnboarding,
  };
}

// ── Notifier ───────────────────────────────────────────────────
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  FirebaseFirestore get _db  => FirebaseFirestore.instance;
  String?           get _uid => ref.read(authServiceProvider).currentUser?.uid;

  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    final seenOnboarding = prefs.getBool(_kOnboarding) ?? false;

    final uid = _uid;
    if (uid == null) {
      return AppSettings(hasSeenOnboarding: seenOnboarding);
    }

    final doc = await _db.collection('users').doc(uid).collection('settings').doc('app').get();
    if (doc.exists && doc.data() != null) {
      return AppSettings.fromMap(doc.data()!).copyWith(
        hasSeenOnboarding: seenOnboarding,
      );
    }
    return AppSettings(hasSeenOnboarding: seenOnboarding);
  }

  Future<void> setSeenOnboarding(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboarding, v);
    state = AsyncData((state.value ?? const AppSettings()).copyWith(hasSeenOnboarding: v));
  }

  Future<void> setSound(bool v) async {
    state = AsyncData((state.value ?? const AppSettings()).copyWith(sound: v));
    await _persist({_kSound: v});
  }

  Future<void> setVibration(bool v) async {
    state = AsyncData((state.value ?? const AppSettings()).copyWith(vibration: v));
    await _persist({_kVibration: v});
  }

  Future<void> setNotifications(bool v) async {
    state = AsyncData((state.value ?? const AppSettings()).copyWith(notifications: v));
    await _persist({_kNotifications: v});
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = AsyncData((state.value ?? const AppSettings()).copyWith(themeMode: mode));
    await _persist({_kThemeMode: mode.index});
  }

  Future<void> _persist(Map<String, dynamic> data) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('settings').doc('app').set(data, SetOptions(merge: true));
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).value?.themeMode ?? ThemeMode.system;
});
