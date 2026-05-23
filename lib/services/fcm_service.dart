import 'dart:developer' as dev;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../models/notification_model.dart';

class FcmService {
  static final FcmService _instance = FcmService._();
  factory FcmService() => _instance;
  FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final List<NotificationModel> notifications = [];
  final ValueNotifier<int> unreadCount = ValueNotifier(0);

  // 앱 내에서 알림 탭 시 이동할 때 사용
  GlobalKey<NavigatorState>? navigatorKey;

  Future<void> initialize() async {
    // 알림 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    dev.log('FCM 권한 상태: ${settings.authorizationStatus}');

    // FCM 토큰 가져오기 (시뮬레이터에서는 실패할 수 있음)
    try {
      final token = await _messaging.getToken();
      dev.log('FCM Token: $token');
    } catch (e) {
      dev.log('FCM 토큰 가져오기 실패 (시뮬레이터?): $e');
    }

    // 토큰 갱신 리스너
    _messaging.onTokenRefresh.listen((newToken) {
      dev.log('FCM Token 갱신: $newToken');
      // TODO: 서버에 새 토큰 전송
    });

    // 포그라운드 메시지 수신
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 백그라운드에서 알림 탭하여 앱 열기
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 앱이 종료된 상태에서 알림 탭하여 열기
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _addNotification(initialMessage, isRead: true);
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    dev.log('포그라운드 메시지 수신: ${message.notification?.title}');
    _addNotification(message);
    _showInAppNotification(message);
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    dev.log('알림 탭으로 앱 열림: ${message.notification?.title}');
    _addNotification(message, isRead: true);
  }

  void _addNotification(RemoteMessage message, {bool isRead = false}) {
    final notification = NotificationModel(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: message.notification?.title ?? '알림',
      body: message.notification?.body ?? '',
      receivedAt: DateTime.now(),
      data: message.data,
      isRead: isRead,
    );
    notifications.insert(0, notification);
    _updateUnreadCount();
  }

  void _showInAppNotification(RemoteMessage message) {
    final context = navigatorKey?.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.notification?.title ?? '알림',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (message.notification?.body != null)
              Text(
                message.notification!.body!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '보기',
          textColor: Colors.white,
          onPressed: () {
            navigatorKey?.currentState?.pushNamed('/notifications');
          },
        ),
      ),
    );
  }

  void markAsRead(String id) {
    final notification = notifications.where((n) => n.id == id).firstOrNull;
    if (notification != null) {
      notification.isRead = true;
      _updateUnreadCount();
    }
  }

  void markAllAsRead() {
    for (final n in notifications) {
      n.isRead = true;
    }
    _updateUnreadCount();
  }

  void deleteNotification(String id) {
    notifications.removeWhere((n) => n.id == id);
    _updateUnreadCount();
  }

  void _updateUnreadCount() {
    unreadCount.value = notifications.where((n) => !n.isRead).length;
  }
}
