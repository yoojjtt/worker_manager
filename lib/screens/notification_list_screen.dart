import 'dart:developer' as dev;

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final List<Map<String, dynamic>> _logs = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _size = 20;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() => _isLoading = true);

    if (refresh) {
      _offset = 0;
      _logs.clear();
      _hasMore = true;
    }

    try {
      final user = AuthService().currentUser;
      dev.log('[알림이력] currentUser: ${user?.userId}');
      if (user == null) {
        dev.log('[알림이력] 로그인 안 됨, return');
        return;
      }

      dev.log('[알림이력] API 호출: user_id=${user.userId}, offset=$_offset');
      final data = await ApiService.get(
        ApiConfig.fcmLogMy,
        params: {
          'user_id': user.userId,
          'app_type': 'WORKER_MANAGER',
          'offset': '$_offset',
          'size': '$_size',
        },
      );
      dev.log('[알림이력] 응답: resultCode=${data['resultCode']}, res=${data['res']}');

      if (data['resultCode'] == '200') {
        final res = Map<String, dynamic>.from(data['res'] as Map);
        final list = (res['list'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final total = res['totalRecords'] as int;
        dev.log('[알림이력] 조회 성공: ${list.length}건, 전체 $total건');

        _logs.addAll(list);
        _offset += list.length;
        _hasMore = _logs.length < total;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 이력 로드 실패: $e'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
      ),
      body: _isLoading && _logs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
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
    return RefreshIndicator(
      onRefresh: () => _loadLogs(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _logs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _logs.length) {
            _loadLogs();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final log = _logs[index];
          final success = log['success'] == 1;
          final createdAt = log['create_DT'] as String? ?? '';

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
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
                  color: success
                      ? const Color(0xFF1B2E5C).withValues(alpha: 0.1)
                      : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.notifications_active : Icons.error_outline,
                  color: success ? const Color(0xFF1B2E5C) : Colors.red,
                  size: 20,
                ),
              ),
              title: Text(
                log['title'] as String? ?? '알림',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    log['body'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatTime(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      if (!success) ...[
                        const SizedBox(width: 8),
                        Text(
                          '발송 실패',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.red.shade400,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              onTap: () => _showDetail(log),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(Map<String, dynamic> log) {
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
              log['title'] as String? ?? '알림',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2E5C),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  _formatTime(log['create_DT'] as String? ?? ''),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: log['success'] == 1
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log['success'] == 1 ? '발송 성공' : '발송 실패',
                    style: TextStyle(
                      fontSize: 11,
                      color: log['success'] == 1
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              log['body'] as String? ?? '',
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (log['error_message'] != null) ...[
              const SizedBox(height: 12),
              Text(
                '오류: ${log['error_message']}',
                style: TextStyle(fontSize: 13, color: Colors.red.shade400),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatTime(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return '방금 전';
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
      if (diff.inHours < 24) return '${diff.inHours}시간 전';
      if (diff.inDays < 7) return '${diff.inDays}일 전';
      return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }
}
