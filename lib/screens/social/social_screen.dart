import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/router/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/social_providers.dart';
import '../../services/social_service.dart';
import '../../services/duel_service.dart';
import '../../providers/study_providers.dart';
import '../../models/ders_model.dart';
import '../../models/konu_model.dart';
import '../../providers/auth_providers.dart';

class SocialScreen extends ConsumerStatefulWidget {
  const SocialScreen({super.key});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen> {
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  List<({String uid, UserProfile profile})> _searchResults = [];

  void _search() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) {
      if (mounted) setState(() { _searchResults = []; _isSearching = false; });
      return;
    }
    setState(() => _isSearching = true);
    final results = await ref.read(socialServiceProvider).searchUsersByUsername(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sosyal'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Akış'),
              Tab(text: 'Arkadaşlar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Aktivite Akışı Sekmesi
            Consumer(
              builder: (context, ref, child) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Aktivite Akışı (Feed)\nBurada arkadaşlarınızın tamamladığı testler ve kazandıkları başarımlar görüntülenecek.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),

            // Arkadaşlar Sekmesi
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.p16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: '@kullaniciadi ara',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (_) => _search(),
                        ),
                      ),
                      const SizedBox(width: AppSizes.p8),
                      FilledButton(
                        onPressed: _search,
                        child: const Text('Bul'),
                      ),
                    ],
                  ),
                ),
                if (_isSearching)
                  const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())
                else if (_searchResults.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final res = _searchResults[index];
                        return ListTile(
                          leading: CircleAvatar(child: Text(res.profile.avatarEmoji)),
                          title: Text(res.profile.displayName),
                          subtitle: Text('@${res.profile.username}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add_rounded),
                            onPressed: () {
                              ref.read(socialServiceProvider).sendFriendRequest(res.uid);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('İstek gönderildi.')));
                              setState(() { _searchResults = []; _searchCtrl.clear(); });
                            },
                          ),
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: Consumer(
                      builder: (context, ref, child) {
                        final friendsAsync = ref.watch(friendProfilesProvider);
                        
                        return friendsAsync.when(
                          data: (friends) {
                            if (friends.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text(
                                    'Henüz arkadaş eklemedin.\nYukarıdan aratıp ekleyebilirsin.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              itemCount: friends.length,
                              itemBuilder: (context, index) {
                                final res = friends[index];
                                return ListTile(
                                  leading: CircleAvatar(child: Text(res.profile.avatarEmoji)),
                                  title: Text(res.profile.displayName),
                                  subtitle: Text('@${res.profile.username} • Çevrimiçi'),
                                  trailing: FilledButton.tonal(
                                    onPressed: () => _showDuelLobby(context, res.uid, res.profile.displayName),
                                    child: const Text('Düello'),
                                  ),
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, st) => Center(child: Text('Hata: $e')),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDuelLobby(BuildContext context, String targetUid, String targetName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DuelLobbyBottomSheet(targetUid: targetUid, targetName: targetName),
    );
  }
}

class _DuelLobbyBottomSheet extends ConsumerStatefulWidget {
  final String targetUid;
  final String targetName;
  const _DuelLobbyBottomSheet({required this.targetUid, required this.targetName});

  @override
  ConsumerState<_DuelLobbyBottomSheet> createState() => _DuelLobbyBottomSheetState();
}

class _DuelLobbyBottomSheetState extends ConsumerState<_DuelLobbyBottomSheet> {
  String? _selectedLessonId;
  String? _selectedSubjectId;
  final Set<String> _selectedTypes = {'multiple_choice'};
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(lessonsProvider);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1F2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.targetName} ile Düello', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 24),
          
          const Text('Ders Seçin', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          lessonsAsync.when(
            data: (lessons) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: lessons.map((l) {
                  final isSelected = _selectedLessonId == l.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(l.name),
                      selected: isSelected,
                      onSelected: (val) => setState(() {
                        _selectedLessonId = val ? l.id : null;
                        _selectedSubjectId = null;
                      }),
                      backgroundColor: Colors.white10,
                      selectedColor: const Color(0xFF6B5CF6),
                      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                    ),
                  );
                }).toList(),
              ),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Text('Hata!'),
          ),

          if (_selectedLessonId != null) ...[
            const SizedBox(height: 24),
            const Text('Konu Seçin (Opsiyonel)', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ref.watch(subjectsProvider(_selectedLessonId!)).when(
              data: (subjects) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: subjects.map((s) {
                    final isSelected = _selectedSubjectId == s.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(s.name),
                        selected: isSelected,
                        onSelected: (val) => setState(() {
                          _selectedSubjectId = val ? s.id : null;
                        }),
                        backgroundColor: Colors.white10,
                        selectedColor: const Color(0xFF6B5CF6).withValues(alpha: 0.5),
                        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                      ),
                    );
                  }).toList(),
                ),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('Konu yüklenemedi.'),
            ),
          ],

          const SizedBox(height: 24),
          const Text('Soru Türleri', style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _TypeFilterChip(label: 'Test', type: 'multiple_choice', selected: _selectedTypes.contains('multiple_choice'), onToggle: _toggleType),
              _TypeFilterChip(label: 'Flashcard', type: 'flashcard', selected: _selectedTypes.contains('flashcard'), onToggle: _toggleType),
              _TypeFilterChip(label: 'Boşluk Doldurma', type: 'fill_blank', selected: _selectedTypes.contains('fill_blank'), onToggle: _toggleType),
            ],
          ),

          const SizedBox(height: 40),
          FilledButton(
            onPressed: (_selectedLessonId == null || _selectedTypes.isEmpty || _isSending) 
              ? null : _startChallenge,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6B5CF6),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSending 
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('DAVET GÖNDER', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _toggleType(String type) {
    setState(() {
      if (_selectedTypes.contains(type)) {
        if (_selectedTypes.length > 1) _selectedTypes.remove(type);
      } else {
        _selectedTypes.add(type);
      }
    });
  }

  void _startChallenge() async {
    setState(() => _isSending = true);
    final room = await ref.read(duelServiceProvider).sendChallenge(
      widget.targetUid,
      lessonId: _selectedLessonId,
      subjectId: _selectedSubjectId,
      questionTypes: _selectedTypes.toList(),
    );
    
    if (mounted) {
      if (room != null) {
        Navigator.pop(context);
        context.push(AppRoutes.duelGame, extra: room.id);
      } else {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hata oluştu.')));
      }
    }
  }
}

class _TypeFilterChip extends StatelessWidget {
  final String label;
  final String type;
  final bool selected;
  final Function(String) onToggle;

  const _TypeFilterChip({required this.label, required this.type, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onToggle(type),
      backgroundColor: Colors.white10,
      selectedColor: const Color(0xFF6B5CF6),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70),
    );
  }
}
