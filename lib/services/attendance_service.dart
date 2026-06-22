// Design Ref: §4.2 — 출결 관리 서비스 (12 API)
import '../config/api_config.dart';
import '../models/attendance_model.dart';
import 'api_service.dart';

class AttendanceService {
  // === 출근 승인 (2-1, 2-2, 2-3) ===

  static Future<List<CheckinRequest>> readCheckinList({
    required String companyKey,
    required String hyunjangKey,
    required String workDate,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.attReadCheckinList, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'work_date': workDate,
      'user_id': userId,
    });
    return _handleResponse(
      response,
      (res) =>
          _parseList(res, (e) => CheckinRequest.fromJson(e)),
    );
  }

  static Future<void> approveCheckin({
    required int seq,
    String? approveReason,
    required String userId,
  }) async {
    final body = <String, dynamic>{
      'seq': seq,
      'user_id': userId,
    };
    if (approveReason != null) body['approve_reason'] = approveReason;
    final response =
        await ApiService.post(ApiConfig.attApproveCheckin, body);
    _handleResponse<void>(response, (_) {});
  }

  static Future<void> rejectCheckin({
    required int seq,
    required String approveReason,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.attRejectCheckin, {
      'seq': seq,
      'approve_reason': approveReason,
      'user_id': userId,
    });
    _handleResponse<void>(response, (_) {});
  }

  // === 수기 등록 (3-1, 3-2, 3-3) ===

  static Future<int> manualCheckin({
    required String companyKey,
    required String hyunjangKey,
    required String employeeKey,
    required String workDate,
    String? checkinDt,
    required String manualReason,
    required String userId,
  }) async {
    final body = <String, dynamic>{
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'employee_key': employeeKey,
      'work_date': workDate,
      'manual_reason': manualReason,
      'user_id': userId,
    };
    if (checkinDt != null) body['checkin_dt'] = checkinDt;
    final response =
        await ApiService.post(ApiConfig.attManualCheckin, body);
    return _handleResponse(response, (res) => res['seq'] as int);
  }

  static Future<void> manualCheckout({
    required int seq,
    int? unitPrice,
    required String userId,
  }) async {
    final body = <String, dynamic>{
      'seq': seq,
      'user_id': userId,
    };
    if (unitPrice != null) body['unit_price'] = unitPrice;
    final response =
        await ApiService.post(ApiConfig.attManualCheckout, body);
    _handleResponse<void>(response, (_) {});
  }

  static Future<int> manualBulk({
    required String manualReason,
    required String userId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await ApiService.post(ApiConfig.attManualBulk, {
      'manual_reason': manualReason,
      'user_id': userId,
      'items': items,
    });
    return _handleResponse(response, (res) => res['count'] as int);
  }

  // === 공수/단가 (4-1, 4-2, 4-3) ===

  static Future<void> adjustKongsu({
    required int seq,
    required double workedKongsu,
    required String changeReason,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.attAdjustKongsu, {
      'seq': seq,
      'worked_kongsu': workedKongsu,
      'change_reason': changeReason,
      'user_id': userId,
    });
    _handleResponse<void>(response, (_) {});
  }

  static Future<void> cancelKongsu({
    required int seq,
    required String changeReason,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.attCancelKongsu, {
      'seq': seq,
      'change_reason': changeReason,
      'user_id': userId,
    });
    _handleResponse<void>(response, (_) {});
  }

  static Future<void> adjustDanga({
    required int seq,
    required int unitPrice,
    required String changeReason,
    required String userId,
  }) async {
    final response = await ApiService.post(ApiConfig.attAdjustDanga, {
      'seq': seq,
      'unit_price': unitPrice,
      'change_reason': changeReason,
      'user_id': userId,
    });
    _handleResponse<void>(response, (_) {});
  }

  // === 현황 조회 (5-1, 5-2) ===

  static Future<MonthlyOverview> readMonthlyOverview({
    required String companyKey,
    required String hyunjangKey,
    required String month,
    required String userId,
  }) async {
    final response =
        await ApiService.post(ApiConfig.attMonthlyOverview, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'month': month,
      'user_id': userId,
    });
    return _handleResponse(
      response,
      (res) => MonthlyOverview.fromJson(res),
    );
  }

  static Future<List<DailyAttendance>> readDailyOverview({
    required String companyKey,
    required String hyunjangKey,
    required String workDate,
    required String userId,
  }) async {
    final response =
        await ApiService.post(ApiConfig.attDailyOverview, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'work_date': workDate,
      'user_id': userId,
    });
    return _handleResponse(
      response,
      (res) =>
          _parseList(res, (e) => DailyAttendance.fromJson(e)),
    );
  }

  // === kongsu 반영 (6-1, 6-2) ===

  static Future<List<SyncItem>> readSyncStatus({
    required String companyKey,
    required String hyunjangKey,
    required String month,
    required String userId,
  }) async {
    final response =
        await ApiService.post(ApiConfig.attReadSyncStatus, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'month': month,
      'user_id': userId,
    });
    return _handleResponse(
      response,
      (res) => _parseList(res, (e) => SyncItem.fromJson(e)),
    );
  }

  static Future<int> syncToKongsu({
    required String companyKey,
    required String hyunjangKey,
    required String month,
    List<int>? employeeKeys,
    required String userId,
  }) async {
    final body = <String, dynamic>{
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
      'month': month,
      'user_id': userId,
    };
    if (employeeKeys != null) body['employee_keys'] = employeeKeys;
    final response =
        await ApiService.post(ApiConfig.attSyncToKongsu, body);
    return _handleResponse(response, (res) => res['count'] as int);
  }

  // === 일용직 근로자 목록 ===

  static Future<List<DailyEmployee>> readEmployeeList({
    required String companyKey,
    required String hyunjangKey,
  }) async {
    final response =
        await ApiService.post(ApiConfig.dailyEmployeeList, {
      'company_key': companyKey,
      'hyunjang_key': hyunjangKey,
    });
    return _handleResponse(
      response,
      (res) =>
          _parseList(res, (e) => DailyEmployee.fromJson(e)),
    );
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
}
