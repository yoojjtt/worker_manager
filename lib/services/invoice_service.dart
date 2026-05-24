import 'dart:io';

import '../config/api_config.dart';
import 'api_service.dart';

class InvoiceService {
  // OCR 파싱
  static Future<Map<String, dynamic>> parseInvoice(
    File imageFile,
    String companyKey,
  ) async {
    return ApiService.uploadFile(
      ApiConfig.invoiceParse,
      imageFile,
      fields: {'company_key': companyKey},
    );
  }

  // 저장
  static Future<Map<String, dynamic>> saveInvoice(
    Map<String, dynamic> data,
  ) async {
    return ApiService.post(ApiConfig.invoiceSave, data);
  }

  // 수정
  static Future<Map<String, dynamic>> updateInvoice(
    Map<String, dynamic> data,
  ) async {
    return ApiService.putBody(ApiConfig.invoiceUpdate, data);
  }

  // 상세 조회
  static Future<Map<String, dynamic>> getDetail(String seq) async {
    return ApiService.post(ApiConfig.invoiceDetail, {'seq': seq});
  }

  // 목록 조회
  static Future<Map<String, dynamic>> getList({
    required String companyKey,
    String? createId,
    String? invoiceMonth,
    String? status,
    String? srcWord,
    required int offset,
    required int size,
  }) async {
    final body = <String, dynamic>{
      'company_key': companyKey,
      'offset': offset,
      'size': size,
    };
    if (createId != null) body['create_ID'] = createId;
    if (invoiceMonth != null) body['invoice_month'] = invoiceMonth;
    if (status != null) body['status'] = status;
    if (srcWord != null && srcWord.isNotEmpty) body['src_word'] = srcWord;
    return ApiService.post(ApiConfig.invoiceList, body);
  }

  // 삭제
  static Future<Map<String, dynamic>> deleteInvoice(
    String seq,
    String deleteId,
  ) async {
    return ApiService.post(ApiConfig.invoiceDelete, {
      'seq': seq,
      'delete_ID': deleteId,
    });
  }

  // 결재요청
  static Future<Map<String, dynamic>> requestApproval({
    required String invoiceKey,
    required String actorId,
    String? actorName,
    String? comment,
  }) async {
    return ApiService.post(ApiConfig.invoiceRequest, {
      'invoice_key': invoiceKey,
      'actor_id': actorId,
      if (actorName != null) 'actor_name': actorName,
      if (comment != null) 'comment': comment,
    });
  }

  // 결재 이력 조회
  static Future<List<dynamic>> getApprovalHistory(String invoiceKey) async {
    final data = await ApiService.post(ApiConfig.invoiceApprovalHistory, {
      'invoice_key': invoiceKey,
    });
    if (data['resultCode'] == '200') {
      return data['res'] as List;
    }
    return [];
  }

  // 현장 목록 (공사중만)
  static Future<List<Map<String, dynamic>>> getHyunjangList(
    String companyKey,
  ) async {
    final data = await ApiService.post(ApiConfig.hyunjangRead, {
      'company_key': companyKey,
      'hyunjang_status': '1',
      'offset': 0,
      'size': 100,
    });
    if (data['resultCode'] == '200' && data['res'] != null) {
      final res = data['res'];
      // 페이징 응답: { data: [...] } 또는 { resultModel: [...] }
      if (res is Map) {
        final model = res['data'] ?? res['resultModel'] ?? res['list'];
        if (model is List) {
          return model
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      // 직접 리스트 응답
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  // 계정과목 목록
  static Future<List<Map<String, dynamic>>> getAccountCategories(
    String companyKey,
  ) async {
    final data = await ApiService.post(ApiConfig.accountCategoryAll, {
      'company_key': companyKey,
    });
    if (data['resultCode'] == '200' && data['res'] != null) {
      final res = data['res'];
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (res is Map) {
        final items = res['data'] ?? res['resultModel'] ?? res['list'];
        if (items is List) {
          return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    return [];
  }

  // 거래처 목록
  static Future<List<Map<String, dynamic>>> getPartners(
    String companyKey,
  ) async {
    final data = await ApiService.post(ApiConfig.partnerFindAll, {
      'company_key': companyKey,
    });
    if (data['resultCode'] == '200' && data['res'] != null) {
      final res = data['res'];
      if (res is List) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (res is Map) {
        final items = res['data'] ?? res['resultModel'] ?? res['list'];
        if (items is List) {
          return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    }
    return [];
  }
}
