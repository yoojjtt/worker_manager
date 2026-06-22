# daily-qr-attendance Design Document

> **Summary**: 일용직 QR 출결 관리 — Flutter 관리자앱 6개 화면 + 16개 API 연동 설계
>
> **Project**: worker_manager (Flutter)
> **Version**: 1.0.0
> **Author**: 유종태
> **Date**: 2026-06-22
> **Status**: Draft
> **Planning Doc**: [daily-qr-attendance.plan.md](../../01-plan/features/daily-qr-attendance.plan.md)

### Pipeline References

| Phase | Document | Status |
|-------|----------|--------|
| Phase 1 | Schema Definition | N/A (백엔드 완성) |
| Phase 2 | Coding Conventions | ✅ (CLAUDE.md + analysis_options.yaml) |
| Phase 4 | [API Spec](daily-qr-attendance-admin-api.md) | ✅ (외부 Java 프로젝트) |

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

### 1.1 Design Goals

- 기존 프로젝트 패턴(ApiConfig + ApiService.post() + setState) 100% 준수
- 화면별 기능 분리(qr/, attendance/, overview/) + 서비스 2개(QrService, AttendanceService)
- API 스펙의 resultCode별 에러 처리 통일
- GPS 권한 요청/거부 처리 패턴 정립

### 1.2 Design Principles

- 기존 코드 패턴과의 일관성 (새 패턴 도입 최소화)
- 서비스-화면 1:N 관계로 재사용성 확보
- 에러 처리를 서비스 레이어에서 통일

---

## 2. Architecture

### 2.0 Architecture Comparison

| Criteria | Option A: Minimal | Option B: Clean | **Option C: Pragmatic** |
|----------|:-:|:-:|:-:|
| **Approach** | 서비스 1개, 폴더 없이 플랫 | 도메인별 서비스 6개 | **서비스 2개, 폴더 3개** |
| **New Files** | 10 | 20+ | **12** |
| **Modified Files** | 2 | 2 | **2** |
| **Complexity** | Low | High | **Medium** |
| **Maintainability** | Medium | High | **High** |
| **Effort** | Low | High | **Medium** |
| **Risk** | Low (coupled) | Low (clean) | **Low (balanced)** |

**Selected**: Option C: Pragmatic — QR(4 API)와 Attendance(12 API)의 도메인 경계가 명확하고, 기존 프로젝트 규모(24개 dart 파일)에 적합한 분리 수준

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                           │
├──────────┬──────────────────┬───────────────────────────┤
│ screens/ │                  │                           │
│  qr/     │  attendance/     │  overview/                │
│  ├ generate │  ├ approval   │  ├ monthly               │
│  └ history  │  └ manual     │  ├ daily                 │
│             │               │  └ sync                  │
├──────────┴──────────────────┴───────────────────────────┤
│                   services/                              │
│  ┌─────────────┐  ┌────────────────────┐                │
│  │ QrService   │  │ AttendanceService  │                │
│  │ (4 API)     │  │ (12 API)           │                │
│  └──────┬──────┘  └─────────┬──────────┘                │
├─────────┴───────────────────┴───────────────────────────┤
│                   ApiService.post()                      │
│                   ApiConfig (endpoints)                  │
├─────────────────────────────────────────────────────────┤
│                   models/                                │
│  ┌─────────────┐  ┌────────────────────┐                │
│  │ QrModel     │  │ AttendanceModel    │                │
│  └─────────────┘  └────────────────────┘                │
├─────────────────────────────────────────────────────────┤
│  geolocator (GPS)    qr_flutter (QR Image)              │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Java/Spring Backend — https://linkerbiz.net/api/LB     │
│  (16 endpoints, 이미 완성)                               │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow

```
[QR 생성 플로우]
GPS 수집(geolocator) → QR 생성 API → qr_url 수신 → QR 이미지 표시(qr_flutter)

[출근 승인 플로우]
출근 목록 API → GPS 상태 표시 → 승인/거부 API (GPS이상 시 사유 입력)

[공수 반영 플로우]
월별 현황 API → 미반영 건 확인 → syncToKongsu API → 기존 공수 시스템 반영
```

### 2.3 Dependencies

| Component | Depends On | Purpose |
|-----------|-----------|---------|
| qr_generate_screen | QrService, geolocator | QR 생성 + GPS |
| qr_history_screen | QrService | QR 이력 조회/무효화 |
| checkin_approval_screen | AttendanceService | 출근 승인/거부 |
| manual_checkin_screen | AttendanceService | 수기 출근/퇴근/일괄 |
| monthly_overview_screen | AttendanceService | 월별 집계 |
| daily_overview_screen | AttendanceService | 일별 상세 + 공수/단가 조정 |
| sync_kongsu_screen | AttendanceService | kongsu 반영 |

---

## 3. Data Model

### 3.1 QR Models (`lib/models/qr_model.dart`)

```dart
/// QR 생성 응답 모델
class QrInfo {
  final int seq;
  final String qrToken;
  final String qrUrl;
  final String qrType;       // CHECKIN | CHECKOUT
  final String expiredAt;
  final int gpsRadiusM;
  final String hyunjangName;
  final int useCount;
  final int maxUse;
  final String? status;       // ACTIVE | EXPIRED | INVALIDATED
  final String? createdBy;
  final String? createDT;

  QrInfo({...});
  factory QrInfo.fromJson(Map<String, dynamic> json);
}
```

### 3.2 Attendance Models (`lib/models/attendance_model.dart`)

```dart
/// 출근 요청 모델
class CheckinRequest {
  final int seq;
  final int employeeKey;
  final String employeeName;
  final String? employeeCell;
  final String? photoUrl;
  final String checkinDt;
  final String gpsStatus;      // NORMAL | OUT_OF_RANGE | UNAVAILABLE | SUSPICIOUS
  final int? gpsDistanceM;
  final String approveStatus;  // PENDING | APPROVED | REJECTED
  final String attendanceSource; // QR

  CheckinRequest({...});
  factory CheckinRequest.fromJson(Map<String, dynamic> json);
}

/// 일별 출결 상세 모델
class DailyAttendance {
  final int seq;
  final int employeeKey;
  final String employeeName;
  final String? photoUrl;
  final String checkinDt;
  final String? checkoutDt;
  final double? workedHours;
  final double? workedKongsu;
  final int? unitPrice;
  final String gpsStatus;
  final int? gpsDistanceM;
  final String approveStatus;
  final String? approveBy;
  final String attendanceSource;
  final String syncStatus;     // PENDING | SYNCED

  DailyAttendance({...});
  factory DailyAttendance.fromJson(Map<String, dynamic> json);
}

/// 월별 현황 요약
class MonthlyOverview {
  final MonthlySummary summary;
  final List<WorkerSummary> workers;

  MonthlyOverview({...});
  factory MonthlyOverview.fromJson(Map<String, dynamic> json);
}

class MonthlySummary {
  final int totalWorkers;
  final double totalKongsu;
  final int totalAmount;
  final int pendingCheckout;

  MonthlySummary({...});
  factory MonthlySummary.fromJson(Map<String, dynamic> json);
}

class WorkerSummary {
  final int employeeKey;
  final String employeeName;
  final int totalDays;
  final double totalKongsu;
  final int unitPrice;
  final int totalAmount;
  final String syncStatus;
  final int pendingCheckout;

  WorkerSummary({...});
  factory WorkerSummary.fromJson(Map<String, dynamic> json);
}

/// kongsu 미반영 건
class SyncItem {
  final int seq;
  final int employeeKey;
  final String workDate;
  final double workedKongsu;
  final int unitPrice;
  final String syncStatus;

  SyncItem({...});
  factory SyncItem.fromJson(Map<String, dynamic> json);
}
```

### 3.3 Entity Relationships

```
[QrInfo] 1 ──── N [CheckinRequest] (qr_token으로 출근 연결)
   │
[CheckinRequest] → approve → [DailyAttendance]
   │
[DailyAttendance] N ──── 1 [WorkerSummary] (employee_key 집계)
   │
[DailyAttendance] → sync → [SyncItem] → kongsu 반영
```

---

## 4. API Specification

> 모든 API는 POST, 공통 응답: `{ "resultCode": "200", "res": {...} }`

### 4.1 Endpoint List — ApiConfig 추가분

```dart
// QR 관리 (QrService)
static const String qrGenerateCheckin = '/api/LB/qr/generateCheckin';
static const String qrGenerateCheckout = '/api/LB/qr/generateCheckout';
static const String qrReadList = '/api/LB/qr/readQrList';
static const String qrInvalidate = '/api/LB/qr/invalidateQr';

// 출근 승인 (AttendanceService)
static const String attReadCheckinList = '/api/LB/attendance/readCheckinList';
static const String attApproveCheckin = '/api/LB/attendance/approveCheckin';
static const String attRejectCheckin = '/api/LB/attendance/rejectCheckin';

// 수기 등록
static const String attManualCheckin = '/api/LB/attendance/manualCheckin';
static const String attManualCheckout = '/api/LB/attendance/manualCheckout';
static const String attManualBulk = '/api/LB/attendance/manualBulk';

// 공수/단가
static const String attAdjustKongsu = '/api/LB/attendance/adjustKongsu';
static const String attCancelKongsu = '/api/LB/attendance/cancelKongsu';
static const String attAdjustDanga = '/api/LB/attendance/adjustDanga';

// 현황 조회
static const String attMonthlyOverview = '/api/LB/attendance/readMonthlyOverview';
static const String attDailyOverview = '/api/LB/attendance/readDailyOverview';

// kongsu 반영
static const String attReadSyncStatus = '/api/LB/attendance/readSyncStatus';
static const String attSyncToKongsu = '/api/LB/attendance/syncToKongsu';
```

### 4.2 서비스 메서드 시그니처

#### QrService (`lib/services/qr_service.dart`)

```dart
class QrService {
  /// 출근 QR 생성 (GPS 좌표 필수)
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
  });

  /// 퇴근 QR 생성
  static Future<QrInfo> generateCheckout({...}); // 동일 시그니처

  /// QR 이력 조회
  static Future<List<QrInfo>> readQrList({
    required String companyKey,
    String? hyunjangKey,
    String? workDate,
  });

  /// QR 무효화
  static Future<void> invalidateQr({
    required int seq,
    required String userId,
  });
}
```

#### AttendanceService (`lib/services/attendance_service.dart`)

```dart
class AttendanceService {
  // === 출근 승인 ===
  static Future<List<CheckinRequest>> readCheckinList({
    required String companyKey,
    required String hyunjangKey,
    required String workDate,
    required String userId,
  });

  static Future<void> approveCheckin({
    required int seq,
    String? approveReason,  // GPS 이상 시 필수
    required String userId,
  });

  static Future<void> rejectCheckin({
    required int seq,
    required String approveReason,
    required String userId,
  });

  // === 수기 등록 ===
  static Future<int> manualCheckin({
    required String companyKey,
    required String hyunjangKey,
    required String employeeKey,
    required String workDate,
    String? checkinDt,
    required String manualReason,
    required String userId,
  });

  static Future<void> manualCheckout({
    required int seq,
    int? unitPrice,
    required String userId,
  });

  static Future<int> manualBulk({
    required String manualReason,
    required String userId,
    required List<Map<String, dynamic>> items,
  });

  // === 공수/단가 ===
  static Future<void> adjustKongsu({
    required int seq,
    required double workedKongsu,
    required String changeReason,
    required String userId,
  });

  static Future<void> cancelKongsu({
    required int seq,
    required String changeReason,
    required String userId,
  });

  static Future<void> adjustDanga({
    required int seq,
    required int unitPrice,
    required String changeReason,
    required String userId,
  });

  // === 현황 조회 ===
  static Future<MonthlyOverview> readMonthlyOverview({
    required String companyKey,
    required String hyunjangKey,
    required String month,
    required String userId,
  });

  static Future<List<DailyAttendance>> readDailyOverview({
    required String companyKey,
    required String hyunjangKey,
    required String workDate,
    required String userId,
  });

  // === kongsu 반영 ===
  static Future<List<SyncItem>> readSyncStatus({
    required String companyKey,
    required String hyunjangKey,
    required String month,
    required String userId,
  });

  static Future<int> syncToKongsu({
    required String companyKey,
    required String hyunjangKey,
    required String month,
    List<int>? employeeKeys,
    required String userId,
  });
}
```

---

## 5. UI/UX Design

### 5.1 Navigation Flow

```
WorkMenuScreen
  ├── "QR 생성" → QrGenerateScreen
  │                   ├── [QR 생성 완료] → QR 이미지 + 공유
  │                   └── "이력 보기" → QrHistoryScreen
  │                                       └── [무효화]
  ├── "출근 승인"(NEW 메뉴) → CheckinApprovalScreen
  │                              ├── [승인] (GPS이상→사유 다이얼로그)
  │                              └── [거부] (사유 다이얼로그)
  ├── "수기 등록"(NEW 메뉴) → ManualCheckinScreen
  │                              ├── [개별 출근]
  │                              ├── [개별 퇴근]
  │                              └── [일괄 등록]
  └── "현황 관리"(NEW 메뉴) → MonthlyOverviewScreen
                                 ├── [근로자 선택] → DailyOverviewScreen
                                 │                    ├── [공수 조정]
                                 │                    ├── [공수 취소]
                                 │                    └── [단가 조정]
                                 └── "kongsu 반영" → SyncKongsuScreen
```

### 5.2 WorkMenuScreen 변경

기존 4개 메뉴 → 6개 메뉴 (3x2 그리드 유지, 스크롤 가능)

| 기존 | 변경 |
|------|------|
| QR 생성 (placeholder) | QR 생성 → QrGenerateScreen |
| 안전보고서 | 유지 (placeholder) |
| 작업추가 | **출근 승인** → CheckinApprovalScreen |
| 결재요청 | 유지 |
| — | **수기 등록** → ManualCheckinScreen |
| — | **현황 관리** → MonthlyOverviewScreen |

> **참고**: "작업추가"는 현재 placeholder이므로 "출근 승인"으로 교체. 추후 작업추가가 필요하면 메뉴 확장.

### 5.3 Screen Layouts

#### 5.3.1 QR 생성 화면 (QrGenerateScreen)

```
┌────────────────────────────────────┐
│ ← QR 생성                          │
├────────────────────────────────────┤
│                                    │
│  현장 선택: [드롭다운 ▼]            │
│  근무일자: [2026-06-22]             │
│                                    │
│  ─── 설정 (접이식) ───              │
│  허용 반경: [500]m                  │
│  만료 시간: [480]분 (8시간)          │
│  최대 사용: [50]회                   │
│                                    │
│  [출근 QR 생성]  [퇴근 QR 생성]      │
│                                    │
│  ─── 생성 결과 ───                  │
│  ┌──────────────────────┐          │
│  │                      │          │
│  │    ██████████████    │          │
│  │    ██ QR IMAGE ██    │          │
│  │    ██████████████    │          │
│  │                      │          │
│  └──────────────────────┘          │
│  ○○현장 · 출근 QR                   │
│  만료: 16:00 · 0/50회 사용           │
│                                    │
│  [QR 이력 보기]                     │
└────────────────────────────────────┘
```

#### 5.3.2 QR 이력 화면 (QrHistoryScreen)

```
┌────────────────────────────────────┐
│ ← QR 이력                          │
├────────────────────────────────────┤
│ 현장: [전체 ▼]  날짜: [2026-06-22]  │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ 🟢 ACTIVE  출근 QR             │ │
│ │ ○○현장 · admin01               │ │
│ │ 5/50회 · 만료 16:00            │ │
│ │                    [무효화]     │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 🔴 EXPIRED  퇴근 QR            │ │
│ │ ○○현장 · admin01               │ │
│ │ 12/50회 · 만료 17:00           │ │
│ └────────────────────────────────┘ │
└────────────────────────────────────┘
```

#### 5.3.3 출근 승인 화면 (CheckinApprovalScreen)

```
┌────────────────────────────────────┐
│ ← 출근 승인                        │
├────────────────────────────────────┤
│ 현장: [○○현장 ▼]  2026-06-22       │
│ 대기 3건                           │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ 👤 김철수  010-1234-5678       │ │
│ │ 08:02 출근  🟢 120m (정상)     │ │
│ │         [승인]  [거부]          │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 👤 박영희  010-9876-5432       │ │
│ │ 08:15 출근  🟡 1.2km (범위초과) │ │
│ │         [승인]  [거부]          │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 👤 이민수                       │ │
│ │ 08:20 출근  🔴 GPS 거부         │ │
│ │         [승인]  [거부]          │ │
│ └────────────────────────────────┘ │
│                                    │
│  [전체 승인]                        │
└────────────────────────────────────┘
```

#### 5.3.4 수기 등록 화면 (ManualCheckinScreen)

```
┌────────────────────────────────────┐
│ ← 수기 등록                        │
├────────────────────────────────────┤
│ [개별 등록]  [일괄 등록]  ← 탭      │
├────────────────────────────────────┤
│ ─── 개별 등록 탭 ───               │
│                                    │
│  현장: [드롭다운 ▼]                 │
│  근로자: [검색/선택 ▼]              │
│  근무일자: [2026-06-22]             │
│  출근 시간: [08:00] (선택)          │
│  등록 사유: [________________]      │
│            (필수)                   │
│                                    │
│  [출근 등록]                        │
│                                    │
│ ─── 등록된 수기 건 ───             │
│  김철수 08:00 [퇴근 처리]           │
│    └ 단가: [180000]원               │
└────────────────────────────────────┘
```

#### 5.3.5 월별 현황 화면 (MonthlyOverviewScreen)

```
┌────────────────────────────────────┐
│ ← 월별 현황                        │
├────────────────────────────────────┤
│ 현장: [○○현장 ▼]  [2026-06 ▼]      │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ 총 근로자 25명 · 총 공수 320.5  │ │
│ │ 총 금액 57,690,000원            │ │
│ │ ⚠️ 퇴근 미처리 3건              │ │
│ └────────────────────────────────┘ │
│                                    │
│ ┌────────────────────────────────┐ │
│ │ 김철수  15일 14.5공수           │ │
│ │ @180,000  ₩2,610,000  반영대기  │ │
│ └────────────────────────────────┘ │
│ ┌────────────────────────────────┐ │
│ │ 박영희  12일 11.0공수  ⚠️1건   │ │
│ │ @150,000  ₩1,650,000  반영대기  │ │
│ └────────────────────────────────┘ │
│                                    │
│ [kongsu 반영]                      │
└────────────────────────────────────┘
```

#### 5.3.6 일별 상세 화면 (DailyOverviewScreen)

```
┌────────────────────────────────────┐
│ ← 일별 상세  2026-06-22            │
├────────────────────────────────────┤
│ ┌────────────────────────────────┐ │
│ │ 👤 김철수  QR                   │ │
│ │ 08:02→17:05  9.0h  1.13공수    │ │
│ │ @180,000  🟢 정상  ✅승인       │ │
│ │ [공수 조정] [단가 조정] [취소]   │ │
│ └────────────────────────────────┘ │
└────────────────────────────────────┘
```

#### 5.3.7 kongsu 반영 화면 (SyncKongsuScreen)

```
┌────────────────────────────────────┐
│ ← kongsu 반영                      │
├────────────────────────────────────┤
│ 현장: [○○현장 ▼]  [2026-06 ▼]      │
│ 미반영 15건                        │
├────────────────────────────────────┤
│ ☑ 김철수  06-20  1.0공수 @180,000  │
│ ☑ 김철수  06-21  1.0공수 @180,000  │
│ ☑ 박영희  06-20  1.0공수 @150,000  │
│ ...                                │
├────────────────────────────────────┤
│ 선택: 15건  총 공수: 15.0           │
│ [전체 선택]  [선택 반영]             │
└────────────────────────────────────┘
```

### 5.4 Page UI Checklist

#### QrGenerateScreen

- [ ] Dropdown: 현장 선택 (hyunjangRead API 연동)
- [ ] DatePicker: 근무일자 (기본 오늘)
- [ ] TextField: 허용 반경 (기본 500m, ExpansionTile 접이식)
- [ ] TextField: 만료 시간 (기본 480분)
- [ ] TextField: 최대 사용 횟수 (기본 50)
- [ ] Button: "출근 QR 생성" (Primary)
- [ ] Button: "퇴근 QR 생성" (Secondary)
- [ ] QR Image: qr_flutter로 qr_url 렌더링 (200x200)
- [ ] Text: 현장명 + QR 타입 + 만료시간 + 사용횟수 표시
- [ ] Button: "QR 이력 보기" → QrHistoryScreen 이동
- [ ] Loading: GPS 수집 중 인디케이터
- [ ] Error: GPS 권한 거부 시 설정 이동 안내

#### QrHistoryScreen

- [ ] Dropdown: 현장 필터 (전체/특정 현장)
- [ ] DatePicker: 날짜 필터
- [ ] ListView: QR 카드 목록
- [ ] Card: 상태 배지 (ACTIVE=초록, EXPIRED=빨강, INVALIDATED=회색)
- [ ] Card: QR 타입 (CHECKIN/CHECKOUT)
- [ ] Card: 생성자, 사용횟수/최대, 만료시간
- [ ] Button: "무효화" (ACTIVE 상태에서만 표시, 확인 다이얼로그)

#### CheckinApprovalScreen

- [ ] Dropdown: 현장 선택
- [ ] Text: 날짜 + 대기 건수
- [ ] ListView: 출근 요청 카드
- [ ] Card: 근로자 이름, 연락처
- [ ] Card: 출근 시간
- [ ] Card: GPS 상태 아이콘 (🟢NORMAL/🟡OUT_OF_RANGE+거리/🔴UNAVAILABLE/🔴SUSPICIOUS)
- [ ] Card: 사진 썸네일 (photo_url, null이면 기본 아이콘)
- [ ] Button: "승인" → GPS 이상 시 사유 입력 BottomSheet
- [ ] Button: "거부" → 사유 입력 BottomSheet
- [ ] Button: "전체 승인" (NORMAL 건만 일괄, GPS 이상 건은 개별 처리 안내)

#### ManualCheckinScreen

- [ ] TabBar: 개별 등록 / 일괄 등록
- [ ] Dropdown: 현장 선택
- [ ] Dropdown/Search: 근로자 선택
- [ ] DatePicker: 근무일자
- [ ] TimePicker: 출근 시간 (선택)
- [ ] TextField: 등록 사유 (필수, 빈 값 submit 차단)
- [ ] Button: "출근 등록"
- [ ] ListView: 등록된 수기 출근 건 (퇴근 미처리)
- [ ] Button: "퇴근 처리" → 단가 입력 다이얼로그
- [ ] 일괄탭: 근로자 다중 선택 체크박스
- [ ] 일괄탭: 공통 사유 입력
- [ ] 일괄탭: "일괄 등록" 버튼

#### MonthlyOverviewScreen

- [ ] Dropdown: 현장 선택
- [ ] MonthPicker: 월 선택 (YYYY-MM)
- [ ] SummaryCard: 총 근로자, 총 공수, 총 금액, 퇴근 미처리 건
- [ ] ListView: 근로자별 카드
- [ ] Card: 이름, 근무일수, 총 공수, 단가, 총 금액
- [ ] Card: sync_status 배지 (PENDING=노랑 "반영 대기", SYNCED=초록 "반영 완료")
- [ ] Card: pending_checkout > 0 이면 ⚠️ 경고
- [ ] Card: 탭 → DailyOverviewScreen 이동
- [ ] Button: "kongsu 반영" → SyncKongsuScreen 이동

#### DailyOverviewScreen

- [ ] Text: 날짜 헤더
- [ ] ListView: 출결 카드
- [ ] Card: 근로자명, 출퇴근 시간, 근무시간, 공수, 단가
- [ ] Card: GPS 상태 아이콘 + approve_status 배지
- [ ] Card: attendance_source (QR/MANUAL)
- [ ] Card: sync_status 배지
- [ ] Button: "공수 조정" → 공수 입력 + 사유 BottomSheet
- [ ] Button: "공수 취소" → 사유 입력 확인 다이얼로그
- [ ] Button: "단가 조정" → 단가 입력 + 사유 BottomSheet
- [ ] Error: 마감 후 400 에러 시 안내 메시지

#### SyncKongsuScreen

- [ ] Dropdown: 현장 선택
- [ ] MonthPicker: 월 선택
- [ ] Text: 미반영 건수
- [ ] ListView: 미반영 건 목록 (체크박스 선택 가능)
- [ ] CheckboxListTile: 근로자명, 날짜, 공수, 단가
- [ ] Text: 선택 건수 + 총 공수 요약
- [ ] Button: "전체 선택"
- [ ] Button: "선택 반영" → 확인 다이얼로그 → syncToKongsu API

---

## 6. Error Handling

### 6.1 resultCode별 처리 패턴

```dart
// 서비스 레이어 공통 패턴
static Future<T> _handleResponse<T>(
  Map<String, dynamic> response,
  T Function(dynamic res) parser,
) {
  final code = response['resultCode'] as String;
  final res = response['res'];

  switch (code) {
    case '200':
      return parser(res);
    case '400':
      throw ApiException(res.toString()); // 유효성 실패 메시지 그대로 표시
    case '404':
      throw ApiException(res.toString());
    case '410':
      throw ApiException('QR이 만료되었습니다. 다시 생성해주세요.');
    case '429':
      throw ApiException(res.toString());
    default:
      throw ApiException('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
  }
}
```

### 6.2 GPS 권한 처리

```dart
// geolocator 권한 요청 패턴
Future<Position?> getCurrentPosition() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      // 스낵바: "위치 권한이 필요합니다"
      return null;
    }
  }
  if (permission == LocationPermission.deniedForever) {
    // 다이얼로그: "설정에서 위치 권한을 허용해주세요" + 설정 이동 버튼
    await Geolocator.openAppSettings();
    return null;
  }
  return await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );
}
```

### 6.3 UI 에러 표시 패턴

```dart
// 기존 패턴 준수: try-catch + ScaffoldMessenger
try {
  await QrService.generateCheckin(...);
} on ApiException catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(e.message)),
  );
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
  );
}
```

---

## 7. Security Considerations

- [x] GPS 좌표 검증은 서버 측에서 수행 (클라이언트는 좌표 전달만)
- [x] gps_status는 서버가 계산하여 반환 (클라이언트 조작 불가)
- [x] 승인 사유(approve_reason)는 서버에서 GPS이상 시 필수 검증
- [x] 마감 후 수정 차단은 서버에서 처리 (400 반환)
- [ ] QR 토큰은 서버 생성, 클라이언트는 표시만
- [ ] HTTPS 통신 (기존 ApiService 유지)

---

## 8. Test Plan

### 8.1 Test Scope

| Type | Target | Tool | Phase |
|------|--------|------|-------|
| L1: API Tests | 16개 엔드포인트 정상/에러 응답 | ApiService + 수동 검증 | Do |
| L2: UI Tests | 화면별 위젯 렌더링 + 인터랙션 | flutter_test | Do |
| L3: E2E Tests | QR 생성→승인→반영 플로우 | 수동 검증 | Check |

### 8.2 L1: API Test Scenarios

| # | Endpoint | Test Description | Expected |
|---|----------|-----------------|----------|
| 1 | generateCheckin | GPS 좌표 포함 정상 생성 | 200 + QrInfo |
| 2 | generateCheckin | 중복 생성 시도 | 400 + 에러 메시지 |
| 3 | readCheckinList | PENDING 건 목록 조회 | 200 + List |
| 4 | approveCheckin | GPS 이상 + 사유 미입력 | 400 + 에러 메시지 |
| 5 | approveCheckin | GPS 이상 + 사유 입력 | 200 + 승인 |
| 6 | adjustKongsu | 마감 후 조정 시도 | 400 + 에러 메시지 |
| 7 | syncToKongsu | 정상 반영 | 200 + count |

### 8.3 L2: UI Test Scenarios

| # | Screen | Action | Expected |
|---|--------|--------|----------|
| 1 | QrGenerate | 현장 미선택 + 생성 | 유효성 에러 표시 |
| 2 | QrGenerate | GPS 권한 거부 | 설정 이동 안내 |
| 3 | QrGenerate | 정상 생성 | QR 이미지 표시 |
| 4 | CheckinApproval | GPS이상 건 승인 | 사유 입력 BottomSheet |
| 5 | ManualCheckin | 사유 미입력 + 등록 | submit 차단 |
| 6 | DailyOverview | 공수 조정 | 사유 입력 + API 호출 |

### 8.4 L3: E2E Scenarios

| # | Scenario | Steps | Success Criteria |
|---|----------|-------|-----------------|
| 1 | QR→승인 | QR생성 → 출근목록 확인 → 승인 | APPROVED 상태 변경 |
| 2 | 수기→반영 | 수기등록 → 월별현황 → 반영 | kongsu 시스템 반영 |
| 3 | 공수조정 | 일별상세 → 공수조정(사유) → 확인 | 공수 값 변경 |

---

## 9. Clean Architecture — Layer Assignment

| Component | Layer | Location |
|-----------|-------|----------|
| QrGenerateScreen, QrHistoryScreen | Presentation | `lib/screens/qr/` |
| CheckinApprovalScreen | Presentation | `lib/screens/attendance/` |
| ManualCheckinScreen | Presentation | `lib/screens/attendance/` |
| MonthlyOverviewScreen, DailyOverviewScreen | Presentation | `lib/screens/overview/` |
| SyncKongsuScreen | Presentation | `lib/screens/overview/` |
| QrService | Application | `lib/services/qr_service.dart` |
| AttendanceService | Application | `lib/services/attendance_service.dart` |
| QrInfo | Domain | `lib/models/qr_model.dart` |
| CheckinRequest, DailyAttendance, etc. | Domain | `lib/models/attendance_model.dart` |
| ApiConfig (endpoints) | Infrastructure | `lib/config/api_config.dart` |
| ApiService.post() | Infrastructure | `lib/services/api_service.dart` |

---

## 10. Coding Convention Reference

### 10.1 This Feature's Conventions

| Item | Convention Applied |
|------|-------------------|
| File naming | snake_case (`qr_generate_screen.dart`) |
| Class naming | PascalCase (`QrGenerateScreen`) |
| Design Ref | `// Design Ref: §N.N — description` |
| Error handling | try-catch + ApiException + SnackBar |
| State | setState (기존 패턴) |
| Navigation | Navigator.push + MaterialPageRoute |
| API calls | ApiService.post(ApiConfig.endpoint, body) |

---

## 11. Implementation Guide

### 11.1 File Structure

```
lib/
├── config/
│   └── api_config.dart              ← MODIFY: 16개 엔드포인트 추가
├── models/
│   ├── qr_model.dart                ← NEW
│   └── attendance_model.dart        ← NEW
├── services/
│   ├── qr_service.dart              ← NEW
│   └── attendance_service.dart      ← NEW
├── screens/
│   ├── qr/
│   │   ├── qr_generate_screen.dart  ← NEW
│   │   └── qr_history_screen.dart   ← NEW
│   ├── attendance/
│   │   ├── checkin_approval_screen.dart ← NEW
│   │   └── manual_checkin_screen.dart   ← NEW
│   ├── overview/
│   │   ├── monthly_overview_screen.dart ← NEW
│   │   ├── daily_overview_screen.dart   ← NEW
│   │   └── sync_kongsu_screen.dart      ← NEW
│   └── work/
│       └── work_menu_screen.dart    ← MODIFY: 메뉴 연결
```

### 11.2 Implementation Order

1. [ ] 패키지 추가 (geolocator, qr_flutter) + 권한 설정
2. [ ] ApiConfig 엔드포인트 추가 (16개)
3. [ ] 모델 클래스 (qr_model.dart, attendance_model.dart)
4. [ ] QrService (4 API)
5. [ ] AttendanceService (12 API)
6. [ ] QrGenerateScreen + QrHistoryScreen
7. [ ] CheckinApprovalScreen
8. [ ] ManualCheckinScreen
9. [ ] MonthlyOverviewScreen + DailyOverviewScreen
10. [ ] SyncKongsuScreen
11. [ ] WorkMenuScreen 메뉴 연결
12. [ ] 통합 테스트

### 11.3 Session Guide

#### Module Map

| Module | Scope Key | Description | Files |
|--------|-----------|-------------|:-----:|
| 기반 레이어 | `module-1` | 패키지, ApiConfig, 모델, 서비스 | 6 |
| QR 화면 | `module-2` | QrGenerateScreen + QrHistoryScreen | 2 |
| 출근 승인 | `module-3` | CheckinApprovalScreen | 1 |
| 수기 등록 | `module-4` | ManualCheckinScreen | 1 |
| 현황/반영 | `module-5` | MonthlyOverview + DailyOverview + SyncKongsu | 3 |
| 통합 연결 | `module-6` | WorkMenuScreen 수정 + 네비게이션 | 1 |

#### Recommended Session Plan

| Session | Scope | Description | Est. Turns |
|---------|-------|-------------|:----------:|
| Session 1 | `--scope module-1` | 패키지+Config+모델+서비스 (기반) | 30-40 |
| Session 2 | `--scope module-2,module-3` | QR 화면 + 출근 승인 | 40-50 |
| Session 3 | `--scope module-4,module-5` | 수기 등록 + 현황/반영 | 40-50 |
| Session 4 | `--scope module-6` + Check | 메뉴 연결 + Gap 분석 | 20-30 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-06-22 | Initial draft — Option C (Pragmatic) | 유종태 |
