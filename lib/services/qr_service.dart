// Design Ref: §4.2 — QR 관리 서비스 (4 API)
import '../config/api_config.dart';
import '../models/qr_model.dart';
import 'api_service.dart';

class QrService {
  /// 출근 QR 생성
  static Future<QrInfo> generateCheckin({
    required String companyKey,
    required String hyunjangKey,
    required String workDate,
    required double gpsLat,
    required double gpsLng,
    int gpsRadiusM = 500,
    int expiredMinutes = 480,
    int maxUse = 50,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.qrGenerateCheckin, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'work_date': workDate,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_radius_m': gpsRadiusM,
      'expired_minutes': expiredMinutes,
      'max_use': maxUse,
      'user_id': userId,
    });
    return _handleResponse(response, (res) => QrInfo.fromJson(res));
  }

  /// 퇴근 QR 생성
  static Future<QrInfo> generateCheckout({
    required String companyKey,
    required String hyunjangKey,
    required String workDate,
    required double gpsLat,
    required double gpsLng,
    int gpsRadiusM = 500,
    int expiredMinutes = 480,
    int maxUse = 50,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.qrGenerateCheckout, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'work_date': workDate,
      'gps_lat': gpsLat,
      'gps_lng': gpsLng,
      'gps_radius_m': gpsRadiusM,
      'expired_minutes': expiredMinutes,
      'max_use': maxUse,
      'user_id': userId,
    });
    return _handleResponse(response, (res) => QrInfo.fromJson(res));
  }

  /// QR 이력 조회
  static Future<List<QrInfo>> readQrList({
    required String companyKey,
    String? hyunjangKey,
    String? workDate,
    String? userId,
  }) async {
    final body = <String, dynamic>{'company_key': companyKey};
    if (hyunjangKey != null) body['hyunjang_key'] = hyunjangKey;
    if (workDate != null) body['work_date'] = workDate;
    if (userId != null) body['user_id'] = userId;

    final response = await ApiService.post(ApiConfig.qrReadList, body);
    return _handleResponse(
      response,
      (res) => _parseList(res, (e) => QrInfo.fromJson(e)),
    );
  }

  /// 서버 응답이 List 직접 또는 페이징({ data: [...] }) 구조일 수 있음
  static List<T> _parseList<T>(
    dynamic res,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    List? list;
    if (res is List) {
      list = res;
    } else if (res is Map) {
      list = res['data'] as List? ?? res['resultModel'] as List? ?? res['list'] as List?;
    }
    if (list == null) return <T>[];
    return list.map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  /// QR 무효화
  static Future<void> invalidateQr({
    required int seq,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.qrInvalidate, {
      'seq': seq,
      'user_id': userId,
    });
    _handleResponse<void>(response, (_) {});
  }

  // Design Ref: §6.1 — resultCode별 공통 에러 처리
  static T _handleResponse<T>(
    Map<String, dynamic> response,
    T Function(dynamic res) parser,
  ) {
    final code = response['resultCode'] as String? ?? '500';
    final res = response['res'];

    if (code == '200') return parser(res);

    final message = switch (code) {
      '400' => res?.toString() ?? '입력값을 확인해주세요.',
      '404' => res?.toString() ?? '데이터를 찾을 수 없습니다.',
      '410' => 'QR이 만료되었습니다. 다시 생성해주세요.',
      '429' => res?.toString() ?? '사용 횟수를 초과했습니다.',
      _ => '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.',
    };
    throw Exception(message);
  }
}
