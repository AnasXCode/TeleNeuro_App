import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/notification_service.dart';

const Color _kPrimary = Color(0xFF1565C0);

class NotificationsScreen extends StatefulWidget {
  final bool showAppBar;
  final bool embeddedInTab;
  final bool markGeneralOnOpen;

  const NotificationsScreen({
    super.key,
    this.showAppBar = true,
    this.embeddedInTab = false,
    this.markGeneralOnOpen = false,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _markedGeneral = false;

  @override
  void initState() {
    super.initState();
    if (widget.markGeneralOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _markGeneralIfNeeded());
    }
  }

  Future<void> _markGeneralIfNeeded() async {
    if (_markedGeneral) return;
    _markedGeneral = true;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await NotificationService.markGeneralNotificationsAsRead(uid);
    }
  }

  String _formatTime(dynamic createdAt) {
    if (createdAt is Timestamp) {
      final d = createdAt.toDate();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '';
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case NotificationService.typeAppointmentBooked:
        return Icons.calendar_month_outlined;
      case NotificationService.typeSessionCompleted:
        return Icons.check_circle_outline;
      case NotificationService.typeChatMessage:
        return Icons.chat_bubble_outline;
      case NotificationService.typeMriShared:
        return Icons.medical_information_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Future<void> _markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await NotificationService.markAllAsRead(uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final useAppBar = widget.showAppBar || widget.embeddedInTab;

    return Scaffold(
      appBar: useAppBar
          ? AppBar(
        title: const Text('Notifications'),
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: !widget.embeddedInTab,
        actions: [
          if (uid != null)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      )
          : null,
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: NotificationService.notificationsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = (snap.data?.docs ?? []).toList()
            ..sort((a, b) {
              final ta = a.data()['createdAt'];
              final tb = b.data()['createdAt'];
              if (ta is! Timestamp) return 1;
              if (tb is! Timestamp) return -1;
              return tb.compareTo(ta);
            });
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            // ✅ Linter fix: (_, __) ki jagah (context, index) use kiya
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();
              final read = data['read'] == true;
              final title = (data['title'] ?? 'Notification').toString();
              final body = (data['body'] ?? '').toString();
              final type = data['type'] as String?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: read ? Colors.grey.shade200 : const Color(0xFFE3F2FD),
                  child: Icon(
                    _iconForType(type),
                    color: read ? Colors.grey : _kPrimary,
                  ),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: read ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty) Text(body),
                    Text(
                      _formatTime(data['createdAt']),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                onTap: () => NotificationService.markAsRead(doc.id),
              );
            },
          );
        },
      ),
    );
  }
}

/// Unread notification count badge for app bars.
class NotificationBadgeIcon extends StatelessWidget {
  final VoidCallback onTap;
  final Color? iconColor;

  const NotificationBadgeIcon({super.key, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        onPressed: onTap,
        icon: Icon(Icons.notifications_outlined, color: iconColor),
      );
    }

    return StreamBuilder<int>(
      stream: NotificationService.unreadCountStream(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onTap,
              icon: Icon(Icons.notifications_outlined, color: iconColor),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}