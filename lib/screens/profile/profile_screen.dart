import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/auth_service.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/profile_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/exams_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Available avatar emojis ────────────────────────────────────
const _avatarEmojis = [
  '🐸', '🦉', '🦊', '🦁', '🐼', '🐯', '🦋', '🦄',
  '🎯', '🚀', '🧠', '⚡', '🔥', '🌙', '🌈', '🎮',
  '📚', '🏆', '💡', '🎸', '🌊', '🍀', '🎨', '🦅',
];

const _kReAuthRequiredMessage = 're-auth-required';
const _kAnimationDuration = Duration(milliseconds: 600);

final _profileScreenDataProvider = Provider((ref) => (
  profile: ref.watch(profileProvider),
  auth: ref.watch(authStateProvider),
));

// ═══════════════════════════════════════════════════════════════
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _editingName     = false;
  bool _editingUsername = false;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _usernameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _usernameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  // ── Emoji picker ───────────────────────────────────────────
  void _showEmojiPicker(BuildContext context, String currentEmoji) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.r24)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSizes.p16),
          Text(
            AppStrings.profileEmojiPickerTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSizes.p12),
          GridView.count(
            padding: const EdgeInsets.all(AppSizes.p16),
            shrinkWrap: true,
            crossAxisCount: 6,
            mainAxisSpacing: AppSizes.p8,
            crossAxisSpacing: AppSizes.p8,
            children: _avatarEmojis.map((emoji) {
              final isSelected = emoji == currentEmoji;
              return GestureDetector(
                onTap: () {
                  ref.read(profileProvider.notifier).updateEmoji(emoji);
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppSizes.r12),
                    border: isSelected
                        ? Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSizes.p16),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final data      = ref.watch(_profileScreenDataProvider);
    // Removed unused cs and tt locals
    final user      = data.auth.value;
    final profile   = data.profile.value ?? const UserProfile();
    final isLoading = data.profile.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.profileTitle)),
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              padding: const EdgeInsets.all(AppSizes.p16),
              children: [
                // ── 0. Guest Warning ───────────────────────
                if (user?.isAnonymous ?? true)
                  _GuestWarningCard(onLoginTap: () => context.go(AppRoutes.login)),

                // ── 1. Header / Avatar ─────────────────────
                _ProfileHeader(
                  user: user,
                  profile: profile,
                  editingName: _editingName,
                  nameCtrl: _nameCtrl,
                  onEmojiTap: () => _showEmojiPicker(context, profile.avatarEmoji),
                  onNameEditStart: () {
                    _nameCtrl.text = profile.displayName;
                    setState(() => _editingName = true);
                  },
                  onNameSave: (name) {
                    if (name.trim().isEmpty) {
                      _showSnackBar('İsim boş bırakılamaz.');
                      return;
                    }
                    ref.read(profileProvider.notifier).updateDisplayName(name.trim());
                    HapticFeedback.lightImpact();
                    setState(() => _editingName = false);
                  },
                  editingUsername: _editingUsername,
                  usernameCtrl: _usernameCtrl,
                  onUsernameEditStart: () {
                    _usernameCtrl.text = profile.username;
                    setState(() => _editingUsername = true);
                  },
                  onUsernameSave: (usernameText) async {
                    final v = usernameText.trim().toLowerCase();
                    if (v.isEmpty) {
                      _showSnackBar('Kullanıcı adı boş bırakılamaz.');
                      setState(() => _editingUsername = false);
                      return;
                    }
                    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) {
                      _showSnackBar('Sadece küçük harf, rakam ve alt çizgi kullanılabilir.');
                      return;
                    }
                    if (v == profile.username) {
                      setState(() => _editingUsername = false);
                      return;
                    }
                    
                    // Unique control logic here
                    try {
                      final snap = await FirebaseFirestore.instance
                          .collection('users')
                          .where('username', isEqualTo: v)
                          .limit(1)
                          .get();
                      
                      final authUid = ref.read(authServiceProvider).currentUser?.uid;
                      if (snap.docs.isNotEmpty && snap.docs.first.id != authUid) {
                        _showSnackBar('Bu kullanıcı adı sistemde kullanılıyor. Lütfen başka bir tane seçin.');
                        return;
                      }
                      
                      await ref.read(profileProvider.notifier).updateUsername(v);
                      HapticFeedback.lightImpact();
                      setState(() => _editingUsername = false);
                    } catch (e) {
                      _showSnackBar('Bağlantı hatası: Kullanıcı adı kontrol edilemedi.');
                    }
                  },
                ),
                const SizedBox(height: AppSizes.p24),

                // ── 2. Stats ───────────────────────────────
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: '🔥', label: AppStrings.profileStreak,  value: '${profile.streak}',   unit: AppStrings.profileStreakUnit)),
                    const SizedBox(width: AppSizes.p12),
                    Expanded(child: _StatCard(icon: '✨', label: AppStrings.profileXp,      value: '${profile.totalXp}',  unit: AppStrings.profileXpUnit)),
                  ],
                ),
                const SizedBox(height: AppSizes.p24),

                // ── 3. Privacy ───────────────────────────
                const _SectionTitle('Gizlilik'),
                SwitchListTile.adaptive(
                  title: const Text('Aktivitelerimi Paylaş'),
                  subtitle: const Text('Arkadaşların çözdüğün testleri ve kazandığın XPleri görebilir.'),
                  value: profile.shareActivity,
                  onChanged: (v) {
                    ref.read(profileProvider.notifier).toggleShareActivity(v);
                    HapticFeedback.selectionClick();
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: AppSizes.p24),

                // ── 4. Exam Selection ─────────────────────
                const _SectionTitle('Hedef Sınavım'),
                _ExamPickerCard(
                  selectedExam: profile.selectedExam,
                  onChanged: (examId) =>
                      ref.read(profileProvider.notifier).updateSelectedExam(examId),
                ),

                const SizedBox(height: AppSizes.p24),

                // ── 5. Settings ──────────────────────────
                const _SectionTitle('Uygulama Ayarları'),
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: AppSizes.defaultBorderRadius),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.palette_rounded),
                        title: Text('Tema'),
                        trailing: _ThemeSegmentedButton(),
                      ),
                      const Divider(height: 1),
                      Consumer(
                        builder: (context, ref, child) {
                          final settings = ref.watch(settingsProvider).value;
                          return SwitchListTile.adaptive(
                            title: const Text('Ses Efektleri'),
                            secondary: const Icon(Icons.music_note_rounded),
                            value: settings?.sound ?? true,
                            onChanged: (v) => ref.read(settingsProvider.notifier).setSound(v),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      Consumer(
                        builder: (context, ref, child) {
                          final settings = ref.watch(settingsProvider).value;
                          return SwitchListTile.adaptive(
                            title: const Text('Haptik (Titreşim)'),
                            secondary: const Icon(Icons.vibration_rounded),
                            value: settings?.vibration ?? true,
                            onChanged: (v) => ref.read(settingsProvider.notifier).setVibration(v),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.p24),

                // ── 6. Account Actions ──────────────────
                const _SectionTitle('Hesap Yönetimi'),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.orange),
                  title: const Text('Çıkış Yap', style: TextStyle(color: Colors.orange)),
                  onTap: () async {
                    await ref.read(authServiceProvider).signOut();
                    if (context.mounted) context.go(AppRoutes.login);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                  title: const Text('Hesabı Sil', style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    // Logic hesabı sil
                  },
                ),

                const SizedBox(height: AppSizes.p32),
              ],
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Extracted widgets
// ═══════════════════════════════════════════════════════════════

// ── Section title ──────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.p4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

// ── Guest warning ──────────────────────────────────────────────
class _GuestWarningCard extends StatelessWidget {
  final VoidCallback onLoginTap;
  const _GuestWarningCard({required this.onLoginTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      color: cs.errorContainer,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSizes.p24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.r16)),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: cs.error),
                const SizedBox(width: AppSizes.p12),
                Expanded(
                  child: Text(
                    AppStrings.guestWarningTitle,
                    style: tt.titleSmall?.copyWith(
                      color: cs.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.p8),
            Text(
              AppStrings.guestWarningSubtitle,
              style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
            ),
            const SizedBox(height: AppSizes.p16),
            FilledButton.icon(
              onPressed: onLoginTap,
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                minimumSize: const Size(double.infinity, 40),
              ),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text(AppStrings.guestWarningBtn),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ─────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final dynamic user;
  final UserProfile profile;
  final bool editingName;
  final bool editingUsername;
  final TextEditingController nameCtrl;
  final TextEditingController usernameCtrl;
  final VoidCallback onEmojiTap;
  final VoidCallback onNameEditStart;
  final ValueChanged<String> onNameSave;
  final VoidCallback onUsernameEditStart;
  final ValueChanged<String> onUsernameSave;

  const _ProfileHeader({
    required this.user,
    required this.profile,
    required this.editingName,
    required this.editingUsername,
    required this.nameCtrl,
    required this.usernameCtrl,
    required this.onEmojiTap,
    required this.onNameEditStart,
    required this.onNameSave,
    required this.onUsernameEditStart,
    required this.onUsernameSave,
  });

  @override
  Widget build(BuildContext context) {
    final cs      = Theme.of(context).colorScheme;
    final tt      = Theme.of(context).textTheme;
    final isGuest = user?.isAnonymous ?? true;

    return Column(
      children: [
        // Avatar
        GestureDetector(
          onTap: isGuest ? null : onEmojiTap,
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSizes.r24),
                ),
                child: Center(
                  child: Text(profile.avatarEmoji, style: const TextStyle(fontSize: 52)),
                ),
              ),
              if (!isGuest)
                Container(
                  padding: const EdgeInsets.all(AppSizes.p4),
                  decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                  child: Icon(Icons.edit_rounded, size: 16, color: cs.onPrimary),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.p12),

        // Display name
        if (editingName)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    hintText: AppStrings.profileEditNameHint,
                    border: OutlineInputBorder(),
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: AppSizes.p12,
                      vertical: AppSizes.p8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.p8),
              FilledButton(
                onPressed: () => onNameSave(nameCtrl.text),
                child: const Text(AppStrings.profileSaveBtn),
              ),
            ],
          )
        else
          GestureDetector(
            onTap: isGuest ? null : onNameEditStart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile.displayName.isEmpty
                      ? AppStrings.profileEditNameHint
                      : profile.displayName,
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                // Edit ikonu sadece guest değilse göster
                if (!isGuest) ...[
                  const SizedBox(width: AppSizes.p8),
                  Icon(Icons.edit_rounded, size: 16, color: cs.primary),
                ],
              ],
            ),
          ),

        const SizedBox(height: AppSizes.p4),

        // Username Editor
        if (editingUsername)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: usernameCtrl,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      hintText: 'yeni_kullaniciadi',
                      prefixText: '@',
                      border: OutlineInputBorder(),
                      counterText: '',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSizes.p12,
                        vertical: AppSizes.p8,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.p8),
                FilledButton(
                  onPressed: () => onUsernameSave(usernameCtrl.text),
                  child: const Text('Kaydet'),
                ),
              ],
            ),
          )
        else
          GestureDetector(
            onTap: isGuest ? null : onUsernameEditStart,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  profile.username.isNotEmpty ? '@${profile.username}' : 'Kullanıcı adı yok (Ekle)',
                  style: tt.titleMedium?.copyWith(
                    color: profile.username.isNotEmpty ? cs.primary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (!isGuest) ...[
                  const SizedBox(width: AppSizes.p8),
                  Icon(Icons.edit_rounded, size: 14, color: profile.username.isNotEmpty ? cs.primary : cs.onSurfaceVariant),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final String unit;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      color: cs.surfaceContainerHighest,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppSizes.defaultBorderRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSizes.p16,
          horizontal: AppSizes.p12,
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: AppSizes.p4),
            Text(
              '$value $unit',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ThemeSegmentedButton extends ConsumerStatefulWidget {
  const _ThemeSegmentedButton();

  @override
  ConsumerState<_ThemeSegmentedButton> createState() => _ThemeSegmentedButtonState();
}

class _ThemeSegmentedButtonState extends ConsumerState<_ThemeSegmentedButton> {
  final _lightKey = GlobalKey();
  final _darkKey = GlobalKey();
  final _systemKey = GlobalKey();

  Offset _centerOf(GlobalKey key) {
    if (key.currentContext == null) return Offset.zero;
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return Offset.zero;
    final pos = box.localToGlobal(Offset.zero);
    return Offset(pos.dx + box.size.width / 2, pos.dy + box.size.height / 2);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final mode = settingsAsync.value?.themeMode ?? ThemeMode.system;

    return SegmentedButton<ThemeMode>(
      segments: [
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(key: _lightKey, Icons.light_mode_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(key: _systemKey, Icons.brightness_auto_rounded),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(key: _darkKey, Icons.dark_mode_rounded),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (set) {
        final newMode = set.first;
        final sysDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
        final newTheme = newMode == ThemeMode.dark || (newMode == ThemeMode.system && sysDark)
            ? AppTheme.darkTheme
            : AppTheme.lightTheme;
        final tapKey = newMode == ThemeMode.dark ? _darkKey : newMode == ThemeMode.light ? _lightKey : _systemKey;
        ThemeSwitcher.of(context).changeTheme(
          theme: newTheme,
          offset: _centerOf(tapKey),
        );
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) ref.read(settingsProvider.notifier).setThemeMode(newMode);
        });
      },
      showSelectedIcon: false,
    );
  }
}

// ── Exam picker card ───────────────────────────────────────────
class _ExamPickerCard extends ConsumerWidget {
  final String? selectedExam;
  final ValueChanged<String?> onChanged;

  const _ExamPickerCard({required this.selectedExam, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final examsAsync = ref.watch(examsProvider);

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: AppSizes.defaultBorderRadius),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.p16),
        child: examsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Sınavlar yüklenemedi: $e'),
          data: (exams) {
            if (exams.isEmpty) {
              return const Center(child: Text('Henüz sınav eklenmemiş.'));
            }
            return Column(
              children: exams.map((exam) {
                final isSelected = selectedExam == exam.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.p12),
                  child: InkWell(
                    onTap: () => onChanged(isSelected ? null : exam.id),
                    borderRadius: AppSizes.defaultBorderRadius,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p16, vertical: AppSizes.p16),
                      decoration: BoxDecoration(
                        borderRadius: AppSizes.defaultBorderRadius,
                        border: Border.all(
                          color: isSelected ? cs.primary : cs.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected ? cs.primaryContainer.withValues(alpha: 0.15) : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? cs.primary : cs.outline,
                          ),
                          const SizedBox(width: AppSizes.p12),
                          Expanded(
                            child: Text(
                              exam.name,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: isSelected ? FontWeight.bold : null,
                                color: isSelected ? cs.primary : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
