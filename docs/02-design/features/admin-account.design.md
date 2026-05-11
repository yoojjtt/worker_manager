# Design: 관리자 계정 관리 (admin-account)

> Feature: admin-account
> Created: 2026-05-11
> Architecture: Option C — Pragmatic Balance
> Plan: docs/01-plan/features/admin-account.plan.md

---

## Context Anchor

| 항목 | 내용 |
|------|------|
| **WHY** | 스플래시→로그인 화면까지 UI는 완성되었으나 API 연동이 없어 실제 로그인이 불가능하다. 관리자 앱의 최소 진입 조건을 충족해야 한다 |
| **WHO** | LinkerBiz 서비스를 사용하는 회사 관리자 (user_type 8~9) |
| **RISK** | 서버 API 스펙 변경 시 클라이언트 수정 필요, 자동로그인 시 자격증명 보안 관리 |
| **SUCCESS** | 로그인→내정보 조회/수정→로그아웃 전체 플로우가 동작, 아이디찾기/비밀번호 재설정 정상 작동 |
| **SCOPE** | API 7개 연동 (로그인, 로그아웃, 아이디찾기, 비밀번호재설정, 내정보, 비밀번호변경, 프로필변경) |

---

## 1. Overview

### 1.1 설계 방향
- **Pragmatic Balance**: API 호출을 service 레이어로 분리하되, Repository/UseCase 같은 과도한 추상화는 하지 않는다
- 각 Screen은 Service를 직접 호출하고, 로딩/에러 상태는 각 Screen의 setState로 관리
- 로그인 사용자 정보는 AuthService 싱글톤에서 보유

### 1.2 핵심 결정사항
| 결정 | 선택 | 이유 |
|------|------|------|
| HTTP 클라이언트 | `http` 패키지 | 단순 POST 호출만 필요, dio는 과도함 |
| 상태관리 | StatefulWidget + setState | 화면 7개 규모에 적합, 추후 확장 가능 |
| 자격증명 저장 | `flutter_secure_storage` | OS 키체인/키스토어 활용, 보안 우수 |
| 네비게이션 | Navigator.push/pushReplacement | named route 불필요한 규모 |
| 사용자 세션 | AuthService 싱글톤 | 앱 전역에서 로그인 사용자 접근 |

---

## 2. 프로젝트 구조

```
lib/
├── main.dart                              # 앱 진입점 (변경 없음)
├── config/
│   └── api_config.dart                    # [신규] Base URL, 엔드포인트 상수
├── models/
│   └── user_model.dart                    # [신규] UserModel (fromJson/toJson)
├── services/
│   ├── api_service.dart                   # [신규] HTTP POST 공통 래퍼
│   └── auth_service.dart                  # [신규] 로그인/로그아웃/자동로그인/세션
├── screens/
│   ├── splash_screen.dart                 # [수정] 자동로그인 체크 추가
│   ├── login_screen.dart                  # [수정] API 연동
│   ├── find_id_screen.dart                # [신규] 아이디 찾기
│   ├── reset_password_screen.dart         # [신규] 비밀번호 재설정
│   ├── home_screen.dart                   # [신규] 로그인 후 메인
│   └── my_info/
│       ├── my_info_screen.dart            # [신규] 내 정보 조회/수정
│       └── change_password_screen.dart    # [신규] 비밀번호 변경
└── widgets/
    └── loading_overlay.dart               # [신규] 로딩 오버레이
```

**파일 수**: 12개 (기존 수정 2 + 신규 10)

---

## 3. 데이터 모델

### 3.1 UserModel (`lib/models/user_model.dart`)

```dart
class UserModel {
  final int seq;
  final String userUUID;
  final String userId;
  final String userName;
  final String? userEmail;
  final String? userCell;
  final String? userProfileURL;
  final String companyKey;
  final int userType;       // 9=관리자, 8=회사사용자, 7=직원, 6=퇴직관리
  final int userLevel;      // 9=마스터, 8=회사마스터, 7=회사직원
  final String? userAddress;
  final String? userAddressDetail;
  final String? userBankAccount;
  final String? userBankHolder;
  final String? userBankName;
  final String? memo;
  final String? createDT;
  final String? updateDT;

  // factory UserModel.fromJson(Map<String, dynamic> json)
  // Map<String, dynamic> toJson()
}
```

**JSON 필드 매핑** (snake_case → camelCase):
| JSON 키 | Dart 필드 |
|---------|-----------|
| `user_UUID` | `userUUID` |
| `user_id` | `userId` |
| `user_name` | `userName` |
| `user_email` | `userEmail` |
| `user_cell` | `userCell` |
| `user_profileURL` | `userProfileURL` |
| `company_key` | `companyKey` |
| `user_type` | `userType` |
| `user_level` | `userLevel` |
| `user_address` | `userAddress` |
| `user_address_detail` | `userAddressDetail` |
| `user_bank_account` | `userBankAccount` |
| `user_bank_holder` | `userBankHolder` |
| `user_bank_name` | `userBankName` |
| `create_DT` | `createDT` |
| `update_DT` | `updateDT` |

---

## 4. API 계약 (Contract)

### 4.1 공통 응답 구조

```dart
// ApiService에서 처리
class ApiResponse {
  final String resultCode;  // "200"=성공
  final dynamic res;        // Object, Array, or String
}
```

### 4.2 엔드포인트 상세

#### API-01: 로그인
```
POST {baseUrl}/api/LB/user/userAccess
Body: { "username": String, "password": String }
Success 200: { "resultCode": "200", "res": [UserModel] }  // Array!
Fail: resultCode 300 (비밀번호 불일치), 400 (계정 없음)
```
> **주의**: `res`가 Array. `res[0]`으로 접근.

#### API-02: 로그아웃
```
POST {baseUrl}/api/LB/user/userAccessOut
Body: { "username": String, "password": String }
Success 200: { "resultCode": "200", "res": [...] }
```
> **주의**: 로그아웃에도 username/password 필요 → auth_service에 자격증명 보관 필요

#### API-03: 아이디 찾기
```
POST {baseUrl}/api/LB/account/findId
Body: { "user_name": String, "user_cell": String }
Success 200: { "resultCode": "200", "res": { "user_id": "hon*****" } }
Fail: 400 (일치 없음), 401 (user_name 누락), 402 (user_cell 누락)
```

#### API-04: 비밀번호 재설정
```
POST {baseUrl}/api/LB/account/resetPassword
Body: { "user_id": String, "user_name": String, "user_cell": String }
Success 200: { "resultCode": "200", "res": "임시 비밀번호가 SMS로 발송되었습니다." }
Fail: 400~403 (필수값), 500 (SMS 실패)
```

#### API-05: 내 정보 조회
```
POST {baseUrl}/api/LB/account/myInfo
Body: { "user_id": String }
Success 200: { "resultCode": "200", "res": UserModel }  // Object (not Array)
Fail: 400 (user_id 누락 / 계정 없음)
```

#### API-06: 비밀번호 변경
```
POST {baseUrl}/api/LB/account/changePassword
Body: { "user_id": String, "current_password": String, "new_password": String }
Success 200: { "resultCode": "200", "res": "비밀번호가 변경되었습니다." }
Fail: 300 (현재PW 불일치), 400 (6자 미만 / 계정 없음), 401 (동일PW)
```

#### API-07: 프로필 변경
```
POST {baseUrl}/api/LB/account/updateProfile
Body: { "user_id": String, "user_cell"?: String, "user_email"?: String }
Success 200: { "resultCode": "200", "res": UserModel }
Fail: 400 (user_id 누락 / 계정 없음)
```

---

## 5. Service 설계

### 5.1 ApiConfig (`lib/config/api_config.dart`)

```dart
class ApiConfig {
  // TODO: 실제 서버 주소로 교체
  static const String baseUrl = 'https://api.example.com';

  // 엔드포인트
  static const String login = '/api/LB/user/userAccess';
  static const String logout = '/api/LB/user/userAccessOut';
  static const String findId = '/api/LB/account/findId';
  static const String resetPassword = '/api/LB/account/resetPassword';
  static const String myInfo = '/api/LB/account/myInfo';
  static const String changePassword = '/api/LB/account/changePassword';
  static const String updateProfile = '/api/LB/account/updateProfile';
}
```

### 5.2 ApiService (`lib/services/api_service.dart`)

```dart
class ApiService {
  /// 공통 POST 요청
  /// 반환: { "resultCode": String, "res": dynamic }
  /// 네트워크 오류 시 Exception throw
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('서버 오류: ${response.statusCode}');
  }
}
```

**설계 포인트**:
- `static` 메서드로 인스턴스 불필요
- 15초 타임아웃
- HTTP 200이 아니면 Exception
- resultCode 해석은 호출자(Screen/AuthService)가 담당

### 5.3 AuthService (`lib/services/auth_service.dart`)

```dart
class AuthService {
  // 싱글톤
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final _storage = const FlutterSecureStorage();

  // 현재 로그인 사용자 (앱 전역 접근)
  UserModel? currentUser;

  // 로그아웃용 자격증명 보관 (메모리)
  String? _username;
  String? _password;

  /// 로그인
  Future<({bool success, String message})> login(String username, String password) async {
    final data = await ApiService.post(ApiConfig.login, {
      'username': username,
      'password': password,
    });
    if (data['resultCode'] == '200') {
      final list = data['res'] as List;
      currentUser = UserModel.fromJson(list[0]);
      _username = username;
      _password = password;
      return (success: true, message: '');
    }
    // resultCode별 에러 메시지 매핑
    return (success: false, message: _loginErrorMessage(data['resultCode']));
  }

  /// 로그아웃
  Future<void> logout() async {
    if (_username != null && _password != null) {
      try {
        await ApiService.post(ApiConfig.logout, {
          'username': _username!,
          'password': _password!,
        });
      } catch (_) {} // 로그아웃 API 실패해도 로컬 세션은 정리
    }
    currentUser = null;
    _username = null;
    _password = null;
    await clearAutoLogin();
  }

  /// 자동로그인 저장
  Future<void> saveAutoLogin(String username, String password) async {
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);
  }

  /// 자동로그인 읽기
  Future<({String? username, String? password})> getAutoLogin() async {
    final username = await _storage.read(key: 'username');
    final password = await _storage.read(key: 'password');
    return (username: username, password: password);
  }

  /// 자동로그인 삭제
  Future<void> clearAutoLogin() async {
    await _storage.deleteAll();
  }

  /// 내 정보 새로고침
  Future<UserModel?> refreshMyInfo() async {
    if (currentUser == null) return null;
    final data = await ApiService.post(ApiConfig.myInfo, {
      'user_id': currentUser!.userId,
    });
    if (data['resultCode'] == '200') {
      currentUser = UserModel.fromJson(data['res']);
      return currentUser;
    }
    return null;
  }
}
```

**설계 포인트**:
- 싱글톤으로 앱 전역에서 `AuthService().currentUser` 접근
- `_username`/`_password`를 메모리에 보관: 로그아웃 API에 필요하기 때문
- 자동로그인은 `flutter_secure_storage`로 암호화 저장 (OS 키체인)
- Record 타입 `({bool success, String message})`으로 결과 반환 (Dart 3.0+)

---

## 6. 화면 설계

### 6.1 SplashScreen (수정)

**변경 사항**: 애니메이션 완료 후 자동로그인 체크 로직 추가

```
[기존] 애니메이션 완료 → LoginScreen
[변경] 애니메이션 완료 → 자동로그인 체크
  ├── 저장된 자격증명 있음 → API 로그인 시도
  │     ├── 성공 → HomeScreen
  │     └── 실패 → 저장 삭제 → LoginScreen
  └── 저장 없음 → LoginScreen
```

**수정 범위**: `_controller.addStatusListener` 콜백을 `_checkAutoLogin()` 비동기 메서드로 교체

### 6.2 LoginScreen (수정)

**변경 사항**: `_onLogin()` 구현

```dart
void _onLogin() async {
  // 1. 빈 값 검증
  // 2. 로딩 표시
  // 3. AuthService().login() 호출
  // 4. 성공: 자동로그인 체크면 저장 → HomeScreen
  // 5. 실패: SnackBar 에러 메시지
  // 6. 로딩 해제
}
```

**추가**: 아이디찾기/비밀번호재설정 버튼 `onPressed`에 Navigator.push 연결

### 6.3 FindIdScreen (신규)

```
┌─────────────────────────────┐
│ ← 아이디 찾기                │
├─────────────────────────────┤
│                             │
│  이름과 핸드폰번호를 입력하세요  │
│                             │
│  이름                        │
│  [________________]         │
│                             │
│  핸드폰번호                   │
│  [________________]         │
│                             │
│  [   아이디 찾기   ]          │
│                             │
│  ┌─ 결과 ──────────────┐    │
│  │ 조회된 아이디:        │    │
│  │ hon*****            │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

- 성공 시 결과 영역에 마스킹 아이디 표시
- "로그인 화면으로" 버튼 제공

### 6.4 ResetPasswordScreen (신규)

```
┌─────────────────────────────┐
│ ← 비밀번호 재설정             │
├─────────────────────────────┤
│                             │
│  아이디, 이름, 핸드폰번호를    │
│  입력하세요                   │
│                             │
│  아이디                      │
│  [________________]         │
│                             │
│  이름                        │
│  [________________]         │
│                             │
│  핸드폰번호                   │
│  [________________]         │
│                             │
│  [  임시 비밀번호 발송  ]      │
│                             │
│  ┌─ 안내 ──────────────┐    │
│  │ 임시 비밀번호가 SMS로  │    │
│  │ 발송되었습니다.        │    │
│  │ [로그인 화면으로]      │    │
│  └─────────────────────┘    │
└─────────────────────────────┘
```

### 6.5 HomeScreen (신규)

```
┌─────────────────────────────┐
│ LINKER.        홍길동 님 ▼   │
├─────────────────────────────┤
│                             │
│  (추후 메인 콘텐츠 영역)      │
│                             │
│                             │
├─────────────────────────────┤
│ [🏠 홈]  [👤 내정보]         │
└─────────────────────────────┘
```

- 간단한 Scaffold + BottomNavigationBar (홈/내정보 2탭)
- 상단에 로그인 사용자 이름 표시
- 홈 탭: 추후 기능 추가용 placeholder
- 내정보 탭: MyInfoScreen

### 6.6 MyInfoScreen (신규)

```
┌─────────────────────────────┐
│ 내 정보                      │
├─────────────────────────────┤
│                             │
│  ┌─ 프로필 카드 ──────────┐  │
│  │ 👤 홍길동              │  │
│  │ LINKER2024000001      │  │
│  │ 회사마스터 · 회사사용자  │  │
│  └───────────────────────┘  │
│                             │
│  연락처 정보                  │
│  이메일    hong@test.com [✏️] │
│  핸드폰    01012345678   [✏️] │
│                             │
│  주소                        │
│  서울시 강남구 101동 201호     │
│                             │
│  은행 정보                    │
│  신한은행 110-123-456789      │
│  예금주: 홍길동               │
│                             │
│  [비밀번호 변경]              │
│  [로그아웃]                   │
└─────────────────────────────┘
```

- initState에서 `ApiService.post(myInfo)` 호출하여 최신 정보 로드
- 이메일/핸드폰 옆 편집 아이콘: 인라인 편집 후 updateProfile API 호출
- 비밀번호 변경: ChangePasswordScreen으로 push
- 로그아웃: 확인 다이얼로그 → AuthService.logout() → LoginScreen

### 6.7 ChangePasswordScreen (신규)

```
┌─────────────────────────────┐
│ ← 비밀번호 변경               │
├─────────────────────────────┤
│                             │
│  현재 비밀번호                │
│  [________________]         │
│                             │
│  새 비밀번호 (6자 이상)       │
│  [________________]         │
│                             │
│  새 비밀번호 확인             │
│  [________________]         │
│                             │
│  [   비밀번호 변경   ]        │
└─────────────────────────────┘
```

- 클라이언트 검증: 6자 미만, 새 비밀번호 불일치
- 성공 시: "비밀번호가 변경되었습니다. 다시 로그인해주세요" → 로그인 화면

---

## 7. 네비게이션 흐름

```
SplashScreen
  ├── [자동로그인 성공] pushReplacement → HomeScreen
  └── [자동로그인 없음/실패] pushReplacement → LoginScreen
        ├── [로그인 성공] pushReplacement → HomeScreen
        ├── [아이디 찾기] push → FindIdScreen
        │     └── [로그인으로] pop
        └── [비밀번호 재설정] push → ResetPasswordScreen
              └── [로그인으로] pop

HomeScreen (BottomNav)
  ├── Tab 0: 홈 (placeholder)
  └── Tab 1: MyInfoScreen
        ├── [비밀번호 변경] push → ChangePasswordScreen
        │     └── [변경 성공] pushAndRemoveUntil → LoginScreen
        └── [로그아웃] pushAndRemoveUntil → LoginScreen
```

**핵심 네비게이션 규칙**:
- 로그인/자동로그인 → `pushReplacement` (뒤로가기 방지)
- 아이디찾기/비밀번호재설정 → `push` (뒤로가기로 로그인 복귀)
- 로그아웃/비밀번호변경완료 → `pushAndRemoveUntil` (스택 초기화)

---

## 8. 에러 처리 전략

### 8.1 API resultCode 매핑

| API | resultCode | 사용자 메시지 |
|-----|:----------:|-------------|
| 로그인 | 300 | 비밀번호가 일치하지 않습니다 |
| 로그인 | 400 | 등록되지 않은 계정입니다 |
| 아이디찾기 | 400 | 일치하는 계정을 찾을 수 없습니다 |
| 비밀번호재설정 | 400 | 일치하는 계정을 찾을 수 없습니다 |
| 비밀번호재설정 | 500 | SMS 발송에 실패했습니다. 잠시 후 다시 시도해주세요 |
| 비밀번호변경 | 300 | 현재 비밀번호가 일치하지 않습니다 |
| 비밀번호변경 | 400 | 새 비밀번호는 6자 이상이어야 합니다 |
| 비밀번호변경 | 401 | 현재 비밀번호와 동일한 비밀번호입니다 |
| 공통 | 네트워크 오류 | 네트워크 연결을 확인해주세요 |
| 공통 | 타임아웃 | 서버 응답이 없습니다. 잠시 후 다시 시도해주세요 |

### 8.2 에러 표시 방식
- **SnackBar**: 일반 에러 (로그인 실패, API 오류)
- **다이얼로그**: 중요한 안내 (비밀번호 변경 성공, 로그아웃 확인)

---

## 9. 보안 설계

| 항목 | 설계 |
|------|------|
| 자격증명 저장 | `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences) |
| 메모리 내 비밀번호 | AuthService 싱글톤에 보관, 로그아웃 시 null 처리 |
| API 통신 | HTTPS 필수 (baseUrl https:// 강제) |
| 비밀번호 표시 | 기본 숨김, 토글 가능 (기존 LoginScreen 패턴 유지) |

---

## 10. 패키지 의존성

```yaml
# pubspec.yaml에 추가
dependencies:
  http: ^1.4.0
  shared_preferences: ^2.5.0
  flutter_secure_storage: ^9.2.0
```

---

## 11. Implementation Guide

### 11.1 구현 순서

| 단계 | 파일 | 작업 | 예상 라인 |
|:----:|------|------|:---------:|
| 1 | `pubspec.yaml` | 패키지 추가 | ~3 |
| 2 | `lib/config/api_config.dart` | API 상수 정의 | ~15 |
| 3 | `lib/models/user_model.dart` | UserModel + fromJson | ~60 |
| 4 | `lib/services/api_service.dart` | HTTP POST 래퍼 | ~30 |
| 5 | `lib/services/auth_service.dart` | 인증 서비스 | ~80 |
| 6 | `lib/widgets/loading_overlay.dart` | 로딩 오버레이 | ~30 |
| 7 | `lib/screens/login_screen.dart` | API 연동 수정 | ~+40 |
| 8 | `lib/screens/find_id_screen.dart` | 아이디 찾기 | ~180 |
| 9 | `lib/screens/reset_password_screen.dart` | 비밀번호 재설정 | ~200 |
| 10 | `lib/screens/home_screen.dart` | 메인 + BottomNav | ~120 |
| 11 | `lib/screens/my_info/my_info_screen.dart` | 내 정보 | ~300 |
| 12 | `lib/screens/my_info/change_password_screen.dart` | PW 변경 | ~200 |
| 13 | `lib/screens/splash_screen.dart` | 자동로그인 수정 | ~+30 |

**총 예상**: ~1,300 라인 (신규 ~1,200 + 수정 ~100)

### 11.2 의존성 그래프

```
api_config ─────────┐
                    ▼
user_model ──→ api_service ──→ auth_service
                    │               │
                    ▼               ▼
              loading_overlay   splash_screen
                    │           login_screen
                    ▼           find_id_screen
              home_screen       reset_password_screen
              my_info_screen
              change_password_screen
```

### 11.3 Session Guide

**Module Map**:

| Module | 파일 | 설명 |
|--------|------|------|
| module-1 | api_config, user_model, api_service, auth_service, loading_overlay | 기반 레이어 (config + model + service + widget) |
| module-2 | login_screen, splash_screen | 로그인 + 자동로그인 연동 |
| module-3 | find_id_screen, reset_password_screen | 계정 찾기/복구 |
| module-4 | home_screen, my_info_screen, change_password_screen | 로그인 후 화면 (내정보) |

**Recommended Session Plan**:

| 세션 | Module | 소요 | 설명 |
|:----:|--------|:----:|------|
| 1 | module-1 + module-2 | ~40min | 기반 구축 + 로그인 동작 확인 |
| 2 | module-3 + module-4 | ~50min | 나머지 화면 전체 구현 |

> 1회 세션으로 전체 구현도 가능 (~90min). 분할 시 module-1,2 먼저 완성하여 로그인 테스트 후 진행 권장.

---

## 12. 디자인 토큰 (기존 코드 기반)

기존 LoginScreen/SplashScreen에서 추출한 디자인 토큰:

| 토큰 | 값 | 용도 |
|------|-----|------|
| `primaryColor` | `#1B2E5C` | 로고, 포커스 보더, 헤더 |
| `accentColor` | `#FFD700` | 로그인 버튼 배경 |
| `backgroundColor` | `#F5F5F7` | Scaffold 배경 |
| `cardColor` | `#FFFFFF` | 카드 배경 |
| `inputFillColor` | `#FAF8F0` | 입력 필드 배경 |
| `textPrimary` | `#3A3A3A` | 본문 텍스트 |
| `textSecondary` | `#6B6B6B` | 보조 텍스트 |
| `borderRadius` | `16px` (카드), `12px` (버튼), `10px` (입력) | 모서리 |
| `cardShadow` | `black 5%, blur 20, offset (0,4)` | 카드 그림자 |
