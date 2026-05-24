import 'package:flutter/material.dart';

import '../../models/invoice_model.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../widgets/loading_overlay.dart';
import 'approval_form_screen.dart';

// Design Ref: §5.5 — 결재 상세 보기
class ApprovalDetailScreen extends StatefulWidget {
  final int invoiceSeq;

  const ApprovalDetailScreen({super.key, required this.invoiceSeq});

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  bool _isLoading = false;
  InvoiceModel? _invoice;
  List<dynamic> _approvalHistory = [];

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await InvoiceService.getDetail('${widget.invoiceSeq}');
      if (data['resultCode'] == '200') {
        final res = data['res'] as Map<String, dynamic>;
        final header = res['header'] as Map<String, dynamic>;
        final items = res['items'] as List?;
        if (items != null) header['items'] = items;
        _invoice = InvoiceModel.fromJson(header);
      }

      _approvalHistory =
          await InvoiceService.getApprovalHistory('${widget.invoiceSeq}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('상세 로드 실패: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _requestApproval() async {
    final user = AuthService().currentUser;
    if (user == null || _invoice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결재요청'),
        content: const Text('이 지급서의 결재를 요청하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('요청',
                  style: TextStyle(color: Color(0xFF1B2E5C)))),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await InvoiceService.requestApproval(
        invoiceKey: '${widget.invoiceSeq}',
        actorId: user.userId,
        actorName: user.userName,
      );
      if (!mounted) return;
      if (result['resultCode'] == '200') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결재요청 완료'),
              behavior: SnackBarBehavior.floating),
        );
        _loadDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결재요청 실패: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '결재 상세',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2E5C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B2E5C)),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: _invoice == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                onRefresh: _loadDetail,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // 상태 + 제목
                      _buildHeader(),
                      const SizedBox(height: 12),

                      // 이미지
                      if (_invoice!.imagePath != null)
                        Container(
                          width: double.infinity,
                          height: 200,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _invoice!.imagePath!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.broken_image,
                                    size: 48, color: Colors.grey.shade300),
                              ),
                            ),
                          ),
                        ),

                      // 기본 정보
                      _buildInfoSection('기본 정보', [
                        _infoRow('제목', _invoice!.title),
                        _infoRow('현장', _invoice!.hyunjangName),
                        _infoRow('문서유형', _docTypeLabel(_invoice!.docType)),
                        _infoRow('거래일자', _invoice!.transactionDate),
                      ]),
                      const SizedBox(height: 12),

                      // 거래처 정보
                      _buildInfoSection('거래처 정보', [
                        _infoRow('거래처명', _invoice!.vendorName),
                        _infoRow('은행', _invoice!.accountBank),
                        _infoRow('계좌번호', _invoice!.accountNumber),
                        _infoRow('예금주', _invoice!.accountHolder),
                      ]),
                      const SizedBox(height: 12),

                      // 금액
                      _buildInfoSection('금액', [
                        _infoRow('공급가액', _formatAmount(_invoice!.totalSupply)),
                        _infoRow('부가세', _formatAmount(_invoice!.totalVat)),
                        _infoRow('합계', _formatAmount(_invoice!.totalAmount),
                            bold: true),
                      ]),
                      const SizedBox(height: 12),

                      // 항목
                      if (_invoice!.items != null &&
                          _invoice!.items!.isNotEmpty)
                        _buildInfoSection('항목', [
                          ..._invoice!.items!.map((item) => _infoRow(
                                '${item.itemNo}. ${item.itemName ?? '-'}',
                                _formatAmount(item.totalAmount),
                              )),
                        ]),
                      if (_invoice!.items != null &&
                          _invoice!.items!.isNotEmpty)
                        const SizedBox(height: 12),

                      // 결재 이력
                      if (_approvalHistory.isNotEmpty)
                        _buildApprovalTimeline(),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar: _invoice == null
          ? null
          : _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _invoice!.vendorName ?? '거래처 미입력',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B2E5C),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _invoice!.statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              _invoice!.statusLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _invoice!.statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2E5C),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String? value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF3A3A3A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalTimeline() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '결재 이력',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2E5C),
            ),
          ),
          const SizedBox(height: 12),
          ..._approvalHistory.map((h) {
            final map = h as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 5, right: 12),
                    decoration: BoxDecoration(
                      color: _actionColor(map['action'] as String?),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_actionLabel(map['action'] as String?)} — ${map['actor_name'] ?? map['actor_id']}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (map['comment'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              map['comment'] as String,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ),
                        Text(
                          map['create_DT'] as String? ?? '',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    final status = _invoice!.status;
    if (status != 'DRAFT' && status != 'CONFIRMED') return null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ApprovalFormScreen(
                        invoiceSeq: widget.invoiceSeq,
                      ),
                    ),
                  );
                  if (result == true) _loadDetail();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B2E5C),
                  side: const BorderSide(color: Color(0xFF1B2E5C)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('수정'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _requestApproval,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B2E5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '결재요청',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _docTypeLabel(String? type) {
    switch (type) {
      case 'EXPENSE_REQUEST': return '지출요청서';
      case 'EXPENSE_STATEMENT': return '지출결의서';
      case 'TAX_INVOICE': return '세금계산서';
      default: return type ?? '-';
    }
  }

  String _actionLabel(String? action) {
    switch (action) {
      case 'REQUESTED': return '결재요청';
      case 'APPROVED': return '승인';
      case 'REJECTED': return '반려';
      case 'PAID': return '지급완료';
      default: return action ?? '-';
    }
  }

  Color _actionColor(String? action) {
    switch (action) {
      case 'REQUESTED': return Colors.orange;
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Colors.red;
      case 'PAID': return Colors.purple;
      default: return Colors.grey;
    }
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
}
