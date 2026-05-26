import 'package:flutter/foundation.dart' show kReleaseMode;

// Design Ref: §5.1 — API Base URL + 엔드포인트 중앙 관리
// Debug(시뮬레이터) → localhost / Release(실기기 배포) → 배포서버
class ApiConfig {
  static const String baseUrl = kReleaseMode
      ? 'https://main-api.linkerbiz.net'
      : 'http://localhost:20118';

  static const String login = '/api/LB/user/userAccess';
  static const String logout = '/api/LB/user/userAccessOut';
  static const String findId = '/api/LB/account/findId';
  static const String resetPassword = '/api/LB/account/resetPassword';
  static const String myInfo = '/api/LB/account/myInfo';
  static const String changePassword = '/api/LB/account/changePassword';
  static const String updateProfile = '/api/LB/account/updateProfile';

  // FCM 토큰
  static const String fcmTokenAccess = '/api/LB/fcm/token/access';
  static const String fcmTokenRead = '/api/LB/fcm/token/read';
  static const String fcmTokenDeactivate = '/api/LB/fcm/token/deactivate';

  // FCM 발송 이력
  static const String fcmLogMy = '/api/LB/fcm/log/my';
  static const String fcmLogRead = '/api/LB/fcm/log/read';
  static const String fcmLogReadAll = '/api/LB/fcm/log/readAll';
  static const String fcmLogUnreadCount = '/api/LB/fcm/log/unreadCount';

  // 지급서 OCR + CRUD
  static const String invoiceParse = '/api/vision/invoice/parse';
  static const String invoiceSave = '/api/vision/invoice/save';
  static const String invoiceUpdate = '/api/vision/invoice/update';
  static const String invoiceDetail = '/api/vision/invoice/detail';
  static const String invoiceList = '/api/vision/invoice/list';
  static const String invoiceDelete = '/api/vision/invoice/delete';

  // 결재 프로세스
  static const String invoiceRequest = '/api/vision/invoice/request';
  static const String invoiceApprovalHistory = '/api/vision/invoice/approvalHistory';

  // 드롭다운 데이터
  static const String hyunjangRead = '/api/LB/hyunjang/hyunjangRead';
  static const String accountCategoryAll = '/api/LB/accounting/category/all';
  static const String partnerFindAll = '/api/LB/accounting/partner/findAll';
}
