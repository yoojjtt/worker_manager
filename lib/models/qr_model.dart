// Design Ref: §3.1 — QR 생성/이력 모델
class QrInfo {
  final int seq;
  final String qrToken;
  final String qrUrl;
  final String qrType; // CHECKIN | CHECKOUT
  final String expiredAt;
  final int gpsRadiusM;
  final String hyunjangName;
  final int useCount;
  final int maxUse;
  final String? status; // ACTIVE | EXPIRED | INVALIDATED
  final String? createdBy;
  final String? createDT;

  QrInfo({
    required this.seq,
    required this.qrToken,
    required this.qrUrl,
    required this.qrType,
    required this.expiredAt,
    required this.gpsRadiusM,
    required this.hyunjangName,
    required this.useCount,
    required this.maxUse,
    this.status,
    this.createdBy,
    this.createDT,
  });

  /// QR 이미지에 사용할 데이터 — qr_url 우선, 없으면 qr_token으로 URL 생성
  String get qrData {
    if (qrUrl.isNotEmpty) return qrUrl;
    if (qrToken.isNotEmpty) return 'https://worker-qr.linkerbiz.net/$qrToken';
    return '';
  }

  factory QrInfo.fromJson(Map<String, dynamic> json) {
    return QrInfo(
      seq: json['seq'] as int? ?? 0,
      qrToken: json['qr_token'] as String? ?? '',
      qrUrl: json['qr_url'] as String? ?? '',
      qrType: json['qr_type'] as String? ?? 'CHECKIN',
      expiredAt: json['expired_at'] as String? ?? '',
      gpsRadiusM: json['gps_radius_m'] as int? ?? 500,
      hyunjangName: json['hyunjang_name'] as String? ?? '',
      useCount: json['use_count'] as int? ?? 0,
      maxUse: json['max_use'] as int? ?? 50,
      status: json['status'] as String?,
      createdBy: json['created_by'] as String?,
      createDT: json['create_DT'] as String?,
    );
  }
}
