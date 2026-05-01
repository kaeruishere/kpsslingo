import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/social_service.dart';
import '../providers/profile_provider.dart';

/// Fetches the profiles of the user's friends
final friendProfilesProvider = FutureProvider<List<({String uid, UserProfile profile})>>((ref) async {
  final profileAsync = ref.watch(profileProvider);
  
  return profileAsync.when(
    data: (profile) async {
      final friends = profile.friendIds;
      if (friends.isEmpty) return [];
      
      final socialService = ref.read(socialServiceProvider);
      return await socialService.getUsersByIds(friends);
    },
    loading: () => [],
    error: (e, st) => [],
  );
});
