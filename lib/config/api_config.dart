// Design Ref: §5.1 — API Base URL + 엔드포인트 중앙 관리
const bool isProduction = bool.fromEnvironment('PRODUCTION');

class ApiConfig {
  static const String baseUrl = isProduction
      ? 'https://main-api.linkerbiz.net'
      : 'http://localhost:20118';

  static const String login = '/api/LB/user/userAccess';
  static const String logout = '/api/LB/user/userAccessOut';
  static const String findId = '/api/LB/account/findId';
  static const String resetPassword = '/api/LB/account/resetPassword';
  static const String myInfo = '/api/LB/account/myInfo';
  static const String changePassword = '/api/LB/account/changePassword';
  static const String updateProfile = '/api/LB/account/updateProfile';
}
