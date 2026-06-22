import 'package:flutter/material.dart';

/// 현장 선택 위젯 — 탭하면 BottomSheet에 카드형 현장 목록 표시
class HyunjangPicker extends StatelessWidget {
  final List<Map<String, dynamic>> hyunjangList;
  final String? selectedKey;
  final void Function(String key, String name) onSelected;
  final String? label;

  const HyunjangPicker({
    super.key,
    required this.hyunjangList,
    required this.selectedKey,
    required this.onSelected,
    this.label,
  });

  String get _selectedName {
    if (selectedKey == null || hyunjangList.isEmpty) return '';
    final match = hyunjangList.where(
      (h) => h['seq'].toString() == selectedKey,
    );
    if (match.isEmpty) return '';
    return match.first['hyunjang_name'] as String? ?? '';
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    '현장 선택',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1B2E5C),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${hyunjangList.length}개 현장',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: hyunjangList.isEmpty
                  ? Center(
                      child: Text('등록된 현장이 없습니다.',
                          style: TextStyle(color: Colors.grey.shade500)),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: hyunjangList.length,
                      itemBuilder: (ctx, i) =>
                          _buildCard(ctx, hyunjangList[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> h) {
    final key = h['seq'].toString();
    final name = h['hyunjang_name'] as String? ?? '';
    final address = h['hyunjang_address'] as String? ?? '';
    final isSelected = key == selectedKey;

    return GestureDetector(
      onTap: () {
        onSelected(key, name);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1B2E5C).withValues(alpha: 0.06)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1B2E5C)
                : Colors.grey.shade200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E5C).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on,
                color: Color(0xFF1B2E5C),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: const Color(0xFF1B2E5C),
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: Color(0xFF1B2E5C), size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: hyunjangList.isEmpty
            ? Text('로딩 중...',
                style: TextStyle(color: Colors.grey.shade400))
            : Text(
                _selectedName.isEmpty ? '현장을 선택해주세요' : _selectedName,
                style: TextStyle(
                  fontSize: 15,
                  color: _selectedName.isEmpty
                      ? Colors.grey.shade400
                      : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
