# 업무관리 메뉴 + 결재요청 Design

## Context Anchor

| Key | Value |
|-----|-------|
| WHY | 현장에서 발생하는 지급서를 모바일로 즉시 처리하고 결재 프로세스를 진행해야 함 |
| WHO | 관리자(MANAGER) 앱 사용자 |
| RISK | OCR 파싱 정확도, 대용량 이미지 업로드 시간, 네트워크 불안정 |
| SUCCESS | 사진→OCR→수정→저장→결재요청 플로우 완성, 결재 목록 조회 가능 |
| SCOPE | 하단 3탭, 업무관리 메뉴(4개), 결재요청 CRUD+목록. QR/안전보고서/작업추가는 placeholder |

---

## 1. Overview

기존 2탭(홈/내정보) BottomNavigationBar를 3탭(홈/업무관리/내정보)으로 확장하고, 업무관리 화면에 4개 메뉴 그리드를 구성한다. 결재요청은 사진→OCR→폼수정→저장→결재요청 플로우를 구현하며, 목록 조회도 포함한다.

---

## 2. 파일 구조

### 2.1 신규 파일

```
lib/
├── screens/
│   ├── work/
│   │   ├── work_menu_screen.dart          # 업무관리 메뉴 그리드
│   │   ├── approval_list_screen.dart      # 결재요청 목록
│   │   ├── approval_form_screen.dart      # 결재요청 작성/수정 폼
│   │   └── approval_detail_screen.dart    # 결재 상세 보기
│   └── placeholder_screen.dart            # QR/안전보고서/작업추가 공통 placeholder
├── services/
│   └── invoice_service.dart               # 지급서/결재 API 서비스
└── models/
    └── invoice_model.dart                 # 지급서 데이터 모델
```

### 2.2 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `lib/screens/home_screen.dart` | 2탭→3탭, 업무관리 탭 추가 |
| `lib/config/api_config.dart` | 지급서/결재/현장/계정과목/거래처 API 엔드포인트 추가 |
| `lib/services/api_service.dart` | multipart 파일 업로드 메서드 추가 |
| `pubspec.yaml` | `image_picker` 패키지 추가 |

---

## 3. API 엔드포인트

### 3.1 ApiConfig 추가

```dart
// 지급서 OCR + CRUD
static const String invoiceParse = '/api/vision/invoice/parse';
static const String invoiceSave = '/api/vision/invoice/save';
static const String invoiceUpdate = '/api/vision/invoice/update';
static const String invoiceDetail = '/api/vision/invoice/detail';
static const String invoiceList = '/api/vision/invoice/list';
static const String invoiceDelete = '/api/vision/invoice/delete';

// 결재 프로세스
static const String invoiceRequest = '/api/vision/invoice/request';
static const String invoiceApprovalHistory = '/api/vision/invoice/approvalHistory';

// 드롭다운 데이터
static const String hyunjangRead = '/api/LB/hyunjang/hyunjangRead';
static const String accountCategoryAll = '/api/LB/accounting/category/all';
static const String partnerFindAll = '/api/LB/accounting/partner/findAll';
```

### 3.2 ApiService 추가 메서드

```dart
// multipart 파일 업로드
static Future<Map<String, dynamic>> uploadFile(
  String endpoint,
  File file, {
  Map<String, String>? fields,
})
```

---

## 4. 데이터 모델

### 4.1 InvoiceModel

```dart
class InvoiceModel {
  final int? seq;
  final String? companyKey;
  final String? hyunjangKey;
  final String? hyunjangName;
  final String? invoiceMonth;
  final String? vendorName;
  final String? accountBank;
  final String? accountNumber;
  final String? accountHolder;
  final int? totalSupply;
  final int? totalVat;
  final int? totalAmount;
  final String? imagePath;
  final String? docType;
  final String? title;
  final int? accountCategorySeq;
  final String? accountCategoryName;
  final int? partnerSeq;
  final String? paymentMethod;
  final String? transactionDate;
  final String? status;
  final String? requestedBy;
  final String? requestedDT;
  final String? createDT;
  final List<InvoiceItemModel>? items;
}

class InvoiceItemModel {
  final int? seq;
  final int? itemNo;
  final String? itemName;
  final int? supplyAmount;
  final int? vatAmount;
  final int? totalAmount;
}
```

---

## 5. 화면 상세

### 5.1 HomeScreen 변경 — 3탭 메뉴

```dart
// 기존 2탭 → 3탭
final _pages = const [
  _HomePlaceholder(),    // 홈
  WorkMenuScreen(),       // 업무관리 (신규)
  MyInfoScreen(),         // 내정보
];

// BottomNavigationBar items 추가
BottomNavigationBarItem(
  icon: Icon(Icons.assignment_outlined),
  activeIcon: Icon(Icons.assignment),
  label: '업무관리',
),
```

### 5.2 WorkMenuScreen — 업무관리 메뉴 그리드

2x2 그리드 레이아웃:

| 메뉴 | 아이콘 | 동작 |
|------|--------|------|
| QR생성 | `Icons.qr_code` | PlaceholderScreen 이동 |
| 안전보고서 | `Icons.health_and_safety` | PlaceholderScreen 이동 |
| 작업추가 | `Icons.add_task` | PlaceholderScreen 이동 |
| 결재요청 | `Icons.receipt_long` | ApprovalListScreen 이동 |

### 5.3 ApprovalListScreen — 결재요청 목록

- 상단: 상태 필터 칩 (전체/요청중/승인/반려)
- 리스트: 거래처명, 금액, 상태 배지, 날짜
- FAB(+): 신규 결재요청 작성
- 페이징: 무한 스크롤
- 당겨서 새로고침

### 5.4 ApprovalFormScreen — 결재요청 작성/수정

**플로우:**
1. 진입 시 사진 선택 다이얼로그 (카메라/갤러리)
2. 이미지 선택 → OCR 파싱 로딩
3. 파싱 결과로 폼 자동 채움
4. 사용자 수정:
   - 현장 드롭다운 (`hyunjangRead`)
   - 계정과목 드롭다운 (`accountCategoryAll`)
   - 거래처 드롭다운 (`partnerFindAll`)
   - 거래처명, 은행/계좌/예금주 (텍스트)
   - 공급가액, 부가세, 합계 (숫자)
   - 항목 리스트 (추가/삭제 가능)
   - 제목/적요 (텍스트)
   - 문서유형 드롭다운 (EXPENSE_REQUEST/EXPENSE_STATEMENT/TAX_INVOICE)
   - 결제수단 드롭다운 (CASH/CARD/TRANSFER)
   - 거래일자 (DatePicker)
5. 저장 버튼 → `invoice/save` → DRAFT
6. 결재요청 버튼 → `invoice/request` → REQUESTED

**수정 모드:** seq가 있으면 `invoice/detail`로 기존 데이터 로드

### 5.5 ApprovalDetailScreen — 상세 보기

- 지급서 정보 표시 (읽기 전용)
- OCR 이미지 표시
- 상태 배지
- 결재 이력 타임라인 (`approvalHistory`)
- 하단 버튼: 수정 (DRAFT일 때) / 결재요청 (DRAFT/CONFIRMED일 때)

### 5.6 PlaceholderScreen — 공통 Placeholder

```dart
PlaceholderScreen(title: 'QR 생성', icon: Icons.qr_code)
```

---

## 6. InvoiceService

```dart
class InvoiceService {
  // OCR 파싱
  static Future<Map<String, dynamic>> parseInvoice(File imageFile, String companyKey)
  
  // CRUD
  static Future<Map<String, dynamic>> saveInvoice(Map<String, dynamic> data)
  static Future<Map<String, dynamic>> updateInvoice(Map<String, dynamic> data)
  static Future<Map<String, dynamic>> getDetail(String seq)
  static Future<Map<String, dynamic>> getList({...})
  static Future<Map<String, dynamic>> deleteInvoice(String seq, String deleteId)
  
  // 결재
  static Future<Map<String, dynamic>> requestApproval({...})
  static Future<List<dynamic>> getApprovalHistory(String invoiceKey)
  
  // 드롭다운 데이터
  static Future<List<Map<String, dynamic>>> getHyunjangList(String companyKey)
  static Future<List<Map<String, dynamic>>> getAccountCategories(String companyKey)
  static Future<List<Map<String, dynamic>>> getPartners(String companyKey)
}
```

---

## 7. 에러 처리

| 상황 | 처리 |
|------|------|
| OCR 파싱 실패 | 에러 메시지 + 빈 폼으로 수동 입력 가능 |
| 이미지 업로드 실패 | SnackBar + 재시도 |
| 드롭다운 데이터 로드 실패 | 빈 드롭다운 + SnackBar |
| 저장/결재요청 실패 | SnackBar + 데이터 유지 |
| 네트워크 없음 | 각 API 호출에서 try-catch |

---

## 8. 상태 표시 색상

| 상태 | 색상 | 텍스트 |
|------|------|--------|
| DRAFT | Grey | 임시저장 |
| CONFIRMED | Blue | 확인완료 |
| REQUESTED | Orange | 결재요청 |
| APPROVED | Green | 승인 |
| REJECTED | Red | 반려 |
| PAID | Purple | 지급완료 |

---

## 9. Implementation Guide

### 9.1 구현 순서

| 순서 | 모듈 | 파일 | 예상 라인 |
|------|------|------|----------|
| 1 | API 설정 | `api_config.dart`, `api_service.dart` | ~30 |
| 2 | 데이터 모델 | `invoice_model.dart` | ~80 |
| 3 | 서비스 | `invoice_service.dart` | ~120 |
| 4 | 하단 메뉴 3탭 | `home_screen.dart` | ~20 |
| 5 | 업무관리 메뉴 | `work_menu_screen.dart` | ~100 |
| 6 | Placeholder | `placeholder_screen.dart` | ~30 |
| 7 | 결재 목록 | `approval_list_screen.dart` | ~200 |
| 8 | 결재 작성 폼 | `approval_form_screen.dart` | ~400 |
| 9 | 결재 상세 | `approval_detail_screen.dart` | ~200 |
| 10 | 패키지 추가 | `pubspec.yaml` | ~1 |

### 9.2 예상 변경량

- 신규 파일: 7개
- 수정 파일: 4개
- 예상 추가 라인: ~1,200줄

### 9.3 Session Guide

| 세션 | 모듈 | 내용 |
|------|------|------|
| Session 1 | 1~6 | API+모델+서비스+메뉴 구조 |
| Session 2 | 7~9 | 결재 화면 (목록+폼+상세) |
