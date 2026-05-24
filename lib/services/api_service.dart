import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

// Design Ref: §5.2 — HTTP POST 공통 래퍼, 15초 타임아웃
class ApiService {
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('서버 오류: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  // Design Ref: §3.2 — GET 요청 (query parameter 방식)
  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: params);
    try {
      final response = await http
          .get(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('서버 오류: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  // Design Ref: §3.2 — multipart 파일 업로드
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    File file, {
    Map<String, String>? fields,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    try {
      final request = http.MultipartRequest('POST', url);
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
      if (fields != null) request.fields.addAll(fields);

      final streamResponse =
          await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('서버 오류: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('파일 업로드 시간이 초과되었습니다.');
    }
  }

  // Design Ref: §3.2 — PUT 요청 (query parameter 방식)
  static Future<Map<String, dynamic>> put(
    String endpoint, {
    Map<String, String>? params,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: params);
    try {
      final response = await http
          .put(url, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('서버 오류: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
    }
  }

  // PUT 요청 (JSON body 방식)
  static Future<Map<String, dynamic>> putBody(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    try {
      final response = await http
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('서버 오류: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('서버 응답이 없습니다. 잠시 후 다시 시도해주세요.');
    }
  }
}
