// Design Ref: §5.1 — API Base URL + 엔드포인트 중앙 관리
const bool isProduction = bool.fromEnvironment('PRODUCTION');

class ApiConfig {
  static const String baseUrl = isProduction
      ? 'https://main-api.linkerbiz.net'
      : 'https://main-api.linkerbiz.net';

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
}
