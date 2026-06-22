// Design Ref: §3.2 — 출결/공수/현황 모델

/// 출근 요청 모델 (2-1 readCheckinList)
class CheckinRequest {
  final int seq;
  final int employeeKey;
  final String employeeName;
  final String? employeeCell;
  final String? photoUrl;
  final String checkinDt;
  final String gpsStatus; // NORMAL | OUT_OF_RANGE | UNAVAILABLE | SUSPICIOUS
  final int? gpsDistanceM;
  final String approveStatus; // PENDING | APPROVED | REJECTED
  final String attendanceSource;

  CheckinRequest({
    required this.seq,
    required this.employeeKey,
    required this.employeeName,
    this.employeeCell,
    this.photoUrl,
    required this.checkinDt,
    required this.gpsStatus,
    this.gpsDistanceM,
    required this.approveStatus,
    required this.attendanceSource,
  });

  factory CheckinRequest.fromJson(Map<String, dynamic> json) {
    return CheckinRequest(
      seq: json['seq'] as int? ?? 0,
      employeeKey: json['employee_key'] as int? ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      employeeCell: json['employee_cell'] as String?,
      photoUrl: json['photo_url'] as String?,
      checkinDt: json['checkin_dt'] as String? ?? '',
      gpsStatus: json['gps_status'] as String? ?? 'UNAVAILABLE',
      gpsDistanceM: json['gps_distance_m'] as int?,
      approveStatus: json['approve_status'] as String? ?? 'PENDING',
      attendanceSource: json['attendance_source'] as String? ?? 'QR',
    );
  }

  bool get isGpsNormal => gpsStatus == 'NORMAL';
}

/// 일별 출결 상세 모델 (5-2 readDailyOverview)
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
  final String syncStatus; // PENDING | SYNCED

  DailyAttendance({
    required this.seq,
    required this.employeeKey,
    required this.employeeName,
    this.photoUrl,
    required this.checkinDt,
    this.checkoutDt,
    this.workedHours,
    this.workedKongsu,
    this.unitPrice,
    required this.gpsStatus,
    this.gpsDistanceM,
    required this.approveStatus,
    this.approveBy,
    required this.attendanceSource,
    required this.syncStatus,
  });

  factory DailyAttendance.fromJson(Map<String, dynamic> json) {
    return DailyAttendance(
      seq: json['seq'] as int? ?? 0,
      employeeKey: json['employee_key'] as int? ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      photoUrl: json['photo_url'] as String?,
      checkinDt: json['checkin_dt'] as String? ?? '',
      checkoutDt: json['checkout_dt'] as String?,
      workedHours: (json['worked_hours'] as num?)?.toDouble(),
      workedKongsu: (json['worked_kongsu'] as num?)?.toDouble(),
      unitPrice: json['unit_price'] as int?,
      gpsStatus: json['gps_status'] as String? ?? 'UNAVAILABLE',
      gpsDistanceM: json['gps_distance_m'] as int?,
      approveStatus: json['approve_status'] as String? ?? 'PENDING',
      approveBy: json['approve_by'] as String?,
      attendanceSource: json['attendance_source'] as String? ?? 'QR',
      syncStatus: json['sync_status'] as String? ?? 'PENDING',
    );
  }
}

/// 월별 현황 (5-1 readMonthlyOverview)
class MonthlyOverview {
  final MonthlySummary summary;
  final List<WorkerSummary> workers;

  MonthlyOverview({required this.summary, required this.workers});

  factory MonthlyOverview.fromJson(Map<String, dynamic> json) {
    return MonthlyOverview(
      summary: MonthlySummary.fromJson(json['summary'] as Map<String, dynamic>),
      workers: (json['workers'] as List)
          .map((w) => WorkerSummary.fromJson(w as Map<String, dynamic>))
          .toList(),
    );
  }
}

class MonthlySummary {
  final int totalWorkers;
  final double totalKongsu;
  final int totalAmount;
  final int pendingCheckout;

  MonthlySummary({
    required this.totalWorkers,
    required this.totalKongsu,
    required this.totalAmount,
    required this.pendingCheckout,
  });

  factory MonthlySummary.fromJson(Map<String, dynamic> json) {
    return MonthlySummary(
      totalWorkers: json['total_workers'] as int? ?? 0,
      totalKongsu: (json['total_kongsu'] as num?)?.toDouble() ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      pendingCheckout: json['pending_checkout'] as int? ?? 0,
    );
  }
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

  WorkerSummary({
    required this.employeeKey,
    required this.employeeName,
    required this.totalDays,
    required this.totalKongsu,
    required this.unitPrice,
    required this.totalAmount,
    required this.syncStatus,
    required this.pendingCheckout,
  });

  factory WorkerSummary.fromJson(Map<String, dynamic> json) {
    return WorkerSummary(
      employeeKey: json['employee_key'] as int? ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      totalDays: json['total_days'] as int? ?? 0,
      totalKongsu: (json['total_kongsu'] as num?)?.toDouble() ?? 0,
      unitPrice: json['unit_price'] as int? ?? 0,
      totalAmount: json['total_amount'] as int? ?? 0,
      syncStatus: json['sync_status'] as String? ?? 'PENDING',
      pendingCheckout: json['pending_checkout'] as int? ?? 0,
    );
  }
}

/// kongsu 미반영 건 (6-1 readSyncStatus)
class SyncItem {
  final int seq;
  final int employeeKey;
  final String? employeeName;
  final String workDate;
  final double workedKongsu;
  final int unitPrice;
  final String syncStatus;

  SyncItem({
    required this.seq,
    required this.employeeKey,
    this.employeeName,
    required this.workDate,
    required this.workedKongsu,
    required this.unitPrice,
    required this.syncStatus,
  });

  factory SyncItem.fromJson(Map<String, dynamic> json) {
    return SyncItem(
      seq: json['seq'] as int? ?? 0,
      employeeKey: json['employee_key'] as int? ?? 0,
      employeeName: json['employee_name'] as String?,
      workDate: json['work_date'] as String? ?? '',
      workedKongsu: (json['worked_kongsu'] as num?)?.toDouble() ?? 0,
      unitPrice: json['unit_price'] as int? ?? 0,
      syncStatus: json['sync_status'] as String? ?? 'PENDING',
    );
  }
}

/// 일용직 근로자 (수기 등록용)
class DailyEmployee {
  final int seq;
  final String employeeName;
  final String? employeeCell;

  DailyEmployee({
    required this.seq,
    required this.employeeName,
    this.employeeCell,
  });

  factory DailyEmployee.fromJson(Map<String, dynamic> json) {
    return DailyEmployee(
      seq: json['seq'] as int? ?? 0,
      employeeName: json['employee_name'] as String? ?? '',
      employeeCell: json['employee_cell'] as String?,
    );
  }
}
