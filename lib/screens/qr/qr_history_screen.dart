// Design Ref: §5.3.2 — QR 이력 화면 (조회 + 무효화)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/qr_model.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../services/qr_service.dart';
import '../../widgets/hyunjang_picker.dart';

class QrHistoryScreen extends StatefulWidget {
  final String companyKey;

  const QrHistoryScreen({super.key, required this.companyKey});

  @override
  State<QrHistoryScreen> createState() => _QrHistoryScreenState();
}

class _QrHistoryScreenState extends State<QrHistoryScreen> {
  final _user = AuthService().currentUser;
  List<Map<String, dynamic>> _hyunjangList = [];
  String? _selectedHyunjangKey;
  List<QrInfo> _qrList = [];
  bool _isLoading = false;
  String? _filterDate;

  @override
  void initState() {
    super.initState();
    _filterDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadHyunjangList();
    _loadQrList();
  }

  Future<void> _loadHyunjangList() async {
    try {
      final list = await InvoiceService.getHyunjangList(widget.companyKey);
      if (mounted) setState(() => _hyunjangList = list);
    } catch (_) {}
  }

  Future<void> _loadQrList() async {
    setState(() => _isLoading = true);
    try {
      _qrList = await QrService.readQrList(
        companyKey: widget.companyKey,
        hyunjangKey: _selectedHyunjangKey,
        workDate: _filterDate,
        userId: _user?.userId,
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

  Future<void> _invalidateQr(QrInfo qr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR 무효화'),
        content: Text('${qr.hyunjangName}의 ${qr.qrType == 'CHECKIN' ? '출근' : '퇴근'} QR을 무효화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('무효화'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await QrService.invalidateQr(
        seq: qr.seq,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR이 무효화되었습니다.')),
        );
        _loadQrList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_filterDate ?? '') ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      _filterDate = DateFormat('yyyy-MM-dd').format(picked);
      _loadQrList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('QR 이력'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B2E5C),
        elevation: 0,
      ),
      body: Column(
        children: [
          // 필터
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: HyunjangPicker(
                    hyunjangList: _hyunjangList,
                    selectedKey: _selectedHyunjangKey,
                    onSelected: (key, name) {
                      setState(() => _selectedHyunjangKey = key);
                      _loadQrList();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _selectDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_filterDate ?? '전체'),
                  ),
                ),
              ],
            ),
          ),

          // 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _qrList.isEmpty
                    ? Center(
                        child: Text('QR 이력이 없습니다.',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadQrList,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _qrList.length,
                          itemBuilder: (context, index) =>
                              _buildQrCard(_qrList[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(QrInfo qr) {
    final isActive = qr.status == 'ACTIVE' || qr.status == null;
    final statusColor = isActive
        ? Colors.green
        : qr.status == 'EXPIRED'
            ? Colors.red
            : Colors.grey;
    final statusText = isActive
        ? 'ACTIVE'
        : qr.status == 'EXPIRED'
            ? 'EXPIRED'
            : 'INVALIDATED';

    return GestureDetector(
      onTap: isActive ? () => _showQrDialog(qr) : null,
      child: Container(
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${qr.qrType == 'CHECKIN' ? '출근' : '퇴근'} QR',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (isActive)
                TextButton(
                  onPressed: () => _invalidateQr(qr),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('무효화', style: TextStyle(fontSize: 13)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${qr.hyunjangName} · ${qr.createdBy ?? ''}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            '${qr.useCount}/${qr.maxUse}회 · 만료 ${qr.expiredAt}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          if (isActive)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '탭하여 QR 보기',
                style: TextStyle(fontSize: 12, color: Colors.blue.shade400),
              ),
            ),
        ],
      ),
    ),
    );
  }

  void _showQrDialog(QrInfo qr) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                qr.hyunjangName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1B2E5C),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${qr.qrType == 'CHECKIN' ? '출근' : '퇴근'} QR',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              QrImageView(
                data: qr.qrData,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                '${qr.useCount}/${qr.maxUse}회 사용',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                '만료: ${qr.expiredAt}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
