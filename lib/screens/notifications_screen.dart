import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/notification_service.dart';

const Color _primary = Color(0xFF1565C0);

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      NotificationService.markAllAsRead(uid);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment_request':
        return Icons.event_available;
      case 'appointment_status':
        return Icons.check_circle_outline;
      case 'message':
        return Icons.chat_bubble_outline;
      case 'report':
        return Icons.description_outlined;
      case 'consultation_ended':
        return Icons.event_busy;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'appointment_request':
        return Colors.orange;
      case 'appointment_status':
        return Colors.green;
      case 'message':
        return _primary;
      case 'report':
        return Colors.purple;
      case 'consultation_ended':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
      ),
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
                    final ta = a.data()['createdAt'] as Timestamp?;
                    final tb = b.data()['createdAt'] as Timestamp?;
                    if (ta == null) return 1;
                    if (tb == null) return -1;
                    return tb.compareTo(ta);
                  });
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text('No notifications yet',
                            style: TextStyle(
                                color: Colors.grey.shade600, fontSize: 16)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final type = (data['type'] ?? '').toString();
                    final isRead = data['isRead'] == true;

                    return ListTile(
                      tileColor: isRead ? null : const Color(0xFFE3F2FD).withOpacity(0.4),
                      leading: CircleAvatar(
                        backgroundColor:
                            _colorForType(type).withOpacity(0.15),
                        child: Icon(_iconForType(type),
                            color: _colorForType(type), size: 22),
                      ),
                      title: Text(
                        (data['title'] ?? '').toString(),
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text((data['body'] ?? '').toString(),
                              style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(data['createdAt'] as Timestamp?),
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                      onTap: () => NotificationService.markAsRead(docs[i].id),
                    );
                  },
                );
              },
            ),
    );
  }
}
