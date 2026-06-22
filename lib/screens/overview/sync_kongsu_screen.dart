// Design Ref: §5.3.7 — kongsu 반영 화면
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/loading_overlay.dart';

class SyncKongsuScreen extends StatefulWidget {
  final String companyKey;
  final String hyunjangKey;
  final String month;

  const SyncKongsuScreen({
    super.key,
    required this.companyKey,
    required this.hyunjangKey,
    required this.month,
  });

  @override
  State<SyncKongsuScreen> createState() => _SyncKongsuScreenState();
}

class _SyncKongsuScreenState extends State<SyncKongsuScreen> {
  final _user = AuthService().currentUser;
  final _numberFormat = NumberFormat('#,###');
  List<SyncItem> _syncItems = [];
  final Set<int> _selectedSeqs = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSyncStatus();
  }

  Future<void> _loadSyncStatus() async {
    setState(() => _isLoading = true);
    try {
      _syncItems = await AttendanceService.readSyncStatus(
        companyKey: widget.companyKey,
        hyunjangKey: widget.hyunjangKey,
        month: widget.month,
        userId: _user?.userId ?? '',
      );
      // 기본 전체 선택
      _selectedSeqs.addAll(_syncItems.map((e) => e.seq));
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

  Future<void> _syncToKongsu() async {
    if (_selectedSeqs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('반영할 건을 선택해주세요.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('kongsu 반영'),
        content: Text('선택한 ${_selectedSeqs.length}건을 kongsu에 반영하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('반영'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      // 선택된 항목의 employee_key 추출 (중복 제거)
      final employeeKeys = _syncItems
          .where((item) => _selectedSeqs.contains(item.seq))
          .map((item) => item.employeeKey)
          .toSet()
          .toList();

      final count = await AttendanceService.syncToKongsu(
        companyKey: widget.companyKey,
        hyunjangKey: widget.hyunjangKey,
        month: widget.month,
        employeeKeys: employeeKeys,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count건 kongsu 반영 완료')),
        );
        Navigator.pop(context);
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

  void _toggleAll() {
    setState(() {
      if (_selectedSeqs.length == _syncItems.length) {
        _selectedSeqs.clear();
      } else {
        _selectedSeqs.addAll(_syncItems.map((e) => e.seq));
      }
    });
  }

  double get _selectedKongsu {
    return _syncItems
        .where((item) => _selectedSeqs.contains(item.seq))
        .fold(0.0, (sum, item) => sum + item.workedKongsu);
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: Text('kongsu 반영 · ${widget.month}'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B2E5C),
          elevation: 0,
        ),
        body: Column(
          children: [
            // 요약
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('미반영 ${_syncItems.length}건',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                      '선택: ${_selectedSeqs.length}건 · 총 공수: ${_selectedKongsu.toStringAsFixed(1)}',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),

            // 전체 선택
            Container(
              color: Colors.white,
              child: CheckboxListTile(
                value: _selectedSeqs.length == _syncItems.length &&
                    _syncItems.isNotEmpty,
                onChanged: (_) => _toggleAll(),
                title: const Text('전체 선택',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                dense: true,
              ),
            ),
            const Divider(height: 1),

            // 목록
            Expanded(
              child: _syncItems.isEmpty && !_isLoading
                  ? Center(
                      child: Text('미반영 건이 없습니다.',
                          style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : ListView.builder(
                      itemCount: _syncItems.length,
                      itemBuilder: (ctx, i) =>
                          _buildSyncItemTile(_syncItems[i]),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _isLoading || _selectedSeqs.isEmpty
                  ? null
                  : _syncToKongsu,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text('선택 반영 (${_selectedSeqs.length}건)'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncItemTile(SyncItem item) {
    return CheckboxListTile(
      value: _selectedSeqs.contains(item.seq),
      onChanged: (v) {
        setState(() {
          if (v == true) {
            _selectedSeqs.add(item.seq);
          } else {
            _selectedSeqs.remove(item.seq);
          }
        });
      },
      title: Text(
        '${item.employeeName ?? ''}  ${item.workDate}',
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${item.workedKongsu}공수  @${_numberFormat.format(item.unitPrice)}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
      dense: true,
    );
  }
}
