import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_routes.dart';
import '../../providers/profile_provider.dart';
import '../../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/exams_provider.dart';

class SetupProfileScreen extends ConsumerStatefulWidget {
  const SetupProfileScreen({super.key});

  @override
  ConsumerState<SetupProfileScreen> createState() => _SetupProfileScreenState();
}

class _SetupProfileScreenState extends ConsumerState<SetupProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Identity State
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  String _selectedEmoji = '🦉';

  // Goal State
  String? _selectedExam;

  // Permissions State
  bool _notificationsGranted = false;

  final List<String> _emojis = ['🦉', '🐸', '🦁', '🦊', '🐨', '🐼', '🐯', '🐰', '🦒'];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider).value;
    _nameController = TextEditingController(text: profile?.displayName);
    _usernameController = TextEditingController(text: profile?.username);
    _selectedEmoji = profile?.avatarEmoji ?? '🦉';
    _selectedExam = profile?.selectedExam;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isLoading = true);
      final username = _usernameController.text.trim();
      final uid = ref.read(profileProvider).value?.displayName; // fallback, real check below
      final authUid = ref.read(authServiceProvider).currentUser?.uid;

      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: username)
            .limit(1)
            .get();

        if (snap.docs.isNotEmpty && snap.docs.first.id != authUid) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bu kullanıcı adı sistemde kullanılıyor. Lütfen başka bir tane seçin.')),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bağlantı hatası oluştu')),
          );
        }
        return;
      }
      
      if (mounted) setState(() => _isLoading = false);
    }
    if (_currentStep == 1) {
      if (_selectedExam == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen bir sınav seçin.')),
        );
        return;
      }
    }
    setState(() => _currentStep++);
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.notification.request();
    if (status.isGranted) {
      setState(() => _notificationsGranted = true);
    }
  }

  Future<void> _handleFinish() async {
    setState(() => _isLoading = true);
    try {
      final notifier = ref.read(profileProvider.notifier);
      await notifier.updateDisplayName(_nameController.text.trim());
      await notifier.updateUsername(_usernameController.text.trim().toLowerCase());
      await notifier.updateEmoji(_selectedEmoji);
      if (_selectedExam != null) {
        await notifier.updateSelectedExam(_selectedExam);
      }
      await notifier.setCompletedSetup(true);
      
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.defaultError)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress Header
            _buildProgress(cs),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.p32),
                child: _buildCurrentStep(cs, tt),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(AppSizes.p32),
              child: _isLoading 
                ? const CircularProgressIndicator()
                : FilledButton(
                    onPressed: _currentStep == 2 ? _handleFinish : _nextStep,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(_currentStep == 2 ? AppStrings.setupFinish : AppStrings.setupNext),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.p32, vertical: AppSizes.p16),
      child: Row(
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index == 2 ? 0 : 8),
              decoration: BoxDecoration(
                color: isActive ? cs.primary : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(ColorScheme cs, TextTheme tt) {
    switch (_currentStep) {
      case 0: return _buildStepIdentity(cs, tt);
      case 1: return _buildStepGoal(cs, tt);
      case 2: return _buildStepAlerts(cs, tt);
      default: return const SizedBox.shrink();
    }
  }

  Widget _buildStepIdentity(ColorScheme cs, TextTheme tt) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSizes.p24),
          Text(AppStrings.setupProfileTitle, style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: AppSizes.p8),
          Text(AppStrings.setupProfileSubtitle, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
          
          const SizedBox(height: AppSizes.p40),
          
          // Avatar Selection
          Text(AppStrings.setupAvatarLabel, style: tt.titleSmall),
          const SizedBox(height: AppSizes.p16),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _emojis.length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final emoji = _emojis[index];
                final isSelected = _selectedEmoji == emoji;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEmoji = emoji),
                  child: Container(
                    width: 70,
                    decoration: BoxDecoration(
                      color: isSelected ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected ? Border.all(color: cs.primary, width: 2) : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(emoji, style: const TextStyle(fontSize: 32)),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppSizes.p40),

          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: AppStrings.setupBioLabel,
              hintText: AppStrings.setupBioHint,
              prefixIcon: const Icon(Icons.person_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen bir ad girin' : null,
          ),
          const SizedBox(height: AppSizes.p24),
          TextFormField(
            controller: _usernameController,
            decoration: InputDecoration(
              labelText: 'Kullanıcı Adı',
              hintText: 'Örn: ahmet_123',
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Kullanıcı adı gerekli';
              if (!RegExp(r'^[a-z0-9_]+$').hasMatch(v)) {
                return 'Sadece küçük harf, rakam ve alt çizgi kullanılabilir.';
              }
              return null;
            },
            maxLength: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildStepGoal(ColorScheme cs, TextTheme tt) {
    final examsAsync = ref.watch(examsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSizes.p24),
        Text(AppStrings.setupGoalTitle, style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.p8),
        Text(AppStrings.setupGoalSubtitle, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: AppSizes.p40),
        examsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Sınavlar yüklenemedi: $e'),
          data: (exams) => Column(
            children: exams.map((exam) {
              final isSelected = _selectedExam == exam.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedExam = exam.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isSelected ? cs.primary : cs.outlineVariant, width: isSelected ? 2 : 1),
                      color: isSelected ? cs.primaryContainer.withValues(alpha: 0.1) : null,
                    ),
                    child: Row(
                      children: [
                        Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                             color: isSelected ? cs.primary : cs.outline),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(exam.name, style: tt.titleMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                            color: isSelected ? cs.primary : null,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSizes.p16),
        Text(AppStrings.setupGoalFooter, style: tt.bodySmall?.copyWith(color: cs.outline), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildStepAlerts(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSizes.p24),
        Text(AppStrings.setupAlertsTitle, style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSizes.p8),
        Text(AppStrings.setupAlertsSubtitle, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
        
        const SizedBox(height: AppSizes.p40),
        
        Center(
          child: Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_active_rounded, size: 80, color: cs.primary),
          ),
        ),
        
        const SizedBox(height: AppSizes.p48),
        
        OutlinedButton.icon(
          onPressed: _notificationsGranted ? null : _requestPermissions,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: Icon(_notificationsGranted ? Icons.check_circle_outline : Icons.notifications_none_rounded),
          label: Text(_notificationsGranted ? AppStrings.setupAlertsBtnSuccess : AppStrings.setupAlertsBtnBuild),
        ),
      ],
    );
  }
}
