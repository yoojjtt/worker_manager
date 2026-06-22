// Design Ref: §5.3.1 — QR 생성 화면 (출근/퇴근 QR + GPS 자동 수집)
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/qr_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/hyunjang_picker.dart';
import '../../services/invoice_service.dart';
import '../../services/qr_service.dart';
import '../../widgets/loading_overlay.dart';
import '../qr/qr_history_screen.dart';

class QrGenerateScreen extends StatefulWidget {
  const QrGenerateScreen({super.key});

  @override
  State<QrGenerateScreen> createState() => _QrGenerateScreenState();
}

class _QrGenerateScreenState extends State<QrGenerateScreen> {
  final _user = AuthService().currentUser;
  List<Map<String, dynamic>> _hyunjangList = [];
  String? _selectedHyunjangKey;
  DateTime _workDate = DateTime.now();

  int _gpsRadiusM = 500;
  int _expiredMinutes = 480;
  int _maxUse = 50;
  bool _showSettings = false;

  QrInfo? _generatedQr;
  bool _isLoading = false;
  bool _isGpsLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHyunjangList();
  }

  Future<void> _loadHyunjangList() async {
    try {
      final list = await InvoiceService.getHyunjangList(
        _user?.companyKey ?? '',
      );
      if (mounted) {
        setState(() {
          _hyunjangList = list;
          if (_hyunjangList.isNotEmpty) {
            _selectedHyunjangKey = _hyunjangList[0]['seq'].toString();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('현장 목록 로드 실패: $e')));
      }
    }
  }

  // Design Ref: §6.2 — GPS 권한 처리
  Future<Position?> _getCurrentPosition() async {
    setState(() => _isGpsLoading = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
          }
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showLocationSettingsDialog();
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('GPS 수집 실패: $e')));
      }
      return null;
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text('QR 생성을 위해 설정에서 위치 권한을 허용해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openAppSettings();
            },
            child: const Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateQr(String type) async {
    if (_selectedHyunjangKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('현장을 선택해주세요.')));
      return;
    }

    final position = await _getCurrentPosition();
    if (position == null) return;

    setState(() => _isLoading = true);
    try {
      final workDateStr = DateFormat('yyyy-MM-dd').format(_workDate);
      final generateFn = type == 'CHECKIN'
          ? QrService.generateCheckin
          : QrService.generateCheckout;

      final qr = await generateFn(
        companyKey: _user?.companyKey ?? '',
        hyunjangKey: _selectedHyunjangKey!,
        workDate: workDateStr,
        gpsLat: position.latitude,
        gpsLng: position.longitude,
        gpsRadiusM: _gpsRadiusM,
        expiredMinutes: _expiredMinutes,
        maxUse: _maxUse,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        setState(() => _generatedQr = qr);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type == 'CHECKIN' ? '출근' : '퇴근'} QR이 생성되었습니다.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _workDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _workDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading || _isGpsLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('QR 생성'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B2E5C),
          elevation: 0,
          actions: [
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      QrHistoryScreen(companyKey: _user?.companyKey ?? ''),
                ),
              ),
              child: const Text('이력 보기'),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCard([
                HyunjangPicker(
                  hyunjangList: _hyunjangList,
                  selectedKey: _selectedHyunjangKey,
                  onSelected: (key, name) {
                    setState(() => _selectedHyunjangKey = key);
                  },
                  label: '현장 선택',
                ),
                const SizedBox(height: 12),
                const Text(
                  '근무일자',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(DateFormat('yyyy-MM-dd').format(_workDate)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // 설정 (접이식)
              _buildCard([
                InkWell(
                  onTap: () => setState(() => _showSettings = !_showSettings),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '설정',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _showSettings ? Icons.expand_less : Icons.expand_more,
                      ),
                    ],
                  ),
                ),
                if (_showSettings) ...[
                  const SizedBox(height: 12),
                  _buildNumberField(
                    '허용 반경 (m)',
                    _gpsRadiusM,
                    (v) => _gpsRadiusM = v,
                  ),
                  const SizedBox(height: 8),
                  _buildNumberField(
                    '만료 시간 (분)',
                    _expiredMinutes,
                    (v) => _expiredMinutes = v,
                  ),
                  const SizedBox(height: 8),
                  _buildNumberField('최대 사용 횟수', _maxUse, (v) => _maxUse = v),
                ],
              ]),
              const SizedBox(height: 16),

              // 생성 버튼
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _generateQr('CHECKIN'),
                      icon: const Icon(Icons.login),
                      label: const Text('출근 QR 생성'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B2E5C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () => _generateQr('CHECKOUT'),
                      icon: const Icon(Icons.logout),
                      label: const Text('퇴근 QR 생성'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B2E5C),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_generatedQr != null) _buildQrResult(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrResult() {
    final qr = _generatedQr!;
    return _buildCard([
      Center(
        child: QrImageView(
          data: qr.qrData,
          version: QrVersions.auto,
          size: 200,
          backgroundColor: Colors.white,
        ),
      ),
      const SizedBox(height: 12),
      Center(
        child: Text(
          '${qr.hyunjangName} · ${qr.qrType == 'CHECKIN' ? '출근' : '퇴근'} QR',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1B2E5C),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          '만료: ${qr.expiredAt} · ${qr.useCount}/${qr.maxUse}회 사용',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
      ),
    ]);
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // _buildHyunjangDropdown 제거 — HyunjangPicker로 대체

  Widget _buildNumberField(
    String label,
    int value,
    void Function(int) onChanged,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Expanded(
          child: TextFormField(
            initialValue: value.toString(),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null) onChanged(parsed);
            },
          ),
        ),
      ],
    );
  }
}
