// Design Ref: §5.3.6 — 일별 상세 화면 (공수/단가 조정)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_overlay.dart';

class DailyOverviewScreen extends StatefulWidget {
  final String companyKey;
  final String hyunjangKey;
  final String employeeName;

  const DailyOverviewScreen({
    super.key,
    required this.companyKey,
    required this.hyunjangKey,
    required this.employeeName,
  });

  @override
  State<DailyOverviewScreen> createState() => _DailyOverviewScreenState();
}

class _DailyOverviewScreenState extends State<DailyOverviewScreen> {
  final _user = AuthService().currentUser;
  final _numberFormat = NumberFormat('#,###');
  String _workDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  List<DailyAttendance> _attendances = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _attendances = await AttendanceService.readDailyOverview(
        companyKey: widget.companyKey,
        hyunjangKey: widget.hyunjangKey,
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

  // Design Ref: §5.4 — 공수 조정 BottomSheet
  Future<void> _adjustKongsu(DailyAttendance att) async {
    final kongsuController =
        TextEditingController(text: att.workedKongsu?.toString() ?? '1.0');
    final reasonController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('공수 조정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: kongsuController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '공수',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '변경 사유 (필수)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'kongsu': kongsuController.text,
                'reason': reasonController.text,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('조정'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final kongsu = double.tryParse(result['kongsu'] ?? '');
    final reason = result['reason'] ?? '';
    if (kongsu == null || reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공수와 사유를 모두 입력해주세요.')),
        );
      }
      return;
    }

    try {
      await AttendanceService.adjustKongsu(
        seq: att.seq,
        workedKongsu: kongsu,
        changeReason: reason,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공수 조정 완료')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _cancelKongsu(DailyAttendance att) async {
    final reason = await _showReasonDialog('공수 취소', '취소 사유를 입력해주세요.');
    if (reason == null || reason.isEmpty) return;

    try {
      await AttendanceService.cancelKongsu(
        seq: att.seq,
        changeReason: reason,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('공수 취소 완료')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _adjustDanga(DailyAttendance att) async {
    final priceController =
        TextEditingController(text: att.unitPrice?.toString() ?? '');
    final reasonController = TextEditingController();

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('단가 조정',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '단가 (원)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: '변경 사유 (필수)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, {
                'price': priceController.text,
                'reason': reasonController.text,
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('조정'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    final price = int.tryParse(result['price'] ?? '');
    final reason = result['reason'] ?? '';
    if (price == null || reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단가와 사유를 모두 입력해주세요.')),
        );
      }
      return;
    }

    try {
      await AttendanceService.adjustDanga(
        seq: att.seq,
        unitPrice: price,
        changeReason: reason,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단가 조정 완료')),
        );
        _loadData();
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
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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

  Widget _buildGpsIcon(String gpsStatus) {
    switch (gpsStatus) {
      case 'NORMAL':
        return const Icon(Icons.check_circle, size: 14, color: Colors.green);
      case 'OUT_OF_RANGE':
        return const Icon(Icons.warning, size: 14, color: Colors.orange);
      default:
        return const Icon(Icons.gps_off, size: 14, color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: Text('일별 상세 · $_workDate'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B2E5C),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today, size: 20),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(_workDate) ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  _workDate = DateFormat('yyyy-MM-dd').format(picked);
                  _loadData();
                }
              },
            ),
          ],
        ),
        body: _attendances.isEmpty && !_isLoading
            ? Center(
                child: Text('출결 기록이 없습니다.',
                    style: TextStyle(color: Colors.grey.shade500)),
              )
            : RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _attendances.length,
                  itemBuilder: (ctx, i) =>
                      _buildAttendanceCard(_attendances[i]),
                ),
              ),
      ),
    );
  }

  Widget _buildAttendanceCard(DailyAttendance att) {
    final checkinTime = att.checkinDt.length >= 16
        ? att.checkinDt.substring(11, 16)
        : att.checkinDt;
    final checkoutTime = att.checkoutDt != null && att.checkoutDt!.length >= 16
        ? att.checkoutDt!.substring(11, 16)
        : '-';

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
              const Icon(Icons.person, size: 18, color: Color(0xFF1B2E5C)),
              const SizedBox(width: 6),
              Text(att.employeeName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(att.attendanceSource,
                    style:
                        const TextStyle(fontSize: 10, color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$checkinTime→$checkoutTime',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 8),
              if (att.workedHours != null)
                Text('${att.workedHours}h',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              if (att.workedKongsu != null)
                Text('${att.workedKongsu}공수',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (att.unitPrice != null)
                Text('@${_numberFormat.format(att.unitPrice)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(width: 8),
              _buildGpsIcon(att.gpsStatus),
              const SizedBox(width: 4),
              Text(
                att.approveStatus == 'APPROVED'
                    ? '✅승인'
                    : att.approveStatus == 'REJECTED'
                        ? '❌거부'
                        : '⏳대기',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: att.syncStatus == 'SYNCED'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  att.syncStatus == 'SYNCED' ? '반영' : '대기',
                  style: TextStyle(
                    fontSize: 10,
                    color: att.syncStatus == 'SYNCED'
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _actionButton('공수 조정', () => _adjustKongsu(att)),
              const SizedBox(width: 6),
              _actionButton('취소', () => _cancelKongsu(att),
                  color: Colors.red),
              const SizedBox(width: 6),
              _actionButton('단가 조정', () => _adjustDanga(att)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? const Color(0xFF1B2E5C)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, color: color ?? const Color(0xFF1B2E5C))),
      ),
    );
  }
}
