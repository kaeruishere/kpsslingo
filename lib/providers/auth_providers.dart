import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'profile_provider.dart';
import 'settings_provider.dart';

/// This provider listens to auth changes and resets all user-dependent providers
/// when the UID changes (e.g., sign-out, sign-in to different account).
final authStateListenerProvider = Provider<void>((ref) {
  final authState = ref.watch(authStateProvider);

  // We only care about the transition, so we invalidate and let build() handle
  // the specific state logic based on the new (or null) UID.
  authState.whenData((user) {
    // Note: invalidating profile and settings ensures they re-fetch for the new UID
    ref.invalidate(profileProvider);
    ref.invalidate(settingsProvider);
  });
});
