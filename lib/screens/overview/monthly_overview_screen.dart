// Design Ref: §5.3.5 — 월별 현황 화면
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../widgets/hyunjang_picker.dart';
import '../../widgets/loading_overlay.dart';
import 'daily_overview_screen.dart';
import 'sync_kongsu_screen.dart';

class MonthlyOverviewScreen extends StatefulWidget {
  const MonthlyOverviewScreen({super.key});

  @override
  State<MonthlyOverviewScreen> createState() => _MonthlyOverviewScreenState();
}

class _MonthlyOverviewScreenState extends State<MonthlyOverviewScreen> {
  final _user = AuthService().currentUser;
  final _numberFormat = NumberFormat('#,###');
  List<Map<String, dynamic>> _hyunjangList = [];
  String? _selectedHyunjangKey;
  String _month = DateFormat('yyyy-MM').format(DateTime.now());
  MonthlyOverview? _overview;
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
            _loadOverview();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadOverview() async {
    if (_selectedHyunjangKey == null) return;
    setState(() => _isLoading = true);
    try {
      _overview = await AttendanceService.readMonthlyOverview(
        companyKey: _user?.companyKey ?? '',
        hyunjangKey: _selectedHyunjangKey!,
        month: _month,
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

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse('$_month-01') ?? now,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) {
      _month = DateFormat('yyyy-MM').format(picked);
      _loadOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('월별 현황'),
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
                        _loadOverview();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: _selectMonth,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_month,
                          style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),

            // 요약
            if (_overview != null) _buildSummaryCard(),

            // 근로자 목록
            Expanded(
              child: _overview == null
                  ? const SizedBox()
                  : RefreshIndicator(
                      onRefresh: _loadOverview,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _overview!.workers.length,
                        itemBuilder: (ctx, i) =>
                            _buildWorkerCard(_overview!.workers[i]),
                      ),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _overview != null
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SyncKongsuScreen(
                          companyKey: _user?.companyKey ?? '',
                          hyunjangKey: _selectedHyunjangKey!,
                          month: _month,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B2E5C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('kongsu 반영'),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildSummaryCard() {
    final s = _overview!.summary;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E5C),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('총 근로자', '${s.totalWorkers}명'),
              _summaryItem('총 공수', '${s.totalKongsu}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryItem('총 금액', '${_numberFormat.format(s.totalAmount)}원'),
              if (s.pendingCheckout > 0)
                _summaryItem('⚠️ 퇴근 미처리', '${s.pendingCheckout}건',
                    color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: color ?? Colors.white70)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color ?? Colors.white,
            )),
      ],
    );
  }

  Widget _buildWorkerCard(WorkerSummary worker) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyOverviewScreen(
            companyKey: _user?.companyKey ?? '',
            hyunjangKey: _selectedHyunjangKey!,
            employeeName: worker.employeeName,
          ),
        ),
      ),
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
                Text(worker.employeeName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                if (worker.pendingCheckout > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('⚠️ ${worker.pendingCheckout}건',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.orange)),
                  ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: worker.syncStatus == 'SYNCED'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    worker.syncStatus == 'SYNCED' ? '반영 완료' : '반영 대기',
                    style: TextStyle(
                      fontSize: 11,
                      color: worker.syncStatus == 'SYNCED'
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${worker.totalDays}일 ${worker.totalKongsu}공수  @${_numberFormat.format(worker.unitPrice)}  ₩${_numberFormat.format(worker.totalAmount)}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
