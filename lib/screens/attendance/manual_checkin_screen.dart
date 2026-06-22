// Design Ref: §5.3.4 — 수기 등록 화면 (개별/일괄)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../widgets/hyunjang_picker.dart';
import '../../widgets/loading_overlay.dart';

class ManualCheckinScreen extends StatefulWidget {
  const ManualCheckinScreen({super.key});

  @override
  State<ManualCheckinScreen> createState() => _ManualCheckinScreenState();
}

class _ManualCheckinScreenState extends State<ManualCheckinScreen>
    with SingleTickerProviderStateMixin {
  final _user = AuthService().currentUser;
  late TabController _tabController;

  List<Map<String, dynamic>> _hyunjangList = [];
  String? _selectedHyunjangKey;
  List<DailyEmployee> _employees = [];

  // 개별 등록
  String? _selectedEmployeeKey;
  String _workDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final _reasonController = TextEditingController();
  TimeOfDay? _checkinTime;
  List<CheckinRequest> _manualCheckins = [];

  // 일괄 등록
  final Set<int> _selectedEmployeeKeys = {};
  final _bulkReasonController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHyunjangList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reasonController.dispose();
    _bulkReasonController.dispose();
    super.dispose();
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
            _loadEmployees();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    if (_selectedHyunjangKey == null) return;
    try {
      _employees = await AttendanceService.readEmployeeList(
        companyKey: _user?.companyKey ?? '',
        hyunjangKey: _selectedHyunjangKey!,
      );
      if (mounted) setState(() {});
      _loadManualCheckins();
    } catch (_) {}
  }

  Future<void> _loadManualCheckins() async {
    if (_selectedHyunjangKey == null) return;
    try {
      final list = await AttendanceService.readCheckinList(
        companyKey: _user?.companyKey ?? '',
        hyunjangKey: _selectedHyunjangKey!,
        workDate: _workDate,
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        setState(() {
          // 수기 등록 건 중 퇴근 미처리 건 필터
          _manualCheckins = list
              .where((c) => c.attendanceSource == 'MANUAL' ||
                  c.approveStatus == 'APPROVED')
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _handleCheckout(CheckinRequest item) async {
    final priceController = TextEditingController();
    final result = await showModalBottomSheet<String>(
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
            const Text('퇴근 처리',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('${item.employeeName} · ${item.checkinDt}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '단가 (원, 선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, priceController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
              ),
              child: const Text('퇴근 처리'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    try {
      await AttendanceService.manualCheckout(
        seq: item.seq,
        unitPrice: int.tryParse(result),
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퇴근 처리 완료')),
        );
        _loadManualCheckins();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'.replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _submitManualCheckin() async {
    if (_selectedEmployeeKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근로자를 선택해주세요.')),
      );
      return;
    }
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록 사유를 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? checkinDt;
      if (_checkinTime != null) {
        final h = _checkinTime!.hour.toString().padLeft(2, '0');
        final m = _checkinTime!.minute.toString().padLeft(2, '0');
        checkinDt = '$_workDate $h:$m:00';
      }

      await AttendanceService.manualCheckin(
        companyKey: _user?.companyKey ?? '',
        hyunjangKey: _selectedHyunjangKey!,
        employeeKey: _selectedEmployeeKey!,
        workDate: _workDate,
        checkinDt: checkinDt,
        manualReason: _reasonController.text.trim(),
        userId: _user?.userId ?? '',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수기 출근 등록 완료')),
        );
        _reasonController.clear();
        _checkinTime = null;
        _loadManualCheckins();
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

  Future<void> _submitBulkCheckin() async {
    if (_selectedEmployeeKeys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('근로자를 선택해주세요.')),
      );
      return;
    }
    if (_bulkReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('등록 사유를 입력해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final items = _selectedEmployeeKeys.map((key) {
        return {
          'company_key': _user?.companyKey ?? '',
          'hyunjang_key': _selectedHyunjangKey!,
          'employee_key': key.toString(),
          'work_date': _workDate,
        };
      }).toList();

      final count = await AttendanceService.manualBulk(
        manualReason: _bulkReasonController.text.trim(),
        userId: _user?.userId ?? '',
        items: items,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count건 수기 등록 완료')),
        );
        _selectedEmployeeKeys.clear();
        _bulkReasonController.clear();
        setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F7),
        appBar: AppBar(
          title: const Text('수기 등록'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B2E5C),
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1B2E5C),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF1B2E5C),
            tabs: const [
              Tab(text: '개별 등록'),
              Tab(text: '일괄 등록'),
            ],
          ),
        ),
        body: Column(
          children: [
            // 현장 선택 (공통)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: HyunjangPicker(
                hyunjangList: _hyunjangList,
                selectedKey: _selectedHyunjangKey,
                onSelected: (key, name) {
                  setState(() => _selectedHyunjangKey = key);
                  _loadEmployees();
                },
                label: '현장',
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildIndividualTab(),
                  _buildBulkTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndividualTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCard([
            _employees.isEmpty
                ? const InputDecorator(
                    decoration: InputDecoration(
                      labelText: '근로자',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Text('현장을 먼저 선택해주세요',
                        style: TextStyle(color: Colors.grey)),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedEmployeeKey,
                    decoration: const InputDecoration(
                      labelText: '근로자',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: _employees.map((e) {
                      return DropdownMenuItem(
                        value: e.seq.toString(),
                        child: Text(
                            '${e.employeeName} ${e.employeeCell ?? ''}'),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedEmployeeKey = v),
                  ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_workDate) ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() =>
                      _workDate = DateFormat('yyyy-MM-dd').format(picked));
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '근무일자',
                  border: OutlineInputBorder(),
                ),
                child: Text(_workDate),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _checkinTime ?? TimeOfDay.now(),
                );
                if (picked != null) setState(() => _checkinTime = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '출근 시간 (선택)',
                  border: OutlineInputBorder(),
                ),
                child: Text(_checkinTime?.format(context) ?? '현재 시간'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: '등록 사유 (필수)',
                hintText: '예: 현장 인터넷 불안정으로 QR 사용 불가',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitManualCheckin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('출근 등록'),
            ),
          ]),
          // 등록된 수기 건 목록
          if (_manualCheckins.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('등록된 수기 출근 건',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ..._manualCheckins.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${item.employeeName}  ${item.checkinDt.length >= 16 ? item.checkinDt.substring(11, 16) : item.checkinDt}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _handleCheckout(item),
                        child: const Text('퇴근 처리',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildBulkTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildCard([
            TextField(
              controller: _bulkReasonController,
              decoration: const InputDecoration(
                labelText: '공통 등록 사유 (필수)',
                hintText: '예: 비 오는 날 QR 사용 불가',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text(
              '근로자 선택 (${_selectedEmployeeKeys.length}명)',
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._employees.map((e) {
              return CheckboxListTile(
                value: _selectedEmployeeKeys.contains(e.seq),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedEmployeeKeys.add(e.seq);
                    } else {
                      _selectedEmployeeKeys.remove(e.seq);
                    }
                  });
                },
                title: Text(e.employeeName,
                    style: const TextStyle(fontSize: 14)),
                subtitle: e.employeeCell != null
                    ? Text(e.employeeCell!,
                        style: const TextStyle(fontSize: 12))
                    : null,
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitBulkCheckin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B2E5C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('일괄 등록'),
            ),
          ]),
        ],
      ),
    );
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
}
