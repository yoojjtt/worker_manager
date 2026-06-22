# daily-qr-attendance Planning Document

> **Summary**: 일용직 QR 출결 관리 — QR 생성/승인/수기등록/공수관리/현황조회/반영
>
> **Project**: worker_manager (Flutter)
> **Version**: 1.0.0
> **Author**: 유종태
> **Date**: 2026-06-22
> **Status**: Draft

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 일용직 근로자의 출퇴근을 수기 장부로 관리하여 GPS 검증 불가, 공수 집계 오류, 승인 추적 어려움 |
| **Solution** | QR 코드 + GPS 기반 자동 출결 시스템을 Flutter 관리자앱에 구현. 백엔드 API 16개 완성 상태에서 프론트엔드 6개 화면 개발 |
| **Function/UX Effect** | 관리자가 현장에서 QR 생성 → 근로자 스캔 → GPS 거리 자동 검증 → 승인/거부 → 공수 반영까지 원스톱 처리 |
| **Core Value** | 현장 출결 신뢰성 확보 + 공수 집계 자동화 + 감사 추적 가능한 승인 프로세스 |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 수기 출결 관리의 GPS 검증 부재, 공수 오류, 승인 추적 불가 해결 |
| **WHO** | 건설 현장 관리자 (소장/반장급), 일용직 근로자 |
| **RISK** | GPS 권한 거부 시 출근 처리 불가, QR 만료/무효화 시 현장 혼란 |
| **SUCCESS** | 6개 화면 + 16개 API 연동 완료, QR 생성→출근승인→공수반영 플로우 정상 동작 |
| **SCOPE** | M1: QR 생성/관리, M2: 출근 승인, M3: 수기 등록, M4: 공수/단가, M5: 현황 조회, M6: kongsu 반영 |

---

## 1. Overview

### 1.1 Purpose

건설 현장 일용직 근로자의 출퇴근을 QR 코드 + GPS 위치 기반으로 관리하는 Flutter 관리자앱 화면을 구현한다. 백엔드(Java/Spring) API 16개가 이미 완성되어 있으며, 프론트엔드 구현만 남은 상태이다.

### 1.2 Background

- 기존: 수기 장부 → 공수 수동 입력 → 오류/분쟁 빈발
- 목표: QR 스캔 → GPS 자동 검증 → 관리자 승인 → 공수 자동 집계
- 현재 앱에 `WorkMenuScreen`의 "QR 생성" 메뉴가 플레이스홀더로 존재

### 1.3 Related Documents

- API Spec: `/Users/yujongtae/Dropbox/SOFTWARE/dev_java/LinkerMain/docs/api-spec/daily-qr-attendance-admin-api.md`
- Base URL: `https://linkerbiz.net/api/LB`

---

## 2. Scope

### 2.1 In Scope

- [ ] QR 생성 화면 (출근/퇴근 QR 생성 + GPS 자동 수집 + QR 코드 이미지 표시)
- [ ] QR 관리 화면 (QR 이력 조회 + 무효화)
- [ ] 출근 승인 화면 (대기 목록 → 사진+GPS 확인 → 승인/거부)
- [ ] 수기 등록 화면 (개별 출근/퇴근 + 일괄 등록)
- [ ] 공수/단가 관리 화면 (공수 조정/취소 + 단가 변경, 사유 필수)
- [ ] 현황 조회 화면 (월별 집계 + 일별 상세 + kongsu 반영)
- [ ] API 연동 서비스 레이어 (QrService, AttendanceService)
- [ ] 모델 클래스 (QR, Attendance, MonthlyOverview 등)
- [ ] GPS 위치 수집 (geolocator 패키지)
- [ ] QR 코드 이미지 생성 (qr_flutter 패키지)

### 2.2 Out of Scope

- 근로자 앱 (QR 스캔 측) — 별도 프로젝트
- 백엔드 API 수정 — 이미 완성
- 푸시 알림 연동 (출근 승인 시 근로자에게 알림) — 후속 과제
- 오프라인 모드/캐싱 — 후속 과제

---

## 3. Requirements

### 3.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | 출근/퇴근 QR 생성 (GPS 자동 수집, 반경/만료시간/최대사용 설정) | High | Pending |
| FR-02 | QR 코드 이미지 표시 (qr_flutter로 qr_url 변환) | High | Pending |
| FR-03 | QR 이력 조회 (현장별/날짜별 필터) | High | Pending |
| FR-04 | QR 무효화 (관리자가 수동으로 QR 비활성화) | Medium | Pending |
| FR-05 | 출근 요청 목록 조회 (PENDING 건, GPS 상태 표시) | High | Pending |
| FR-06 | 출근 승인 (GPS 이상 시 사유 필수) | High | Pending |
| FR-07 | 출근 거부 (사유 입력) | High | Pending |
| FR-08 | 수기 출근 등록 (사유 필수, 즉시 APPROVED) | Medium | Pending |
| FR-09 | 수기 퇴근 등록 (단가 선택) | Medium | Pending |
| FR-10 | 수기 일괄 등록 (다수 근로자 동시 처리) | Medium | Pending |
| FR-11 | 공수 조정 (소수점 공수, 사유 필수, 마감 후 차단) | Medium | Pending |
| FR-12 | 공수 취소 (사유 필수) | Medium | Pending |
| FR-13 | 단가 조정 (사유 필수) | Medium | Pending |
| FR-14 | 월별 전체 현황 (근로자별 집계 + 요약) | High | Pending |
| FR-15 | 일별 출결 상세 (개별 출결 정보 + GPS 상태) | High | Pending |
| FR-16 | kongsu 미반영 건 조회 + 일괄 반영 | Medium | Pending |

### 3.2 Non-Functional Requirements

| Category | Criteria | Measurement Method |
|----------|----------|-------------------|
| Performance | API 응답 15초 타임아웃, GPS 수집 10초 이내 | 기존 ApiService 타임아웃 |
| UX | GPS 상태별 색상 구분 (초록/노랑/빨강), 로딩 인디케이터 | UI 검증 |
| Security | GPS 좌표 클라이언트 조작 방지 — 서버 측 거리 계산 의존 | API 스펙 확인 |
| Accessibility | 버튼 최소 44px, 텍스트 최소 14sp | Flutter 위젯 설정 |

---

## 4. Success Criteria

### 4.1 Definition of Done

- [ ] 16개 API 엔드포인트 전체 연동
- [ ] 6개 화면 구현 및 네비게이션 연결
- [ ] GPS 위치 수집 → QR 생성 플로우 동작
- [ ] QR 코드 이미지 표시 정상
- [ ] 출근 승인/거부 플로우 (GPS 이상 시 사유 입력 강제)
- [ ] 수기 등록 (개별/일괄) 동작
- [ ] 공수/단가 조정 (사유 필수, 마감 후 차단 에러 처리)
- [ ] 월별/일별 현황 조회 정상 표시
- [ ] kongsu 반영 플로우 동작
- [ ] 에러 처리 (400/404/410/429/500 resultCode별 메시지 표시)

### 4.2 Quality Criteria

- [ ] flutter analyze 에러 0건
- [ ] 기존 화면(로그인/결재요청 등)에 영향 없음
- [ ] GPS 권한 거부 시 graceful 처리 (안내 메시지)

---

## 5. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| GPS 권한 거부 | High | Medium | 권한 요청 다이얼로그 + 설정 페이지 이동 안내 |
| QR 만료 후 사용 시도 | Medium | High | 410 에러 처리 → "QR을 다시 생성해주세요" 안내 |
| 중복 QR 생성 시도 | Low | Medium | 400 에러 처리 → "이미 생성된 QR이 있습니다" 표시 |
| 마감 후 공수 수정 시도 | Medium | Medium | 400 에러 처리 → "마감 완료된 월은 수정 불가" 표시 |
| 네트워크 불안정 (건설 현장) | High | High | 15초 타임아웃 + 재시도 안내, 수기 등록 대안 제공 |

---

## 6. Impact Analysis

### 6.1 Changed Resources

| Resource | Type | Change Description |
|----------|------|--------------------|
| `ApiConfig` | Config | QR/Attendance 관련 16개 엔드포인트 추가 |
| `WorkMenuScreen` | UI | "QR 생성" 플레이스홀더 → 실제 화면 연결 |
| `pubspec.yaml` | Config | geolocator, qr_flutter 패키지 추가 |
| iOS Info.plist | Config | NSLocationWhenInUseUsageDescription 추가 |
| Android Manifest | Config | ACCESS_FINE_LOCATION 권한 추가 |

### 6.2 Current Consumers

| Resource | Operation | Code Path | Impact |
|----------|-----------|-----------|--------|
| ApiConfig | READ | api_service.dart → post() | None (추가만) |
| WorkMenuScreen | READ | home_screen.dart → _pages[1] | None (네비게이션 변경만) |
| pubspec.yaml | READ | flutter pub get | Needs verification |

### 6.3 Verification

- [ ] 기존 ApiConfig 엔드포인트와 충돌 없음 확인
- [ ] WorkMenuScreen 기존 4개 메뉴 동작 유지 확인
- [ ] 신규 패키지가 기존 빌드에 영향 없음 확인

---

## 7. Architecture Considerations

### 7.1 Project Level Selection

| Level | Characteristics | Recommended For | Selected |
|-------|-----------------|-----------------|:--------:|
| **Starter** | Simple structure | Static sites | ☐ |
| **Dynamic** | Feature-based modules, BaaS integration | Web apps with backend | ☑ |
| **Enterprise** | Strict layer separation, DI | High-traffic systems | ☐ |

### 7.2 Key Architectural Decisions

| Decision | Options | Selected | Rationale |
|----------|---------|----------|-----------|
| Framework | Flutter | Flutter | 기존 프로젝트 |
| State Management | setState / Provider / Riverpod | setState | 기존 패턴 유지, 복잡도 낮음 |
| API Client | http + ApiService | http + ApiService | 기존 패턴 유지 |
| GPS | geolocator / location | geolocator | 사용자 선택, 가장 널리 사용 |
| QR Display | qr_flutter / webview | qr_flutter | 사용자 선택, 네이티브 렌더링 |
| Navigation | Navigator.push | Navigator.push | 기존 패턴 유지 |

### 7.3 Clean Architecture Approach

```
Selected Level: Dynamic

Folder Structure:
┌─────────────────────────────────────────────────────┐
│ lib/                                                │
│   config/api_config.dart          ← 엔드포인트 추가  │
│   models/                                           │
│     qr_model.dart                 ← NEW             │
│     attendance_model.dart         ← NEW             │
│     monthly_overview_model.dart   ← NEW             │
│   services/                                         │
│     qr_service.dart               ← NEW             │
│     attendance_service.dart       ← NEW             │
│   screens/                                          │
│     qr/                           ← NEW             │
│       qr_generate_screen.dart                       │
│       qr_history_screen.dart                        │
│     attendance/                   ← NEW             │
│       checkin_approval_screen.dart                   │
│       manual_checkin_screen.dart                     │
│       manual_bulk_screen.dart                        │
│     kongsu/                       ← NEW             │
│       kongsu_adjust_screen.dart                      │
│       danga_adjust_screen.dart                       │
│     overview/                     ← NEW             │
│       monthly_overview_screen.dart                   │
│       daily_overview_screen.dart                     │
│       sync_kongsu_screen.dart                        │
└─────────────────────────────────────────────────────┘
```

---

## 8. Convention Prerequisites

### 8.1 Existing Project Conventions

- [x] `CLAUDE.md` has coding conventions section
- [x] `analysis_options.yaml` with flutter_lints
- [x] ApiConfig 중앙 엔드포인트 관리 패턴
- [x] ApiService.post() 공통 래퍼 패턴
- [x] Design Ref 주석 컨벤션 (`// Design Ref: §N — description`)

### 8.2 Conventions to Define/Verify

| Category | Current State | To Define | Priority |
|----------|---------------|-----------|:--------:|
| **Naming** | exists (snake_case files, PascalCase classes) | 유지 | - |
| **Folder structure** | exists (screens/, services/, models/) | qr/, attendance/, kongsu/, overview/ 하위 추가 | High |
| **Error handling** | exists (try-catch + Exception) | resultCode별 분기 패턴 정의 | Medium |
| **GPS permission** | missing | geolocator 권한 요청 패턴 정의 | High |

---

## 9. API Endpoint Mapping

> 백엔드 API 16개 엔드포인트 — 모두 POST, Base: `/api/LB`

| # | API | Endpoint | Service |
|---|-----|----------|---------|
| 1-1 | 출근 QR 생성 | `/qr/generateCheckin` | QrService |
| 1-2 | 퇴근 QR 생성 | `/qr/generateCheckout` | QrService |
| 1-3 | QR 이력 조회 | `/qr/readQrList` | QrService |
| 1-4 | QR 무효화 | `/qr/invalidateQr` | QrService |
| 2-1 | 출근 요청 목록 | `/attendance/readCheckinList` | AttendanceService |
| 2-2 | 출근 승인 | `/attendance/approveCheckin` | AttendanceService |
| 2-3 | 출근 거부 | `/attendance/rejectCheckin` | AttendanceService |
| 3-1 | 수기 출근 | `/attendance/manualCheckin` | AttendanceService |
| 3-2 | 수기 퇴근 | `/attendance/manualCheckout` | AttendanceService |
| 3-3 | 수기 일괄 | `/attendance/manualBulk` | AttendanceService |
| 4-1 | 공수 조정 | `/attendance/adjustKongsu` | AttendanceService |
| 4-2 | 공수 취소 | `/attendance/cancelKongsu` | AttendanceService |
| 4-3 | 단가 조정 | `/attendance/adjustDanga` | AttendanceService |
| 5-1 | 월별 현황 | `/attendance/readMonthlyOverview` | AttendanceService |
| 5-2 | 일별 상세 | `/attendance/readDailyOverview` | AttendanceService |
| 6-1 | 미반영 조회 | `/attendance/readSyncStatus` | AttendanceService |
| 6-2 | kongsu 반영 | `/attendance/syncToKongsu` | AttendanceService |

---

## 10. Next Steps

1. [ ] Design 문서 작성 (`daily-qr-attendance.design.md`)
2. [ ] 구현 (모듈별 세션 분리)
3. [ ] Gap 분석 + 보고서

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-06-22 | Initial draft | 유종태 |
