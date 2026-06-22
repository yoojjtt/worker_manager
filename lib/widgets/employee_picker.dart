import 'package:flutter/material.dart';

import '../models/attendance_model.dart';

/// 근로자 선택 위젯 — 탭하면 BottomSheet에 검색 + 카드형 목록 표시
class EmployeePicker extends StatelessWidget {
  final List<DailyEmployee> employees;
  final String? selectedKey;
  final void Function(String key, String name) onSelected;
  final bool isLoading;
  final String? errorMessage;

  const EmployeePicker({
    super.key,
    required this.employees,
    required this.selectedKey,
    required this.onSelected,
    this.isLoading = false,
    this.errorMessage,
  });

  String get _selectedName {
    if (selectedKey == null || employees.isEmpty) return '';
    final match = employees.where((e) => e.seq.toString() == selectedKey);
    if (match.isEmpty) return '';
    return match.first.employeeName;
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _EmployeePickerSheet(
        employees: employees,
        selectedKey: selectedKey,
        onSelected: (key, name) {
          onSelected(key, name);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const InputDecorator(
        decoration: InputDecoration(
          labelText: '근로자',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('근로자 로딩 중...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (errorMessage != null && employees.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: '근로자',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        child: Text(
          errorMessage!,
          style: TextStyle(fontSize: 13, color: Colors.orange.shade700),
        ),
      );
    }

    return InkWell(
      onTap: employees.isEmpty ? null : () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '근로자',
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: employees.isEmpty
              ? null
              : const Icon(Icons.search),
        ),
        child: employees.isEmpty
            ? Text('현장을 먼저 선택해주세요',
                style: TextStyle(color: Colors.grey.shade400))
            : Text(
                _selectedName.isEmpty ? '탭하여 근로자 검색' : _selectedName,
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedName.isEmpty
                      ? Colors.grey.shade400
                      : Colors.black87,
                ),
              ),
      ),
    );
  }
}

class _EmployeePickerSheet extends StatefulWidget {
  final List<DailyEmployee> employees;
  final String? selectedKey;
  final void Function(String key, String name) onSelected;

  const _EmployeePickerSheet({
    required this.employees,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  final _searchController = TextEditingController();
  List<DailyEmployee> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.employees;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _filtered = widget.employees;
      } else {
        _filtered = widget.employees.where((e) {
          return e.employeeName.contains(query) ||
              (e.employeeCell ?? '').contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollController) => Column(
        children: [
          // 핸들
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 검색
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '이름 또는 연락처로 검색',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '${_filtered.length}명',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const Divider(height: 8),
          // 목록
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text('검색 결과가 없습니다.',
                        style: TextStyle(color: Colors.grey.shade500)),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filtered.length,
                    itemBuilder: (ctx, i) => _buildItem(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(DailyEmployee emp) {
    final isSelected = emp.seq.toString() == widget.selectedKey;
    return InkWell(
      onTap: () => widget.onSelected(emp.seq.toString(), emp.employeeName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade100),
          ),
          color: isSelected
              ? const Color(0xFF1B2E5C).withValues(alpha: 0.05)
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E5C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.person,
                  size: 18, color: Color(0xFF1B2E5C)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    emp.employeeName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (emp.employeeCell != null && emp.employeeCell!.isNotEmpty)
                    Text(
                      emp.employeeCell!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF1B2E5C), size: 20),
          ],
        ),
      ),
    );
  }
}
