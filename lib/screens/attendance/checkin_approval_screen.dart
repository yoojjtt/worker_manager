// Design Ref: §5.3.3 — 출근 승인 화면 (GPS 상태 표시 + 승인/거부)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/api_config.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../widgets/hyunjang_picker.dart';
import '../../widgets/loading_overlay.dart';

class CheckinApprovalScreen extends StatefulWidget {
  const CheckinApprovalScreen({super.key});

  @override
  State<CheckinApprovalScreen> createState() => _CheckinApprovalScreenState();
}

class _CheckinApprovalScreenState extends State<CheckinApprovalScreen> {
  final _user = AuthService().currentUser;
  List<Map<String, dynamic>> _hyunjangList = [];
  String? _selectedHyunjangKey;
  final String _workDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<CheckinRequest> _checkinList = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHyunjangList();
  }

  Future<void> _loadHyunjangList() async {
    try {
      final list = await InvoiceService.getHyunjangList(
          _user?.companyKey ?? '');
      if (mounted) {
        setState(() {
          _hyunjangList = list;
          if (_hyunjangList.isNotEmpty) {
            _selectedHyunjangKey =
                _hyunjangList[0]['seq'].toString();
            _loadCheckinList();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCheckinList() async {
    if (_selectedHyunjangKey == null) return;
    setState(() => _isLoading = true);
    try {
      _checkinList = await AttendanceService.readCheckinList(
        companyKey: _user?.companyKey ?? '',
        hyunjangKey: _selectedHyunjangKey!,
        workDate: _workDate,
        userId: _user?.userId ?? '',
      );
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

  Future<void> _approve(CheckinRequest item) async {
    // Plan SC: GPS 이상 시 사유 입력 강제
    if (!item.isGpsNormal) {
      final reason = await _showReasonDialog('승인 사유', 'GPS 이상 건은 승인 사유를 입력해야 합니다.');
      if (reason == null || reason.isEmpty) return;
      await _doApprove(item.seq, reason);
    } else {
      await _doApprove(item.seq, null);
    }
  }

  Future<void> _doApprove(int seq, String? reason) async {
    try {
      await AttendanceService.approveCheckin(
        seq: seq,
        approveReason: reason,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('승인 완료')),
        );
        _loadCheckinList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _reject(CheckinRequest item) async {
    final reason = await _showReasonDialog('거부 사유', '거부 사유를 입력해주세요.');
    if (reason == null || reason.isEmpty) return;

    try {
      await AttendanceService.rejectCheckin(
        seq: item.seq,
        approveReason: reason,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('거부 완료')),
        );
        _loadCheckinList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<String?> _showReasonDialog(String title, String hint) async {
    final controller = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('확인'),
            ),
          ],
        ),
      ),
    );
  }

  // Design Ref: §5.4 — GPS 상태별 아이콘
  Widget _buildGpsStatus(CheckinRequest item) {
    final IconData icon;
    final Color color;
    final String text;

    switch (item.gpsStatus) {
      case 'NORMAL':
        icon = Icons.check_circle;
        color = Colors.green;
        text = '${item.gpsDistanceM ?? 0}m (정상)';
      case 'OUT_OF_RANGE':
        icon = Icons.warning;
        color = Colors.orange;
        final dist = item.gpsDistanceM ?? 0;
        text = dist >= 1000
            ? '${(dist / 1000).toStringAsFixed(1)}km (범위초과)'
            : '${dist}m (범위초과)';
      case 'SUSPICIOUS':
        icon = Icons.error;
        color = Colors.red;
        text = '위치 이상';
      default: // UNAVAILABLE
        icon = Icons.gps_off;
        color = Colors.red;
        text = 'GPS 거부';
    }

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        _checkinList.where((c) => c.approveStatus == 'PENDING').length;

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('출근 승인'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B2E5C),
          elevation: 0,
        ),
        body: Column(
          children: [
            // 필터
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: HyunjangPicker(
                      hyunjangList: _hyunjangList,
                      selectedKey: _selectedHyunjangKey,
                      onSelected: (key, name) {
                        setState(() => _selectedHyunjangKey = key);
                        _loadCheckinList();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('대기 $pendingCount건',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            // 목록
            Expanded(
              child: _checkinList.isEmpty && !_isLoading
                  ? Center(
                      child: Text('출근 요청이 없습니다.',
                          style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadCheckinList,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _checkinList.length,
                        itemBuilder: (ctx, i) =>
                            _buildCheckinCard(_checkinList[i]),
                      ),
                    ),
            ),

            // 전체 승인 버튼
            if (_checkinList.any((c) => c.approveStatus == 'PENDING'))
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _approveAllNormal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2E5C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('전체 승인 (정상 GPS만)'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveAllNormal() async {
    final normalPending = _checkinList
        .where((c) => c.approveStatus == 'PENDING' && c.isGpsNormal)
        .toList();
    final abnormalPending = _checkinList
        .where((c) => c.approveStatus == 'PENDING' && !c.isGpsNormal)
        .toList();

    if (normalPending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('일괄 승인 가능한 정상 GPS 건이 없습니다.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      for (final item in normalPending) {
        await AttendanceService.approveCheckin(
          seq: item.seq,
          userId: _user?.userId ?? '',
        );
      }
      if (mounted) {
        var msg = '${normalPending.length}건 일괄 승인 완료';
        if (abnormalPending.isNotEmpty) {
          msg += ' (GPS 이상 ${abnormalPending.length}건은 개별 처리 필요)';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        _loadCheckinList();
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

  Widget _buildCheckinCard(CheckinRequest item) {
    final isPending = item.approveStatus == 'PENDING';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Row(
            children: [
              // 사진 썸네일
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: item.photoUrl != null
                    ? Image.network(
                        '${ApiConfig.baseUrl}${item.photoUrl}',
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 40,
                          height: 40,
                          color: const Color(0xFF1B2E5C).withValues(alpha: 0.1),
                          child: const Icon(Icons.person,
                              size: 20, color: Color(0xFF1B2E5C)),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        color: const Color(0xFF1B2E5C).withValues(alpha: 0.1),
                        child: const Icon(Icons.person,
                            size: 20, color: Color(0xFF1B2E5C)),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.employeeName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    if (item.employeeCell != null)
                      Text(item.employeeCell!,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${item.checkinDt.substring(11, 16)} 출근',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(width: 12),
              _buildGpsStatus(item),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => _reject(item),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('거부'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approve(item),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B2E5C),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  ),
                  child: const Text('승인'),
                ),
              ],
            ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                item.approveStatus == 'APPROVED' ? '✅ 승인됨' : '❌ 거부됨',
                style: TextStyle(
                  fontSize: 13,
                  color: item.approveStatus == 'APPROVED'
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
