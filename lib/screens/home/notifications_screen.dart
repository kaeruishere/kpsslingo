import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/router/app_router.dart';
import '../../providers/profile_provider.dart';
import '../../providers/duel_providers.dart';
import '../../providers/push_notifications_provider.dart';
import '../../models/push_notification_model.dart';
import '../../services/duel_service.dart';
import '../../services/social_service.dart';
import 'package:intl/intl.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(friendRequestsProvider);
    final challengesAsync = ref.watch(duelChallengesProvider);
    final pushNotificationsAsync = ref.watch(pushNotificationsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1C),
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: challengesAsync.when(
              data: (challenges) {
                return requestsAsync.when(
                  data: (requests) {
                    return pushNotificationsAsync.when(
                      data: (pushNotifications) {
                        if (requests.isEmpty && challenges.isEmpty && pushNotifications.isEmpty) {
                          return const Center(child: Text('Bildiriminiz bulunmuyor.', style: TextStyle(color: Colors.white54)));
                        }

                        return ListView(
                          padding: const EdgeInsets.all(AppSizes.p16),
                          children: [
                            if (challenges.isNotEmpty) ...[
                              const Text('Düello Davetleri', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 12),
                              ...challenges.map((c) => _DuelChallengeCard(challenge: c)),
                              const SizedBox(height: 24),
                            ],
                            if (requests.isNotEmpty) ...[
                              const Text('Arkadaşlık İstekleri', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                              const SizedBox(height: 12),
                              ...requests.map((r) => _FriendRequestCard(request: r)),
                              const SizedBox(height: 24),
                            ],
                            if (pushNotifications.isNotEmpty) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Sistem Bildirimleri', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12)),
                                  TextButton(
                                    onPressed: () {
                                      ref.read(pushNotificationsProvider.notifier).markAllAsRead();
                                    },
                                    child: const Text('Okundu İşaretle', style: TextStyle(fontSize: 11)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...pushNotifications.map((n) => _PushNotificationCard(notification: n)),
                            ],
                          ],
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, stack) => const Center(child: Text('Bir hata oluştu.')),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => const Center(child: Text('Bir hata oluştu.')),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => const Center(child: Text('Bir hata oluştu.')),
            ),
          ),
        ],
      ),
    );
  }
}

class _PushNotificationCard extends ConsumerWidget {
  final PushNotificationModel notification;
  const _PushNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeStr = DateFormat('dd MMM, HH:mm', 'tr_TR').format(notification.createdAt);
    
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent.withValues(alpha: 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        ref.read(pushNotificationsProvider.notifier).deleteNotification(notification.id);
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: notification.isRead ? const Color(0xFF131722) : const Color(0xFF1A1F2C),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: notification.isRead ? Colors.grey.withValues(alpha: 0.2) : const Color(0xFF6B5CF6).withValues(alpha: 0.2),
            child: Icon(Icons.notifications_active_rounded, color: notification.isRead ? Colors.grey : const Color(0xFF6B5CF6), size: 20),
          ),
          title: Text(notification.title, style: TextStyle(color: notification.isRead ? Colors.white70 : Colors.white, fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold, fontSize: 13)),
          subtitle: Text('${notification.body}\n$timeStr', style: const TextStyle(color: Colors.white54, fontSize: 11)),
          isThreeLine: true,
          onTap: () {
            ref.read(pushNotificationsProvider.notifier).markAsRead(notification.id);
            if (notification.contentId.isNotEmpty) {
              context.push('${AppRoutes.notificationDetail}/${notification.contentId}');
            }
          },
        ),
      ),
    );
  }
}

class _DuelChallengeCard extends ConsumerWidget {
  final Map<String, dynamic> challenge;
  const _DuelChallengeCard({required this.challenge});

  Future<UserProfile?> _fetchSenderProfile() async {
    final fromUid = challenge['from_uid'] as String? ?? '';
    final snap = await FirebaseFirestore.instance.collection('users').doc(fromUid).get();
    if (snap.exists && snap.data() != null) {
      return UserProfile.fromMap(snap.data()!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAt = (challenge['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();
    final timeStr = DateFormat('dd MMM, HH:mm', 'tr_TR').format(createdAt);

    return FutureBuilder<UserProfile?>(
      future: _fetchSenderProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? 'Bir kullanıcı';
        
        return Card(
          elevation: 0,
          color: const Color(0xFF1A1F2C),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF6B5CF6),
              child: Text(profile?.avatarEmoji ?? '⚡'),
            ),
            title: Text('$name seni düelloya davet etti!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            subtitle: Text('Tarih: $timeStr', style: const TextStyle(color: Colors.white54, fontSize: 11)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () {
                    ref.read(duelServiceProvider).rejectChallenge(challenge['room_id']);
                  },
                  child: const Text('REDDET', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ),
                FilledButton(
                  onPressed: () {
                    ref.read(appRouterProvider).push(AppRoutes.duelGame, extra: challenge['room_id']);
                  },
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF6B5CF6), padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('KABUL ET', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FriendRequestCard extends ConsumerStatefulWidget {
  final FriendRequest request;

  const _FriendRequestCard({required this.request});

  @override
  ConsumerState<_FriendRequestCard> createState() => _FriendRequestCardState();
}

class _FriendRequestCardState extends ConsumerState<_FriendRequestCard> {
  bool _isLoading = false;

  Future<UserProfile?> _fetchSenderProfile() async {
    final snap = await FirebaseFirestore.instance.collection('users').doc(widget.request.fromUid).get();
    if (snap.exists && snap.data() != null) {
      return UserProfile.fromMap(snap.data()!);
    }
    return null;
  }

  void _handleAccept() async {
    setState(() => _isLoading = true);
    await ref.read(socialServiceProvider).acceptFriendRequest(
      widget.request.id,
      widget.request.fromUid,
      widget.request.toUid,
    );
    if (mounted) setState(() => _isLoading = false);
  }

  void _handleReject() async {
    setState(() => _isLoading = true);
    await FirebaseFirestore.instance.collection('friend_requests').doc(widget.request.id).update({'status': 'rejected'});
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _fetchSenderProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final name = profile?.displayName ?? 'Bir kullanıcı';
        
        return Card(
          elevation: 0,
          color: const Color(0xFF1A1F2C),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6B5CF6).withValues(alpha: 0.2),
                  child: Text(profile?.avatarEmoji ?? '🦉'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      const Text('Sana arkadaşlık isteği gönderdi.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                if (_isLoading)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        onPressed: _handleAccept,
                        tooltip: 'Kabul Et',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                        onPressed: _handleReject,
                        tooltip: 'Reddet',
                      ),
                    ],
                  )
              ],
            ),
          ),
        );
      },
    );
  }
}
