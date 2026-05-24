import 'package:flutter/material.dart';

import '../../models/invoice_model.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import 'approval_detail_screen.dart';
import 'approval_form_screen.dart';

// Design Ref: §5.3 — 결재요청 목록 화면
class ApprovalListScreen extends StatefulWidget {
  const ApprovalListScreen({super.key});

  @override
  State<ApprovalListScreen> createState() => _ApprovalListScreenState();
}

class _ApprovalListScreenState extends State<ApprovalListScreen> {
  final List<InvoiceModel> _invoices = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _size = 20;
  String? _statusFilter;

  final _filters = const [
    {'label': '전체', 'value': null},
    {'label': '임시저장', 'value': 'DRAFT'},
    {'label': '확인완료', 'value': 'CONFIRMED'},
    {'label': '결재요청', 'value': 'REQUESTED'},
    {'label': '승인', 'value': 'APPROVED'},
    {'label': '반려', 'value': 'REJECTED'},
  ];

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList({bool refresh = false}) async {
    if (_isLoading) return;
    if (!refresh && !_hasMore) return;

    setState(() => _isLoading = true);
    if (refresh) {
      _offset = 0;
      _invoices.clear();
      _hasMore = true;
    }

    try {
      final user = AuthService().currentUser;
      if (user == null) return;

      final data = await InvoiceService.getList(
        companyKey: user.companyKey,
        createId: user.userId,
        status: _statusFilter,
        offset: _offset,
        size: _size,
      );

      if (data['resultCode'] == '200' && data['res'] != null) {
        final raw = data['res'];
        if (raw is Map) {
          final res = Map<String, dynamic>.from(raw);
          final items = res['data'] ?? res['resultModel'] ?? res['list'];
          if (items is List) {
            final list = items
                .map((e) => InvoiceModel.fromJson(
                    Map<String, dynamic>.from(e as Map)))
                .toList();
            final total = (res['totalRecords'] as int?) ?? list.length;

            _invoices.addAll(list);
            _offset += list.length;
            _hasMore = _invoices.length < total;
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('목록 로드 실패: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFilterChanged(String? status) {
    _statusFilter = status;
    _loadList(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '결재요청',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2E5C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B2E5C)),
      ),
      body: Column(
        children: [
          // 상태 필터 칩
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((f) {
                  final isSelected = _statusFilter == f['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f['label'] as String),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1B2E5C),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      onSelected: (_) =>
                          _onFilterChanged(f['value']),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // 목록
          Expanded(
            child: _isLoading && _invoices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _invoices.isEmpty
                    ? _buildEmpty()
                    : _buildList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1B2E5C),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ApprovalFormScreen()),
          );
          if (result == true) _loadList(refresh: true);
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '결재 내역이 없습니다',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '+ 버튼으로 새 결재를 요청하세요',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: () => _loadList(refresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _invoices.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _invoices.length) {
            _loadList();
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final invoice = _invoices[index];
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.vendorName ?? '거래처 미입력',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1B2E5C),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: invoice.statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      invoice.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: invoice.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (invoice.hyunjangName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      invoice.hyunjangName!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (invoice.title != null)
                    Text(
                      invoice.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatAmount(invoice.totalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B2E5C),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(invoice.createDT),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ApprovalDetailScreen(invoiceSeq: invoice.seq!),
                  ),
                );
                if (result == true) _loadList(refresh: true);
              },
            ),
          );
        },
      ),
    );
  }

  String _formatAmount(int? amount) {
    if (amount == null) return '-';
    final str = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(',');
      buffer.write(str[i]);
    }
    return '${buffer.toString()}원';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return dateStr;
    }
  }
}
