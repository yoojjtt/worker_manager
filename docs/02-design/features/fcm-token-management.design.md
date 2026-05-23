# FCM 토큰 관리 Design

## Context Anchor

| Key | Value |
|-----|-------|
| WHY | 서버에서 관리자에게 업무 알림을 보내려면 FCM 토큰이 서버에 등록되어야 함 |
| WHO | 관리자(MANAGER) 앱 사용자 |
| RISK | 시뮬레이터에서 FCM 토큰 못 가져옴, 토큰 등록 API 실패 시 앱 크래시 방지 |
| SUCCESS | 로그인 후 토큰 자동 등록, 갱신 시 재등록, 내정보에서 ON/OFF 동작 |
| SCOPE | 토큰 등록/갱신/비활성화만. 관리 화면, 테스트 푸시는 제외 |

---

## 1. Overview

기존 `FcmService` 싱글톤에 서버 토큰 등록/비활성화 기능을 추가하고, `ApiService`에 GET/PUT 메서드를 추가하며, `MyInfoScreen`에 알림 ON/OFF 토글을 추가한다.

---

## 2. Architecture

### 2.1 변경 파일 목록

| 파일 | 변경 유형 | 내용 |
|------|----------|------|
| `lib/config/api_config.dart` | 수정 | FCM API 엔드포인트 3개 추가 |
| `lib/services/api_service.dart` | 수정 | `get()`, `put()` static 메서드 추가 |
| `lib/services/fcm_service.dart` | 수정 | 토큰 서버 등록/비활성화, 토큰 seq 관리, 알림 ON/OFF 상태 관리 |
| `lib/services/auth_service.dart` | 수정 | 로그인 성공 후 `FcmService.registerToken()` 호출 |
| `lib/screens/my_info/my_info_screen.dart` | 수정 | 알림 ON/OFF 토글 섹션 추가 |

### 2.2 데이터 흐름

```
[Login 성공]
  AuthService.login()
    → FcmService.registerToken(userId, companyKey)
      → FirebaseMessaging.getToken()
      → POST /api/LB/fcm/token/access { company_key, user_id, app_type:"MANAGER", token, device_os }
      → 응답 res(seq) → _tokenSeq에 저장
      → _pushEnabled = true → SecureStorage에 저장

[Token Refresh]
  onTokenRefresh 리스너
    → AuthService.currentUser != null 이면
    → FcmService.registerToken() 재호출

[알림 OFF]
  MyInfoScreen 토글 → FcmService.setPushEnabled(false)
    → PUT /api/LB/fcm/token/deactivate?seq={_tokenSeq}
    → _pushEnabled = false → SecureStorage에 저장

[알림 ON]
  MyInfoScreen 토글 → FcmService.setPushEnabled(true)
    → FcmService.registerToken() 재호출 (새 토큰 등록)
    → _pushEnabled = true → SecureStorage에 저장
```

---

## 3. API 연동 상세

### 3.1 ApiConfig 추가 엔드포인트

```dart
// FCM 토큰
static const String fcmTokenAccess = '/api/LB/fcm/token/access';
static const String fcmTokenRead = '/api/LB/fcm/token/read';
static const String fcmTokenDeactivate = '/api/LB/fcm/token/deactivate';
```

### 3.2 ApiService 추가 메서드

```dart
// GET 요청 (query parameter 방식)
static Future<Map<String, dynamic>> get(String endpoint, {Map<String, String>? params})

// PUT 요청 (query parameter 방식)
static Future<Map<String, dynamic>> put(String endpoint, {Map<String, String>? params})
```

### 3.3 토큰 등록 요청 Body

```json
{
  "company_key": 1,
  "user_id": "admin01",
  "app_type": "MANAGER",
  "token": "FCM토큰값",
  "device_os": "iOS"
}
```

> `device_id`는 선택 사항. 현재 단계에서는 생략.

### 3.4 토큰 비활성화 요청

```
PUT /api/LB/fcm/token/deactivate?seq=15
```

---

## 4. FcmService 변경 상세

### 4.1 추가 필드

```dart
int? _tokenSeq;          // 서버에 등록된 토큰의 seq (비활성화용)
bool _pushEnabled = true; // 알림 ON/OFF 상태
final _storage = const FlutterSecureStorage();
```

### 4.2 추가 메서드

| 메서드 | 설명 |
|--------|------|
| `Future<void> registerToken(String userId, int companyKey)` | FCM 토큰을 서버에 등록 |
| `Future<void> deactivateToken()` | 서버에 토큰 비활성화 요청 |
| `Future<void> setPushEnabled(bool enabled)` | 알림 ON/OFF 토글 처리 |
| `Future<bool> getPushEnabled()` | 저장된 알림 상태 조회 |

### 4.3 registerToken 로직

```
1. FirebaseMessaging.getToken() → null이면 return (시뮬레이터)
2. Platform.isIOS → "iOS" / "ANDROID"
3. POST /api/LB/fcm/token/access
4. 성공 → _tokenSeq = res (int)
5. 실패 → dev.log만, 앱 동작에 영향 없음
```

### 4.4 onTokenRefresh 수정

```
기존: dev.log만
변경: AuthService().currentUser != null && _pushEnabled이면 registerToken() 호출
```

---

## 5. MyInfoScreen 변경

### 5.1 알림 설정 섹션 추가 위치

`은행 정보` 섹션과 `비밀번호 변경` 버튼 사이에 추가.

### 5.2 UI 구조

```
┌─────────────────────────────┐
│ 알림 설정                     │
│  푸시 알림    [토글 스위치]     │
│  설명 텍스트                  │
└─────────────────────────────┘
```

### 5.3 토글 동작

| 상태 변경 | 동작 |
|----------|------|
| ON → OFF | `FcmService.setPushEnabled(false)` → 서버 비활성화 |
| OFF → ON | `FcmService.setPushEnabled(true)` → 서버 재등록 |

로딩 중일 때 토글 비활성화. 실패 시 토글 원복 + SnackBar 에러 메시지.

---

## 6. AuthService 변경

### 6.1 login() 수정

```dart
// 기존 login() 성공 후 추가
if (result.success) {
  // FCM 토큰 등록 (실패해도 로그인에 영향 없음)
  try {
    final pushEnabled = await FcmService().getPushEnabled();
    if (pushEnabled) {
      await FcmService().registerToken(username, int.parse(currentUser!.companyKey));
    }
  } catch (_) {}
}
```

---

## 7. SecureStorage 키

| 키 | 값 | 용도 |
|----|-----|------|
| `push_enabled` | `"true"` / `"false"` | 알림 ON/OFF 상태 |
| `fcm_token_seq` | `"15"` | 서버 토큰 seq (비활성화용) |

---

## 8. 에러 처리

| 상황 | 처리 |
|------|------|
| FCM 토큰 못 가져옴 (시뮬레이터) | `dev.log`, 서버 등록 스킵 |
| 토큰 등록 API 실패 | `dev.log`, 앱 동작에 영향 없음 |
| 토큰 비활성화 API 실패 | 토글 원복 + SnackBar |
| 네트워크 없음 | 동일하게 try-catch, 앱 크래시 방지 |

---

## 9. Implementation Guide

### 9.1 구현 순서

| 순서 | 작업 | 파일 |
|------|------|------|
| 1 | API 엔드포인트 추가 | `api_config.dart` |
| 2 | GET/PUT 메서드 추가 | `api_service.dart` |
| 3 | 토큰 서버 등록/비활성화 구현 | `fcm_service.dart` |
| 4 | 로그인 후 토큰 등록 연동 | `auth_service.dart` |
| 5 | 알림 ON/OFF 토글 UI | `my_info_screen.dart` |

### 9.2 예상 변경량

- 수정 파일: 5개
- 신규 파일: 0개
- 예상 추가 라인: ~120줄
