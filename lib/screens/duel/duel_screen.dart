import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/app_strings.dart';
import '../../models/duel_stats_model.dart';
import '../../providers/profile_provider.dart';
import '../../providers/duel_providers.dart';
import '../../providers/study_providers.dart';
import '../../providers/exams_provider.dart';
import '../../services/duel_service.dart';

class DuelScreen extends ConsumerWidget {
  const DuelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    final profileAsync = ref.watch(profileProvider);
    final leaderboardAsync = ref.watch(globalLeaderboardProvider);

    return profileAsync.when(
      loading: () => Scaffold(backgroundColor: cs.surface, body: Center(child: CircularProgressIndicator(color: cs.primary))),
      error: (e, s) => Scaffold(body: Center(child: Text('Hata: $e', style: TextStyle(color: cs.error)))),
      data: (profile) {
        final stats = DuelStatsModel(
          totalDuels: profile.duelTotal,
          wins: profile.duelWins,
          losses: profile.duelLosses,
          draws: profile.duelDraws,
          winRate: profile.duelTotal == 0 ? 0 : (profile.duelWins / profile.duelTotal) * 100,
        );

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(AppStrings.screenDuel, style: tt.titleLarge?.copyWith(color: cs.onSurface, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16),
                  child: _buildStatsHeader(context, stats, cs, tt),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16),
                  child: _buildActionArea(context, cs, tt),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SectionTitle(title: 'Haftalık Liderlik Tablosu', cs: cs, tt: tt),
                      Row(
                        children: [
                          Icon(Icons.timer_outlined, size: 16, color: cs.onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text('Bitime: 3g 12s 45d', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: leaderboardAsync.when(
                  data: (users) => _buildPodium(context, users, cs, tt),
                  loading: () => Center(child: CircularProgressIndicator(color: cs.primary)),
                  error: (e, s) => Center(child: Text('Sıralama yüklenemedi', style: TextStyle(color: cs.onSurfaceVariant))),
                ),
              ),
              leaderboardAsync.when(
                data: (users) {
                  final listUsers = users.length > 3 ? users.sublist(3) : <UserProfile>[];
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = listUsers[index];
                        final rank = index + 4;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSizes.p32),
                          leading: Text(
                            '#$rank',
                            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurfaceVariant),
                          ),
                          title: Text(user.displayName, style: TextStyle(color: cs.onSurface)),
                          trailing: Text('${user.totalXp} XP', style: tt.bodySmall?.copyWith(color: cs.primary)),
                        );
                      },
                      childCount: listUsers.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: SizedBox()),
                error: (e, s) => const SliverToBoxAdapter(child: SizedBox()),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSizes.p120)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsHeader(BuildContext context, DuelStatsModel stats, ColorScheme cs, TextTheme tt) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSizes.p24),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              SizedBox(
                height: 100, width: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: stats.winRate / 100,
                      strokeWidth: 10,
                      backgroundColor: cs.onSurface.withValues(alpha: 0.05),
                      color: cs.primary,
                      strokeCap: StrokeCap.round,
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('%${stats.winRate.toInt()}', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                        Text('Galibiyet', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.p24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Güçlü Bir Rakipsin!', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                    const SizedBox(height: 4),
                    Text('Kazanma oranını yükseltmek için daha fazla düello yapmalısın.', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.p16),
        Row(
          children: [
            _StatMiniCard(title: 'Düello', value: stats.totalDuels.toString(), color: cs.onSurface, cs: cs),
            const SizedBox(width: 8),
            _StatMiniCard(title: 'Galibiyet', value: stats.wins.toString(), color: const Color(0xFF22C55E), cs: cs),
            const SizedBox(width: 8),
            _StatMiniCard(title: 'Mağlubiyet', value: stats.losses.toString(), color: cs.error, cs: cs),
            const SizedBox(width: 8),
            _StatMiniCard(title: 'Beraberlik', value: stats.draws.toString(), color: const Color(0xFFF59E0B), cs: cs),
          ],
        ),
      ],
    );
  }

  Widget _buildActionArea(BuildContext context, ColorScheme cs, TextTheme tt) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'YENİ DÜELLO',
            icon: Icons.add_rounded,
            color: cs.primary,
            onColor: cs.onPrimary,
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const _NewDuelSheet(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'KODLA KATIL',
            icon: Icons.qr_code_scanner_rounded,
            color: cs.surfaceContainerLow,
            onColor: cs.onSurface,
            onTap: () => showDialog(context: context, builder: (context) => const _JoinCodeDialog()),
          ),
        ),
      ],
    );
  }

  Widget _buildPodium(BuildContext context, List<UserProfile> users, ColorScheme cs, TextTheme tt) {
    if (users.isEmpty) return const SizedBox();
    
    final user1 = users[0];
    final user2 = users.length > 1 ? users[1] : null;
    final user3 = users.length > 2 ? users[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (user2 != null)
            _PodiumColumn(rank: 2, height: 120, user: user2, color: Colors.blueGrey.shade300, cs: cs, tt: tt)
          else
            const Expanded(child: SizedBox()),
          const SizedBox(width: 8),
          _PodiumColumn(rank: 1, height: 160, user: user1, color: Colors.amber.shade400, isWinner: true, cs: cs, tt: tt),
          const SizedBox(width: 8),
          if (user3 != null)
            _PodiumColumn(rank: 3, height: 90, user: user3, color: Colors.brown.shade300, cs: cs, tt: tt)
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color onColor;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Icon(icon, color: onColor, size: 28),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: onColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final ColorScheme cs;

  const _StatMiniCard({required this.title, required this.value, required this.color, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(color: cs.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(title, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final int rank;
  final double height;
  final UserProfile user;
  final Color color;
  final bool isWinner;
  final ColorScheme cs;
  final TextTheme tt;

  const _PodiumColumn({
    required this.rank,
    required this.height,
    required this.user,
    required this.color,
    required this.cs,
    required this.tt,
    this.isWinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isWinner ? Colors.amber : color, width: 2)),
                child: CircleAvatar(
                  radius: isWinner ? 32 : 24,
                  backgroundColor: cs.surfaceContainerLow,
                  child: Text(user.avatarEmoji, style: TextStyle(fontSize: isWinner ? 24 : 18)),
                ),
              ),
              if (isWinner)
                const Positioned(
                  bottom: 0,
                  child: Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 24),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(user.displayName, style: tt.labelSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface), overflow: TextOverflow.ellipsis),
          Text('${user.totalXp} XP', style: tt.labelSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.1)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(top: BorderSide(color: color, width: 3)),
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: tt.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: color.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  final TextTheme tt;

  const _SectionTitle({required this.title, required this.cs, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface),
    );
  }
}

class _NewDuelSheet extends ConsumerStatefulWidget {
  const _NewDuelSheet();

  @override
  ConsumerState<_NewDuelSheet> createState() => _NewDuelSheetState();
}

class _NewDuelSheetState extends ConsumerState<_NewDuelSheet> {
  String? _selectedExamId;
  String _selectedLessonId = 'all';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    final examsAsync = ref.watch(examsProvider);
    final lessonsAsync = ref.watch(lessonsProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p24, vertical: AppSizes.p16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4, margin: const EdgeInsets.only(bottom: AppSizes.p16),
                decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Düello Lobisi', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)),
                      Text('Meydan okumak istediğin konuyu seç ve başla!', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: AppSizes.p24),
            
            Container(
              padding: const EdgeInsets.all(AppSizes.p20),
              decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Düelloya Katıl', style: TextStyle(color: cs.onPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.flash_on_rounded, color: Colors.amber, size: 20),
                          ],
                        ),
                        Text('Rastgele bir rakiple hemen kapış', style: TextStyle(color: cs.onPrimary.withValues(alpha: 0.8), fontSize: 12)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final room = await ref.read(duelServiceProvider).findRandomMatch(lessonId: _selectedLessonId);
                      if (mounted && room != null) {
                        Navigator.pop(context);
                        context.push(AppRoutes.duelMatchmaking, extra: room.id);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.onPrimary,
                      foregroundColor: cs.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Eşleşme Bul', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p24),

            Text('SINAV SEÇ:', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            examsAsync.when(
              data: (exams) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: exams.map((exam) {
                    final isSelected = _selectedExamId == exam.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(exam.name),
                        selected: isSelected,
                        onSelected: (v) => setState(() => _selectedExamId = exam.id),
                        selectedColor: cs.primary.withValues(alpha: 0.2),
                        labelStyle: TextStyle(color: isSelected ? cs.primary : cs.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                        shape: StadiumBorder(side: BorderSide(color: isSelected ? cs.primary : Colors.transparent)),
                        showCheckmark: false,
                        backgroundColor: cs.surfaceContainerHigh,
                      ),
                    );
                  }).toList(),
                ),
              ),
              loading: () => LinearProgressIndicator(color: cs.primary),
              error: (e, s) => Text('Sınavlar yüklenemedi', style: TextStyle(color: cs.error)),
            ),
            const SizedBox(height: AppSizes.p20),

            Text('DERS SEÇ:', style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            lessonsAsync.when(
              data: (lessons) => Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _LessonChip(
                    label: 'Tüm Dersler',
                    isSelected: _selectedLessonId == 'all',
                    onTap: () => setState(() => _selectedLessonId = 'all'),
                    cs: cs,
                  ),
                  ...lessons.map((lesson) => _LessonChip(
                    label: lesson.name,
                    isSelected: _selectedLessonId == lesson.id,
                    onTap: () => setState(() => _selectedLessonId = lesson.id),
                    cs: cs,
                  )),
                ],
              ),
              loading: () => const SizedBox(),
              error: (e, s) => const SizedBox(),
            ),
            const SizedBox(height: AppSizes.p32),

            Container(
              padding: const EdgeInsets.all(AppSizes.p16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.done_all_rounded, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Savaş Hazır! Seçimlerine göre 450+ uygun soru bulundu.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.p16),

            ListTile(
              onTap: () async {
                final room = await ref.read(duelServiceProvider).createRoom(lessonId: _selectedLessonId);
                if (mounted && room != null) {
                  Navigator.pop(context);
                  context.push(AppRoutes.duelInvitation, extra: room.id);
                }
              },
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cs.onSurface.withValues(alpha: 0.1))),
              leading: Icon(Icons.group_add_outlined, color: cs.onSurfaceVariant),
              title: Text('Oda Oluştur & Paylaş', style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.bold)),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppSizes.p16),
          ],
        ),
      ),
    );
  }
}

class _LessonChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme cs;

  const _LessonChip({required this.label, required this.isSelected, required this.onTap, required this.cs});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? cs.onPrimary : cs.onSurfaceVariant, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
      ),
    );
  }
}

class _JoinCodeDialog extends ConsumerStatefulWidget {
  const _JoinCodeDialog();
  @override
  ConsumerState<_JoinCodeDialog> createState() => _JoinCodeDialogState();
}

class _JoinCodeDialogState extends ConsumerState<_JoinCodeDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      backgroundColor: cs.surfaceContainerLow,
      title: Text('Oda Kodu Girin', style: TextStyle(color: cs.onSurface)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TextStyle(color: cs.onSurface),
        decoration: InputDecoration(
          hintText: 'Örn: G7X2W9',
          hintStyle: TextStyle(color: cs.onSurfaceVariant),
          border: const OutlineInputBorder(),
        ),
        textCapitalization: TextCapitalization.characters,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('İptal', style: TextStyle(color: cs.onSurfaceVariant))),
        FilledButton(
          onPressed: () async {
            final code = _controller.text.trim();
            if (code.length != 6) return;
            
            final room = await ref.read(duelServiceProvider).joinRoom(code);
            if (mounted) {
              Navigator.pop(context);
              if (room != null) {
                context.push(AppRoutes.duelRoom, extra: room.id);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçersiz kod veya oda dolu.')));
              }
            }
          },
          child: const Text('Katıl'),
        ),
      ],
    );
  }
}
