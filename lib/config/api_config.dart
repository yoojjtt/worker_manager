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

  // Design Ref: §4.1 — QR 관리 (QrService)
  static const String qrGenerateCheckin = '/api/LB/qr/generateCheckin';
  static const String qrGenerateCheckout = '/api/LB/qr/generateCheckout';
  static const String qrReadList = '/api/LB/qr/readQrList';
  static const String qrInvalidate = '/api/LB/qr/invalidateQr';

  // Design Ref: §4.1 — 출근 승인 (AttendanceService)
  static const String attReadCheckinList =
      '/api/LB/attendance/readCheckinList';
  static const String attApproveCheckin =
      '/api/LB/attendance/approveCheckin';
  static const String attRejectCheckin =
      '/api/LB/attendance/rejectCheckin';

  // 수기 등록
  static const String attManualCheckin =
      '/api/LB/attendance/manualCheckin';
  static const String attManualCheckout =
      '/api/LB/attendance/manualCheckout';
  static const String attManualBulk = '/api/LB/attendance/manualBulk';

  // 공수/단가
  static const String attAdjustKongsu =
      '/api/LB/attendance/adjustKongsu';
  static const String attCancelKongsu =
      '/api/LB/attendance/cancelKongsu';
  static const String attAdjustDanga = '/api/LB/attendance/adjustDanga';

  // 현황 조회
  static const String attMonthlyOverview =
      '/api/LB/attendance/readMonthlyOverview';
  static const String attDailyOverview =
      '/api/LB/attendance/readDailyOverview';

  // kongsu 반영
  static const String attReadSyncStatus =
      '/api/LB/attendance/readSyncStatus';
  static const String attSyncToKongsu =
      '/api/LB/attendance/syncToKongsu';

  // 일용직 근로자 목록
  static const String dailyEmployeeRead =
      '/api/LB/dailyEmployee/employeeRead';
}
