import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../core/utils/level_manager.dart';

// ── Keys ───────────────────────────────────────────────────────
const _kAvatarEmoji  = 'avatar_emoji';
const _kDisplayName  = 'display_name';
const _kStreak       = 'streak';
const _kTotalXp      = 'total_xp';
const _kLevel        = 'level';
const _kSelectedExam = 'selected_exam';
const _kSetup        = 'has_completed_setup';
const _kLastLoginDate = 'last_login_date';
const _kLastQuestionDate = 'last_question_date';
const _kDuelWins = 'duel_wins';
const _kDuelLosses = 'duel_losses';
const _kDuelDraws = 'duel_draws';
const _kDuelTotal = 'duel_total';
const _kFriends = 'friends';
const _kUsername = 'username';
const _kShareActivity = 'share_activity';
const _defaultEmoji  = '🦉';

// ── State ──────────────────────────────────────────────────────
class UserProfile {
  final String avatarEmoji;
  final String displayName;
  final int streak;
  final int totalXp;
  final int level;
  final String? selectedExam;
  final bool hasCompletedSetup;
  final DateTime? lastLoginDate;
  final DateTime? lastQuestionDate;
  final int duelWins;
  final int duelLosses;
  final int duelDraws;
  final int duelTotal;
  final List<String> friendIds;
  final String username;
  final bool shareActivity;

  const UserProfile({
    this.avatarEmoji = _defaultEmoji,
    this.displayName = '',
    this.streak = 0,
    this.totalXp = 0,
    this.level = 1,
    this.selectedExam,
    this.hasCompletedSetup = false,
    this.lastLoginDate,
    this.lastQuestionDate,
    this.duelWins = 0,
    this.duelLosses = 0,
    this.duelDraws = 0,
    this.duelTotal = 0,
    this.friendIds = const [],
    this.username = '',
    this.shareActivity = true,
  });

  UserProfile copyWith({
    String? avatarEmoji,
    String? displayName,
    int? streak,
    int? totalXp,
    int? level,
    String? selectedExam,
    bool? hasCompletedSetup,
    DateTime? lastLoginDate,
    DateTime? lastQuestionDate,
    int? duelWins,
    int? duelLosses,
    int? duelDraws,
    int? duelTotal,
    List<String>? friendIds,
    String? username,
    bool? shareActivity,
  }) => UserProfile(
    avatarEmoji: avatarEmoji ?? this.avatarEmoji,
    displayName: displayName ?? this.displayName,
    streak: streak ?? this.streak,
    totalXp: totalXp ?? this.totalXp,
    level: level ?? this.level,
    selectedExam: selectedExam ?? this.selectedExam,
    hasCompletedSetup: hasCompletedSetup ?? this.hasCompletedSetup,
    lastLoginDate: lastLoginDate ?? this.lastLoginDate,
    lastQuestionDate: lastQuestionDate ?? this.lastQuestionDate,
    duelWins: duelWins ?? this.duelWins,
    duelLosses: duelLosses ?? this.duelLosses,
    duelDraws: duelDraws ?? this.duelDraws,
    duelTotal: duelTotal ?? this.duelTotal,
    friendIds: friendIds ?? this.friendIds,
    username: username ?? this.username,
    shareActivity: shareActivity ?? this.shareActivity,
  );

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
    avatarEmoji: map[_kAvatarEmoji] as String? ?? _defaultEmoji,
    displayName: map[_kDisplayName] as String? ?? '',
    streak: map[_kStreak] as int? ?? 0,
    totalXp: map[_kTotalXp] as int? ?? 0,
    level: map[_kLevel] as int? ?? 1,
    selectedExam: map[_kSelectedExam] as String?,
    hasCompletedSetup: map[_kSetup] as bool? ?? false,
    lastLoginDate: map[_kLastLoginDate] != null ? (map[_kLastLoginDate] as Timestamp).toDate() : null,
    lastQuestionDate: map[_kLastQuestionDate] != null ? (map[_kLastQuestionDate] as Timestamp).toDate() : null,
    duelWins: map[_kDuelWins] as int? ?? 0,
    duelLosses: map[_kDuelLosses] as int? ?? 0,
    duelDraws: map[_kDuelDraws] as int? ?? 0,
    duelTotal: map[_kDuelTotal] as int? ?? 0,
    friendIds: (map[_kFriends] as List<dynamic>?)?.map((e) => e as String).toList() ?? const [],
    username: map[_kUsername] as String? ?? '',
    shareActivity: map[_kShareActivity] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    _kAvatarEmoji: avatarEmoji,
    _kDisplayName: displayName,
    _kStreak: streak,
    _kTotalXp: totalXp,
    _kLevel: level,
    _kSelectedExam: selectedExam,
    _kSetup: hasCompletedSetup,
    if (lastLoginDate != null) _kLastLoginDate: Timestamp.fromDate(lastLoginDate!),
    if (lastQuestionDate != null) _kLastQuestionDate: Timestamp.fromDate(lastQuestionDate!),
    _kDuelWins: duelWins,
    _kDuelLosses: duelLosses,
    _kDuelDraws: duelDraws,
    _kDuelTotal: duelTotal,
    _kFriends: friendIds,
    _kUsername: username,
    _kShareActivity: shareActivity,
  };
}

// ── Notifier ───────────────────────────────────────────────────
class ProfileNotifier extends AsyncNotifier<UserProfile> {
  FirebaseFirestore get _db  => FirebaseFirestore.instance;
  
  @override
  Future<UserProfile> build() async {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    if (user == null) {
      debugPrint('[ProfileNotifier] No user, returning default profile');
      return const UserProfile();
    }

    debugPrint('[ProfileNotifier] Initializing profile for UID: ${user.uid}');
    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        var profile = UserProfile.fromMap(data);
        debugPrint('[ProfileNotifier] Existing profile found for ${user.uid}');

        // ── Google Name Sync ──
        if (profile.displayName.isEmpty && user.displayName != null && user.displayName!.isNotEmpty) {
          debugPrint('[ProfileNotifier] Syncing Google name for existing account');
          profile = profile.copyWith(displayName: user.displayName);
          // Fire and forget persistence to avoid blocking the build
          _persist(user.uid, {_kDisplayName: user.displayName})
            .catchError((e) => debugPrint('[ProfileNotifier] Google name sync error: $e'));
        }
        
        return profile;
      } else {
        debugPrint('[ProfileNotifier] No profile found, creating new for ${user.uid}');
        // New user or no data: Initialize with Google display name or default
        final initialName = user.displayName ?? (user.isAnonymous ? 'Misafir' : '');
        final profile = UserProfile(displayName: initialName);
        
        if (initialName.isNotEmpty) {
          // Fire and forget persistence
          _persist(user.uid, profile.toMap())
            .catchError((e) => debugPrint('[ProfileNotifier] New profile persistence error: $e'));
        }
        return profile;
      }
    } catch (e) {
      debugPrint('[ProfileNotifier] Error in build(): $e');
      rethrow;
    }
  }

  Future<void> updateEmoji(String emoji) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    
    state = AsyncData((state.value ?? const UserProfile()).copyWith(avatarEmoji: emoji));
    await _persist(uid, {_kAvatarEmoji: emoji});
  }

  Future<void> updateDisplayName(String name) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    state = AsyncData((state.value ?? const UserProfile()).copyWith(displayName: name));
    await _persist(uid, {_kDisplayName: name});
  }

  Future<void> setCompletedSetup(bool v) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    state = AsyncData((state.value ?? const UserProfile()).copyWith(hasCompletedSetup: v));
    await _persist(uid, {_kSetup: v});
  }

  Future<void> updateSelectedExam(String? examId) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    state = AsyncData((state.value ?? const UserProfile()).copyWith(selectedExam: examId));
    await _persist(uid, {_kSelectedExam: examId});
  }

  Future<void> updateXp(int basePoints) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    
    final currentState = state.value ?? const UserProfile();
    int streak = currentState.streak;
    final now = DateTime.now();
    
    if (currentState.lastQuestionDate != null) {
      final lastMidnight = DateTime(currentState.lastQuestionDate!.year, currentState.lastQuestionDate!.month, currentState.lastQuestionDate!.day);
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final diff = todayMidnight.difference(lastMidnight).inDays;
      
      if (diff == 1) {
        streak += 1;
      } else if (diff > 1) {
        streak = 1;
      } else if (diff == 0 && streak == 0) {
        streak = 1;
      }
    } else {
      streak = 1;
    }

    int points = basePoints;
    if (points > 0 && streak >= 3) {
      points = (points * 1.1).round();
    }

    int newXp = (currentState.totalXp + points).clamp(0, 999999);
    int newLevel = LevelManager.calculateLevel(newXp);

    state = AsyncData(currentState.copyWith(
      totalXp: newXp,
      level: newLevel,
      streak: streak,
      lastQuestionDate: now,
    ));

    await _persist(uid, {
      _kTotalXp: newXp,
      _kLevel: newLevel,
      _kStreak: streak,
      _kLastQuestionDate: FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateLoginTimestamp() async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;
    
    final currentState = state.value ?? const UserProfile();
    final now = DateTime.now();

    int streak = currentState.streak;
    if (currentState.lastQuestionDate != null) {
      final lastMidnight = DateTime(currentState.lastQuestionDate!.year, currentState.lastQuestionDate!.month, currentState.lastQuestionDate!.day);
      final todayMidnight = DateTime(now.year, now.month, now.day);
      if (todayMidnight.difference(lastMidnight).inDays > 1) {
        streak = 0;
      }
    }

    state = AsyncData(currentState.copyWith(
      lastLoginDate: now,
      streak: streak,
    ));

    await _persist(uid, {
      _kLastLoginDate: FieldValue.serverTimestamp(),
      _kStreak: streak,
    });
  }

  Future<void> updateUsername(String username) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    state = AsyncData((state.value ?? const UserProfile()).copyWith(username: username));
    await _persist(uid, {_kUsername: username});
  }

  Future<void> toggleShareActivity(bool share) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    state = AsyncData((state.value ?? const UserProfile()).copyWith(shareActivity: share));
    await _persist(uid, {_kShareActivity: share});
  }

  Future<void> _persist(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, UserProfile>(
  ProfileNotifier.new,
);
