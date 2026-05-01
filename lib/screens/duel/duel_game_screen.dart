import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../models/duel_room_model.dart';
import '../../models/soru_model.dart';
import '../../providers/duel_providers.dart';
import '../../providers/profile_provider.dart';
import '../../services/duel_service.dart';
import '../../services/firestore_service.dart';
import '../../services/auth_service.dart';

class DuelGameScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DuelGameScreen({super.key, required this.roomId});

  @override
  ConsumerState<DuelGameScreen> createState() => _DuelGameScreenState();
}

class _DuelGameScreenState extends ConsumerState<DuelGameScreen> with TickerProviderStateMixin {
  late AnimationController _timerController;
  int _countdownValue = 3;
  bool _countdownStarted = false;
  String? _selectedOption;
  final _fillBlankController = TextEditingController();
  bool _hasAnswered = false;
  DuelRoomModel? _currentRoom;
  List<SoruModel> _questions = [];
  bool _isLoadingQuestions = true;
  String? _errorMessage;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this, duration: const Duration(seconds: 40));
    _startLoadingTimeout();
    _fetchQuestions();
  }

  void _startLoadingTimeout() {
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoadingQuestions) {
        setState(() {
          _errorMessage = 'Sorular yüklenemedi. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.';
          _isLoadingQuestions = false;
        });
      }
    });
  }

  Future<void> _fetchQuestions() async {
    try {
      final room = await ref.read(currentRoomProvider(widget.roomId).future);
      if (room != null && room.questionIds.isNotEmpty) {
        final firestore = ref.read(firestoreServiceProvider);
        final list = <SoruModel>[];
        for (final id in room.questionIds) {
          final q = await firestore.getSoru(id);
          if (q != null) list.add(q);
        }
        if (mounted) {
          _timeoutTimer?.cancel();
          setState(() {
            _questions = list;
            _isLoadingQuestions = false;
            if (list.isEmpty) {
              _errorMessage = 'Bu konu için soru bulunamadı.';
            }
          });
        }
      } else if (room != null && room.status == DuelRoomStatus.finished) {
        if (mounted) context.go(AppRoutes.duelResult, extra: widget.roomId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Soru yüklenirken bir hata oluştu: $e';
          _isLoadingQuestions = false;
        });
      }
    }
  }

  void _startInitialCountdown() {
    if (_countdownStarted) return;
    setState(() => _countdownStarted = true);
    
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownValue > 1) {
        setState(() => _countdownValue--);
      } else {
        timer.cancel();
        setState(() => _countdownValue = 0);
        _timerController.forward();
      }
    });
  }

  @override
  void dispose() {
    _timerController.dispose();
    _fillBlankController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onAnswerSubmitted(SoruModel currentSoru) async {
    if (_hasAnswered) return;
    
    String answer = '';
    bool isCorrect = false;

    if (currentSoru.type == 'fill_blank') {
      answer = _fillBlankController.text.trim();
      isCorrect = answer.toLowerCase() == currentSoru.answer.toLowerCase();
    } else if (currentSoru.type == 'flashcard') {
      answer = _selectedOption ?? 'unknown';
      isCorrect = answer == 'known';
    } else {
      answer = _selectedOption ?? '';
      isCorrect = answer == currentSoru.answer;
    }

    if (answer.isEmpty && currentSoru.type != 'flashcard') return;

    final timeTaken = _timerController.value * 40;
    setState(() => _hasAnswered = true);
    
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    if (uid == null) return;

    await ref.read(duelServiceProvider).submitAnswer(
      widget.roomId,
      uid,
      answer,
      isCorrect,
      timeTaken,
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomAsync = ref.watch(currentRoomProvider(widget.roomId));
    _currentRoom = roomAsync.value;
    final profile = ref.watch(profileProvider).value;
    final uid = ref.read(authServiceProvider).currentUser?.uid ?? '';
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: cs.error, size: 64),
                const SizedBox(height: 16),
                Text(_errorMessage!, textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(backgroundColor: cs.primary),
                  child: Text('GERİ DÖN', style: TextStyle(color: cs.onPrimary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_isLoadingQuestions || _currentRoom == null || profile == null) {
      return Scaffold(backgroundColor: cs.surface, body: Center(child: CircularProgressIndicator(color: cs.primary)));
    }

    if (_currentRoom!.status == DuelRoomStatus.waiting) {
      return _buildReadyPhase(context, _currentRoom!, uid, cs, tt);
    }

    if (_countdownValue > 0) {
      if (_currentRoom!.status == DuelRoomStatus.active) {
        _startInitialCountdown();
      }
      return _buildCountdownOverlay(context, cs, tt);
    }

    final currentIndex = _currentRoom!.currentQuestionIndex;
    if (currentIndex >= _questions.length || _currentRoom!.status == DuelRoomStatus.finished) {
       Future.microtask(() {
         if (mounted) context.go(AppRoutes.duelResult, extra: widget.roomId);
       });
       return Scaffold(backgroundColor: cs.surface, body: Center(child: CircularProgressIndicator(color: cs.primary)));
    }
    
    final currentSoru = _questions[currentIndex];

    ref.listen(currentRoomProvider(widget.roomId), (prev, next) {
      if (prev?.value?.currentQuestionIndex != next.value?.currentQuestionIndex) {
        setState(() {
          _selectedOption = null;
          _fillBlankController.clear();
          _hasAnswered = false;
          _timerController.reset();
          _timerController.forward();
        });
      }
      if (next.value?.status == DuelRoomStatus.finished) {
        context.go(AppRoutes.duelResult, extra: widget.roomId);
      }
    });

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHUD(context, _currentRoom!, profile, uid, cs, tt),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildQuestionCard(context, currentSoru, currentIndex, cs, tt),
                    const SizedBox(height: 24),
                    _buildInteractiveArea(context, currentSoru, cs, tt),
                  ],
                ),
              ),
            ),
            _buildBottomAction(context, currentSoru, cs, tt),
          ],
        ),
      ),
    );
  }

  Widget _buildReadyPhase(BuildContext context, DuelRoomModel room, String uid, ColorScheme cs, TextTheme tt) {
    final isHost = room.hostId == uid;
    final meReady = isHost ? room.hostReady : room.opponentReady;
    final otherReady = isHost ? room.opponentReady : room.hostReady;

    if (isHost && room.hostReady && room.opponentReady) {
       Future.microtask(() => ref.read(duelServiceProvider).activateMatch(widget.roomId));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flash_on, color: cs.primary, size: 64),
              const SizedBox(height: 24),
              Text('DÜELLO HAZIRLIK', style: tt.headlineSmall?.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Rakip bekleniyor ve her iki oyuncu hazır olunca başlanır.', textAlign: TextAlign.center, style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 48),
              _ReadyPlayerTile(name: 'SEN', isReady: meReady, isMe: true, cs: cs),
              const SizedBox(height: 16),
              _ReadyPlayerTile(name: 'RAKİP', isReady: otherReady, isMe: false, cs: cs),
              const SizedBox(height: 64),
              FilledButton(
                onPressed: meReady ? null : () => ref.read(duelServiceProvider).setReady(widget.roomId, uid, true),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(meReady ? 'HAZIR!' : 'HAZIR OL', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInteractiveArea(BuildContext context, SoruModel soru, ColorScheme cs, TextTheme tt) {
    if (soru.type == 'fill_blank') {
      return TextField(
        controller: _fillBlankController,
        enabled: !_hasAnswered,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          filled: true,
          fillColor: cs.surfaceContainerLow,
          hintText: 'Cevabınızı buraya yazın...',
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.24)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      );
    } else if (soru.type == 'flashcard') {
      return Column(
        children: [
          _buildOption(context, 'known', soru, cs, tt, label: 'BİLİYORUM', icon: Icons.check_circle_outline),
          _buildOption(context, 'unknown', soru, cs, tt, label: 'BİLMİYORUM', icon: Icons.help_outline),
        ],
      );
    } else {
      return Column(
        children: ['A', 'B', 'C', 'D', 'E'].map((opt) => _buildOption(context, opt, soru, cs, tt)).toList(),
      );
    }
  }

  Widget _buildOption(BuildContext context, String key, SoruModel soru, ColorScheme cs, TextTheme tt, {String? label, IconData? icon}) {
    final text = label ?? soru.secenekler?[key] ?? '';
    final isSelected = _selectedOption == key;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _hasAnswered ? null : () => setState(() => _selectedOption = key),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? cs.primary.withValues(alpha: 0.2) : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? cs.primary : Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              if (icon != null)
                Icon(icon, color: isSelected ? cs.primary : cs.onSurfaceVariant)
              else
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: isSelected ? cs.primary : cs.onSurface.withValues(alpha: 0.1), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(key, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                ),
              const SizedBox(width: 16),
              Expanded(child: Text(text, style: TextStyle(color: cs.onSurface))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHUD(BuildContext context, DuelRoomModel room, UserProfile profile, String uid, ColorScheme cs, TextTheme tt) {
    final isHost = room.hostId == uid;
    final opponentScore = isHost ? room.opponentScore : room.hostScore;
    final myScore = isHost ? room.hostScore : room.opponentScore;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => context.pop(),
                icon: Icon(Icons.exit_to_app, color: cs.error, size: 18),
                label: Text('ÇIKIŞ', style: TextStyle(color: cs.error, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${room.currentQuestionIndex + 1}/10', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PlayerScore(name: 'SEN', score: myScore, avatar: profile.avatarEmoji, isMe: true, cs: cs),
              Expanded(
                child: Center(
                  child: SizedBox(
                    height: 50, width: 50,
                    child: AnimatedBuilder(
                      animation: _timerController,
                      builder: (context, child) {
                        final val = 1.0 - _timerController.value;
                        final color = val > 0.5 ? Colors.green : (val > 0.2 ? Colors.orange : cs.error);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(value: val, color: color, strokeWidth: 6, backgroundColor: cs.onSurface.withValues(alpha: 0.1)),
                            Text('${(val * 40).toInt()}', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
              _PlayerScore(name: 'RAKİP', score: opponentScore, avatar: '👤', isMe: false, cs: cs),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(BuildContext context, SoruModel soru, int index, ColorScheme cs, TextTheme tt) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Row(
           children: [
             Icon(Icons.topic_rounded, size: 16, color: cs.onSurfaceVariant),
             const SizedBox(width: 8),
             Text(soru.type.toUpperCase().replaceAll('_', ' '), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
           ],
         ),
         const SizedBox(height: 12),
         Text(soru.text, style: TextStyle(color: cs.onSurface, fontSize: 18, height: 1.5)),
       ],
     );
  }

  Widget _buildBottomAction(BuildContext context, SoruModel currentSoru, ColorScheme cs, TextTheme tt) {
    bool canSubmit = false;
    if (currentSoru.type == 'fill_blank') {
      canSubmit = _fillBlankController.text.isNotEmpty;
    } else {
      canSubmit = _selectedOption != null;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: FilledButton(
        onPressed: (!canSubmit || _hasAnswered) ? null : () => _onAnswerSubmitted(currentSoru),
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(_hasAnswered ? 'BEKLENİYOR...' : 'SON KARARIM', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildCountdownOverlay(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('DÜELLO BAŞLIYOR', style: TextStyle(color: cs.onSurfaceVariant, letterSpacing: 4, fontWeight: FontWeight.bold)),
            const SizedBox(height: 64),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AvatarName(name: 'SEN', color: cs.primary, cs: cs),
                Icon(Icons.compare_arrows_rounded, color: cs.onSurface.withValues(alpha: 0.24), size: 48),
                _AvatarName(name: 'RAKİP', color: Colors.orange, cs: cs),
              ],
            ),
            const SizedBox(height: 64),
            Container(
              width: 120, height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: cs.primary, width: 4)),
              alignment: Alignment.center,
              child: Text('$_countdownValue', style: TextStyle(color: cs.onSurface, fontSize: 64, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyPlayerTile extends StatelessWidget {
  final String name;
  final bool isReady;
  final bool isMe;
  final ColorScheme cs;

  const _ReadyPlayerTile({required this.name, required this.isReady, required this.isMe, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: isReady ? Colors.green : cs.onSurface.withValues(alpha: 0.1), child: Icon(isReady ? Icons.check : Icons.person, color: isReady ? cs.onPrimary : cs.onSurfaceVariant)),
          const SizedBox(width: 16),
          Expanded(child: Text(name, style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold))),
          if (isReady)
            const Text('HAZIR', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12))
          else
            Text('BEKLENİYOR...', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.24), fontSize: 12)),
        ],
      ),
    );
  }
}

class _PlayerScore extends StatelessWidget {
  final String name;
  final int score;
  final String avatar;
  final bool isMe;
  final ColorScheme cs;

  const _PlayerScore({required this.name, required this.score, required this.avatar, required this.isMe, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 20, backgroundColor: isMe ? cs.primary : cs.onSurface.withValues(alpha: 0.1), child: Text(avatar)),
        const SizedBox(height: 4),
        Text(name, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10, fontWeight: FontWeight.bold)),
        Text('$score', style: TextStyle(color: cs.onSurface, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _AvatarName extends StatelessWidget {
  final String name;
  final Color color;
  final ColorScheme cs;

  const _AvatarName({required this.name, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(radius: 40, backgroundColor: color.withValues(alpha: 0.2), child: Icon(Icons.person, color: cs.onSurface, size: 40)),
        const SizedBox(height: 12),
        Text(name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        Text('OYUNCU', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
