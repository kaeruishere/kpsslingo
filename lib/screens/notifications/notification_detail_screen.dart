import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────
// TİP ENUM
// ─────────────────────────────────────────────

enum NotificationType {
  update,
  exam,
  motivation,
  content,
  announcement;

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationType.announcement,
    );
  }
}

// ─────────────────────────────────────────────
// TİP THEME — Her tipe renk + ikon + etiket
// ─────────────────────────────────────────────

class NotificationTypeTheme {
  final Color color;
  final IconData icon;
  final String label;

  const NotificationTypeTheme({
    required this.color,
    required this.icon,
    required this.label,
  });

  static NotificationTypeTheme of(NotificationType type) {
    switch (type) {
      case NotificationType.update:
        return const NotificationTypeTheme(
          color: Color(0xFF00B4D8),
          icon: Icons.system_update_rounded,
          label: 'Güncelleme',
        );
      case NotificationType.exam:
        return const NotificationTypeTheme(
          color: Color(0xFFE63946),
          icon: Icons.event_rounded,
          label: 'Sınav',
        );
      case NotificationType.motivation:
        return const NotificationTypeTheme(
          color: Color(0xFFF4A261),
          icon: Icons.local_fire_department_rounded,
          label: 'Motivasyon',
        );
      case NotificationType.content:
        return const NotificationTypeTheme(
          color: Color(0xFF2EC4B6),
          icon: Icons.menu_book_rounded,
          label: 'Yeni İçerik',
        );
      case NotificationType.announcement:
        return const NotificationTypeTheme(
          color: Color(0xFF7C4DFF),
          icon: Icons.campaign_rounded,
          label: 'Duyuru',
        );
    }
  }
}

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────

class NotificationContent {
  final NotificationType type;
  final String title;
  final String body;
  final String? ctaLabel;
  final String? ctaUrl;
  final Map<String, dynamic> meta;

  const NotificationContent({
    required this.type,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.ctaUrl,
    this.meta = const {},
  });

  factory NotificationContent.fromMap(Map<String, dynamic> data) {
    return NotificationContent(
      type: NotificationType.fromString(data['type'] as String?),
      title: data['title'] as String? ?? 'Bildirim',
      body: data['body'] as String? ?? '',
      ctaLabel: data['ctaLabel'] as String?,
      ctaUrl: data['ctaUrl'] as String?,
      meta: (data['meta'] as Map<String, dynamic>?) ?? {},
    );
  }
}

// ─────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────

class NotificationDetailScreen extends StatefulWidget {
  final String contentId;

  /// Firestore'daki kullanıcı bildirim doküman yolu (okundu için)
  /// Örn: "user_notifications/docId"
  final String? userNotificationDocPath;

  const NotificationDetailScreen({
    super.key,
    required this.contentId,
    this.userNotificationDocPath,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  late final Future<NotificationContent?> _contentFuture;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));

    _contentFuture = _fetchAndMarkRead();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<NotificationContent?> _fetchAndMarkRead() async {
    try {
      final doc = await _db
          .collection('notifications_content')
          .doc(widget.contentId)
          .get();

      if (!doc.exists) return null;

      _markAsRead();

      final content = NotificationContent.fromMap(doc.data()!);
      _animCtrl.forward();
      return content;
    } catch (e) {
      debugPrint('Bildirim çekilirken hata: $e');
      return null;
    }
  }

  Future<void> _markAsRead() async {
    try {
      final path = widget.userNotificationDocPath;
      if (path != null) {
        final parts = path.split('/');
        if (parts.length == 2) {
          await _db.collection(parts[0]).doc(parts[1]).update({
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint('Okundu yazılırken hata: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C18),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
      body: FutureBuilder<NotificationContent?>(
        future: _contentFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ShimmerSkeleton();
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return _ErrorView(onBack: () => Navigator.pop(context));
          }

          final content = snapshot.data!;
          final theme = NotificationTypeTheme.of(content.type);

          return FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _ContentView(
                content: content,
                theme: theme,
                onLaunchUrl: _launchUrl,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CONTENT VIEW
// ─────────────────────────────────────────────

class _ContentView extends StatelessWidget {
  final NotificationContent content;
  final NotificationTypeTheme theme;
  final Future<void> Function(String) onLaunchUrl;

  const _ContentView({
    required this.content,
    required this.theme,
    required this.onLaunchUrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroHeader(theme: theme),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeBadge(theme: theme),
                const SizedBox(height: 14),
                Text(
                  content.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 2,
                  width: 36,
                  decoration: BoxDecoration(
                    color: theme.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  content.body,
                  style: const TextStyle(
                    color: Color(0xFFAAB4CC),
                    fontSize: 15,
                    height: 1.75,
                  ),
                ),
                if (content.meta.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  _MetaCard(meta: content.meta, accentColor: theme.color),
                ],
                if (content.ctaUrl != null && content.ctaUrl!.isNotEmpty) ...[
                  const SizedBox(height: 32),
                  _CtaButton(
                    label: content.ctaLabel ?? 'Devam Et',
                    color: theme.color,
                    onTap: () => onLaunchUrl(content.ctaUrl!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  final NotificationTypeTheme theme;

  const _HeroHeader({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.color.withOpacity(0.2),
            theme.color.withOpacity(0.05),
            const Color(0xFF080C18),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.color.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.color.withOpacity(0.06),
              ),
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.color.withOpacity(0.12),
                border: Border.all(
                  color: theme.color.withOpacity(0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(theme.icon, size: 48, color: theme.color),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF080C18).withOpacity(0.6),
                    const Color(0xFF080C18),
                  ],
                  stops: const [0.5, 0.85, 1.0],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TYPE BADGE
// ─────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final NotificationTypeTheme theme;

  const _TypeBadge({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(theme.icon, size: 13, color: theme.color),
          const SizedBox(width: 6),
          Text(
            theme.label.toUpperCase(),
            style: TextStyle(
              color: theme.color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// META CARD — Tipe özel ek veriler
//
// Firestore'da "meta" alanı map olarak tutulur:
//   exam       → { "examDate": "15 Haziran 2025", "daysLeft": "42" }
//   content    → { "subject": "Anayasa Hukuku", "questionCount": "80" }
//   motivation → { "streak": "7", "totalSolved": "340" }
//   update     → { "version": "2.4.0", "releaseDate": "10 Mayıs 2025" }
// ─────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  final Map<String, dynamic> meta;
  final Color accentColor;

  const _MetaCard({required this.meta, required this.accentColor});

  String _formatKey(String key) {
    const labels = {
      'examDate': 'Sınav Tarihi',
      'daysLeft': 'Kalan Gün',
      'subject': 'Ders',
      'questionCount': 'Soru Sayısı',
      'streak': 'Gün Serisi',
      'totalSolved': 'Toplam Soru',
      'version': 'Versiyon',
      'releaseDate': 'Yayın Tarihi',
    };
    return labels[key] ?? key;
  }

  @override
  Widget build(BuildContext context) {
    final entries = meta.entries.toList();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF10162A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        children: entries.asMap().entries.map((e) {
          final isLast = e.key == entries.length - 1;
          return Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatKey(e.value.key),
                    style: const TextStyle(
                        color: Color(0xFF6B7490), fontSize: 13),
                  ),
                  Text(
                    e.value.value.toString(),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (!isLast)
                Divider(
                  height: 20,
                  color: Colors.white.withOpacity(0.06),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// CTA BUTTON
// ─────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CtaButton(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: onTap,
          icon: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 18),
          label: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHIMMER SKELETON
// ─────────────────────────────────────────────

class _ShimmerSkeleton extends StatefulWidget {
  const _ShimmerSkeleton();

  @override
  State<_ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<_ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final g = LinearGradient(
          colors: const [
            Color(0xFF10162A),
            Color(0xFF1C2540),
            Color(0xFF10162A),
          ],
          stops: [
            (_anim.value - 0.3).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.3).clamp(0.0, 1.0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );

        Widget bone(double w, double h, {double r = 10}) => Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                gradient: g,
                borderRadius: BorderRadius.circular(r),
              ),
            );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 220, decoration: BoxDecoration(gradient: g)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bone(72, 26, r: 20),
                  const SizedBox(height: 14),
                  bone(double.infinity, 28),
                  const SizedBox(height: 8),
                  bone(200, 28),
                  const SizedBox(height: 20),
                  bone(double.infinity, 14),
                  const SizedBox(height: 8),
                  bone(double.infinity, 14),
                  const SizedBox(height: 8),
                  bone(240, 14),
                  const SizedBox(height: 28),
                  bone(double.infinity, 80, r: 16),
                  const SizedBox(height: 24),
                  bone(double.infinity, 56, r: 16),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ERROR VIEW
// ─────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final VoidCallback onBack;

  const _ErrorView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.inbox_rounded,
                  size: 52, color: Colors.redAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'Bildirim Bulunamadı',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu bildirim artık mevcut değil veya süresi dolmuş.',
              style: TextStyle(color: Color(0xFF6B7490), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Geri Dön'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0xFF2A3250)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}