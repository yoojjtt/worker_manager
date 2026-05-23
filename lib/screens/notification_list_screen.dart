import 'package:flutter/material.dart';

import '../services/fcm_service.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final _fcm = FcmService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '알림',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2E5C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B2E5C)),
        actions: [
          if (_fcm.notifications.isNotEmpty)
            TextButton(
              onPressed: () {
                _fcm.markAllAsRead();
                setState(() {});
              },
              child: const Text(
                '모두 읽음',
                style: TextStyle(
                  color: Color(0xFF1B2E5C),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: _fcm.notifications.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '알림이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 알림이 오면 여기에 표시됩니다',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _fcm.notifications.length,
      itemBuilder: (context, index) {
        final notification = _fcm.notifications[index];
        return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.shade400,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) {
            _fcm.deleteNotification(notification.id);
            setState(() {});
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: notification.isRead ? Colors.white : const Color(0xFFE8EDF5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: notification.isRead
                    ? Colors.grey.shade200
                    : const Color(0xFF1B2E5C).withValues(alpha: 0.2),
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: notification.isRead
                      ? Colors.grey.shade100
                      : const Color(0xFF1B2E5C).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.isRead
                      ? Icons.notifications_none
                      : Icons.notifications_active,
                  color: notification.isRead
                      ? Colors.grey.shade400
                      : const Color(0xFF1B2E5C),
                  size: 20,
                ),
              ),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      notification.isRead ? FontWeight.w500 : FontWeight.w700,
                  color: const Color(0xFF1B2E5C),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.receivedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              onTap: () {
                _fcm.markAsRead(notification.id);
                setState(() {});
                _showDetail(notification);
              },
            ),
          ),
        );
      },
    );
  }

  void _showDetail(notification) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              notification.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2E5C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTime(notification.receivedAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 16),
            Text(
              notification.body,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${dt.month}/${dt.day}';
  }
}
