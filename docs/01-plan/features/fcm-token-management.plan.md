# FCM 토큰 관리 기능 Plan

## Executive Summary

| 항목 | 내용 |
|------|------|
| Feature | FCM 토큰 등록/갱신/알림 ON/OFF |
| 작성일 | 2025-05-23 |
| 예상 기간 | 1일 |
| 작업자 | 유종태 |

### Value Delivered

| 관점 | 내용 |
|------|------|
| Problem | FCM 토큰이 서버에 등록되지 않아 서버에서 특정 사용자에게 푸시를 보낼 수 없음 |
| Solution | 로그인 시 자동 토큰 등록, 토큰 갱신 시 자동 재등록, 내정보에서 알림 ON/OFF 제공 |
| Function UX Effect | 사용자는 별도 조작 없이 로그인만으로 푸시 수신 가능, 원하면 내정보에서 끌 수 있음 |
| Core Value | 서버→클라이언트 실시간 알림 채널 확보, 사용자별 알림 제어권 부여 |

## Context Anchor

| Key | Value |
|-----|-------|
| WHY | 서버에서 관리자/직원에게 업무 알림을 보내려면 FCM 토큰이 서버에 등록되어야 함 |
| WHO | 관리자(MANAGER) 앱 사용자 |
| RISK | 시뮬레이터에서 FCM 토큰 못 가져옴 (실기기 필수), 토큰 만료/갱신 누락 |
| SUCCESS | 로그인 후 서버에 토큰 자동 등록됨, 토큰 갱신 시 재등록됨, 알림 ON/OFF 동작 |
| SCOPE | 토큰 등록/갱신/비활성화만. 토큰 관리 화면, 테스트 푸시 발송은 제외 |

---

## 1. 요구사항

### 1.1 핵심 기능

| ID | 기능 | 설명 | 우선순위 |
|----|------|------|----------|
| F-01 | 토큰 서버 등록 | 로그인 성공 시 FCM 토큰을 서버 `POST /api/LB/fcm/token/access`로 등록 | 필수 |
| F-02 | 토큰 자동 갱신 | `onTokenRefresh` 리스너로 토큰 변경 감지 시 서버에 재등록 | 필수 |
| F-03 | 알림 ON/OFF | 내정보 화면에서 푸시 알림 토글, OFF 시 `PUT /api/LB/fcm/token/deactivate` 호출 | 필수 |

### 1.2 API 매핑

| 기능 | Server API | Method |
|------|-----------|--------|
| 토큰 등록/갱신 | `/api/LB/fcm/token/access` | POST |
| 내 토큰 조회 | `/api/LB/fcm/token/read` | GET |
| 토큰 비활성화 | `/api/LB/fcm/token/deactivate` | PUT |

### 1.3 요청 파라미터 (token/access)

| 필드 | 값 | 비고 |
|------|-----|------|
| company_key | `currentUser.companyKey` | 로그인 유저에서 가져옴 |
| user_id | `currentUser.userId` | 로그인 유저에서 가져옴 |
| app_type | `"MANAGER"` | 고정값 (이 앱은 관리자앱) |
| token | FCM 토큰 | `FirebaseMessaging.getToken()` |
| device_id | 디바이스 ID | `flutter_secure_storage`에 생성/저장 |
| device_os | `"ANDROID"` or `"iOS"` | `Platform.isIOS` 기준 |

---

## 2. 구현 범위

### 2.1 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/config/api_config.dart` | FCM 관련 API 엔드포인트 3개 추가 |
| `lib/services/fcm_service.dart` | 토큰 서버 등록/갱신/비활성화 로직 추가 |
| `lib/services/api_service.dart` | GET, PUT 메서드 추가 (현재 POST만 있음) |
| `lib/services/auth_service.dart` | 로그인 성공 후 토큰 등록 호출 |
| `lib/screens/my_info/my_info_screen.dart` | 알림 ON/OFF 토글 UI 추가 |

### 2.2 구현 흐름

```
[로그인 성공]
  → AuthService.login() 성공
  → FcmService.registerToken() 호출
    → FCM 토큰 가져오기
    → POST /api/LB/fcm/token/access
    → 서버에 토큰 seq 저장 (비활성화용)

[토큰 갱신 발생]
  → onTokenRefresh 리스너 감지
  → 로그인 상태면 FcmService.registerToken() 재호출

[내정보 → 알림 OFF]
  → PUT /api/LB/fcm/token/deactivate?seq={저장된 seq}
  → 로컬에 OFF 상태 저장

[내정보 → 알림 ON]
  → FcmService.registerToken() 재호출 (새 토큰 등록)
  → 로컬에 ON 상태 저장
```

---

## 3. 성공 기준

| ID | 기준 | 검증 방법 |
|----|------|----------|
| SC-01 | 로그인 후 서버에 토큰이 등록됨 | 서버 DB 또는 token/read API로 확인 |
| SC-02 | 토큰 갱신 시 서버에 새 토큰으로 재등록됨 | 로그 확인 |
| SC-03 | 내정보에서 알림 OFF → 서버 토큰 비활성화됨 | deactivate API 호출 확인 |
| SC-04 | 내정보에서 알림 ON → 서버에 새 토큰 등록됨 | token/access API 호출 확인 |
| SC-05 | 토큰 등록 실패 시 앱이 크래시하지 않음 | 네트워크 끊김 상태 테스트 |

---

## 4. 리스크

| 리스크 | 영향 | 대응 |
|--------|------|------|
| 시뮬레이터에서 FCM 토큰 못 가져옴 | 개발/테스트 제한 | try-catch로 안전 처리, 실기기 테스트 |
| 토큰 등록 API 실패 | 푸시 수신 불가 | 실패 시 무시 (앱 동작에 영향 없도록), 다음 앱 실행 시 재시도 |
| 로그아웃 없이 앱 삭제 | 비활성 토큰 잔존 | 서버 cleanup API로 관리 (이 앱 범위 밖) |
