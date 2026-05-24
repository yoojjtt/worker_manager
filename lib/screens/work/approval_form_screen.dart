import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/invoice_model.dart';
import '../../services/auth_service.dart';
import '../../services/invoice_service.dart';
import '../../widgets/loading_overlay.dart';

// Design Ref: §5.4 — 결재요청 작성/수정 폼
class ApprovalFormScreen extends StatefulWidget {
  final int? invoiceSeq; // null이면 신규, 있으면 수정

  const ApprovalFormScreen({super.key, this.invoiceSeq});

  @override
  State<ApprovalFormScreen> createState() => _ApprovalFormScreenState();
}

class _ApprovalFormScreenState extends State<ApprovalFormScreen> {
  bool _isLoading = false;
  File? _imageFile;
  String? _imagePath;

  // 폼 컨트롤러
  final _titleCtrl = TextEditingController();
  final _vendorNameCtrl = TextEditingController();
  final _accountBankCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _accountHolderCtrl = TextEditingController();
  final _totalSupplyCtrl = TextEditingController();
  final _totalVatCtrl = TextEditingController();
  final _totalAmountCtrl = TextEditingController();

  // 드롭다운 데이터
  List<Map<String, dynamic>> _hyunjangList = [];
  List<Map<String, dynamic>> _categoryList = [];
  List<Map<String, dynamic>> _partnerList = [];

  // 선택 값
  String? _selectedHyunjangKey;
  int? _selectedCategorySeq;
  String? _selectedCategoryName;
  int? _selectedPartnerSeq;
  String _docType = 'EXPENSE_REQUEST';
  String _paymentMethod = 'TRANSFER';
  DateTime _transactionDate = DateTime.now();

  // 항목 리스트
  List<InvoiceItemModel> _items = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.invoiceSeq != null) {
      _loadExisting();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _vendorNameCtrl.dispose();
    _accountBankCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _totalSupplyCtrl.dispose();
    _totalVatCtrl.dispose();
    _totalAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDropdowns() async {
    final user = AuthService().currentUser;
    if (user == null) return;
    try {
      final hyunjang = await InvoiceService.getHyunjangList(user.companyKey);
      if (mounted) setState(() => _hyunjangList = hyunjang);
    } catch (_) {}
    try {
      final categories = await InvoiceService.getAccountCategories(user.companyKey);
      if (mounted) setState(() => _categoryList = categories);
    } catch (_) {}
    try {
      final partners = await InvoiceService.getPartners(user.companyKey);
      if (mounted) setState(() => _partnerList = partners);
    } catch (_) {}
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    try {
      final data =
          await InvoiceService.getDetail('${widget.invoiceSeq}');
      if (data['resultCode'] == '200') {
        final res = data['res'] as Map<String, dynamic>;
        final header = res['header'] as Map<String, dynamic>;
        final items = res['items'] as List?;

        _titleCtrl.text = header['title'] ?? '';
        _vendorNameCtrl.text = header['vendor_name'] ?? '';
        _accountBankCtrl.text = header['account_bank'] ?? '';
        _accountNumberCtrl.text = header['account_number'] ?? '';
        _accountHolderCtrl.text = header['account_holder'] ?? '';
        _totalSupplyCtrl.text = '${header['total_supply'] ?? 0}';
        _totalVatCtrl.text = '${header['total_vat'] ?? 0}';
        _totalAmountCtrl.text = '${header['total_amount'] ?? 0}';
        _selectedHyunjangKey = header['hyunjang_key']?.toString();
        _selectedCategorySeq = header['account_category_seq'] as int?;
        _selectedCategoryName = header['account_category_name'] as String?;
        _selectedPartnerSeq = header['partner_seq'] as int?;
        _docType = header['doc_type'] ?? 'EXPENSE_REQUEST';
        _paymentMethod = header['payment_method'] ?? 'TRANSFER';
        _imagePath = header['image_path'] as String?;
        if (header['transaction_date'] != null) {
          try {
            _transactionDate = DateTime.parse(header['transaction_date']);
          } catch (_) {}
        }
        if (items != null) {
          _items = items
              .map((e) =>
                  InvoiceItemModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      if (widget.invoiceSeq == null && mounted) Navigator.pop(context);
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80);
    if (picked == null) {
      if (widget.invoiceSeq == null && mounted) Navigator.pop(context);
      return;
    }

    _imageFile = File(picked.path);
    await _parseOcr();
  }

  Future<void> _parseOcr() async {
    if (_imageFile == null) return;
    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final data =
          await InvoiceService.parseInvoice(_imageFile!, user.companyKey);
      if (data['resultCode'] == '200') {
        final res = data['res'] as Map<String, dynamic>;
        setState(() {
          _vendorNameCtrl.text = res['vendor_name'] ?? '';
          _accountBankCtrl.text = res['account_bank'] ?? '';
          _accountNumberCtrl.text = res['account_number'] ?? '';
          _accountHolderCtrl.text = res['account_holder'] ?? '';
          _totalSupplyCtrl.text = '${res['total_supply'] ?? 0}';
          _totalVatCtrl.text = '${res['total_vat'] ?? 0}';
          _totalAmountCtrl.text = '${res['total_amount'] ?? 0}';
          _imagePath = res['image_path'] as String?;
          if (res['items'] != null) {
            _items = (res['items'] as List)
                .map((e) =>
                    InvoiceItemModel.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR 파싱 실패: $e'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final user = AuthService().currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'company_key': user.companyKey,
        'vendor_name': _vendorNameCtrl.text,
        'account_bank': _accountBankCtrl.text,
        'account_number': _accountNumberCtrl.text,
        'account_holder': _accountHolderCtrl.text,
        'total_supply': int.tryParse(_totalSupplyCtrl.text) ?? 0,
        'total_vat': int.tryParse(_totalVatCtrl.text) ?? 0,
        'total_amount': int.tryParse(_totalAmountCtrl.text) ?? 0,
        'title': _titleCtrl.text,
        'doc_type': _docType,
        'payment_method': _paymentMethod,
        'transaction_date':
            '${_transactionDate.year}-${_transactionDate.month.toString().padLeft(2, '0')}-${_transactionDate.day.toString().padLeft(2, '0')}',
        'invoice_month':
            '${_transactionDate.year}-${_transactionDate.month.toString().padLeft(2, '0')}',
        'create_ID': user.userId,
        'items': _items.map((e) => e.toJson()).toList(),
      };
      if (_selectedHyunjangKey != null) {
        body['hyunjang_key'] = _selectedHyunjangKey;
      }
      if (_selectedCategorySeq != null) {
        body['account_category_seq'] = _selectedCategorySeq;
        body['account_category_name'] = _selectedCategoryName;
      }
      if (_selectedPartnerSeq != null) {
        body['partner_seq'] = _selectedPartnerSeq;
      }
      if (_imagePath != null) body['image_path'] = _imagePath;

      Map<String, dynamic> result;
      if (widget.invoiceSeq != null) {
        body['seq'] = '${widget.invoiceSeq}';
        body['update_ID'] = user.userId;
        result = await InvoiceService.updateInvoice(body);
      } else {
        result = await InvoiceService.saveInvoice(body);
      }

      if (!mounted) return;
      if (result['resultCode'] == '200') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.'),
              behavior: SnackBarBehavior.floating),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: ${result['res']}'),
              behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'),
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
        title: Text(
          widget.invoiceSeq != null ? '결재 수정' : '결재 작성',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1B2E5C),
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF1B2E5C)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text(
              '저장',
              style: TextStyle(
                color: Color(0xFF1B2E5C),
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // OCR 이미지 영역
              if (_imageFile != null || _imagePath != null)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : Image.network(_imagePath!, fit: BoxFit.cover),
                  ),
                ),

              // 사진 변경 버튼
              if (widget.invoiceSeq == null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('사진 다시 선택'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1B2E5C),
                      side: const BorderSide(color: Color(0xFF1B2E5C)),
                    ),
                  ),
                ),

              _buildSection('기본 정보', [
                _buildTextField('제목/적요', _titleCtrl),
                _buildDropdown(
                  '현장',
                  _selectedHyunjangKey,
                  _hyunjangList
                      .map((e) => DropdownMenuItem<String>(
                            value: e['seq'].toString(),
                            child: Text(
                              e['hyunjang_name'] as String? ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  (v) => setState(() => _selectedHyunjangKey = v),
                ),
                _buildDropdown(
                  '문서유형',
                  _docType,
                  const [
                    DropdownMenuItem(
                        value: 'EXPENSE_REQUEST', child: Text('지출요청서')),
                    DropdownMenuItem(
                        value: 'EXPENSE_STATEMENT', child: Text('지출결의서')),
                    DropdownMenuItem(
                        value: 'TAX_INVOICE', child: Text('세금계산서')),
                  ],
                  (v) => setState(() => _docType = v ?? 'EXPENSE_REQUEST'),
                ),
                _buildDatePicker(),
              ]),
              const SizedBox(height: 12),

              _buildSection('거래처 정보', [
                _buildDropdown(
                  '거래처 선택',
                  _selectedPartnerSeq?.toString(),
                  _partnerList
                      .map((e) => DropdownMenuItem<String>(
                            value: e['seq'].toString(),
                            child: Text(
                              e['partner_name'] as String? ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  (v) {
                    final seq = int.tryParse(v ?? '');
                    setState(() => _selectedPartnerSeq = seq);
                  },
                ),
                _buildTextField('거래처명', _vendorNameCtrl),
                _buildTextField('은행', _accountBankCtrl),
                _buildTextField('계좌번호', _accountNumberCtrl),
                _buildTextField('예금주', _accountHolderCtrl),
              ]),
              const SizedBox(height: 12),

              _buildSection('금액 정보', [
                _buildDropdown(
                  '계정과목',
                  _selectedCategorySeq?.toString(),
                  _categoryList
                      .map((e) => DropdownMenuItem<String>(
                            value: e['seq'].toString(),
                            child: Text(
                              e['category_name'] as String? ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  (v) {
                    final seq = int.tryParse(v ?? '');
                    final match = _categoryList
                        .where((e) => e['seq'].toString() == v)
                        .firstOrNull;
                    setState(() {
                      _selectedCategorySeq = seq;
                      _selectedCategoryName =
                          match?['category_name'] as String?;
                    });
                  },
                ),
                _buildDropdown(
                  '결제수단',
                  _paymentMethod,
                  const [
                    DropdownMenuItem(value: 'TRANSFER', child: Text('계좌이체')),
                    DropdownMenuItem(value: 'CARD', child: Text('카드')),
                    DropdownMenuItem(value: 'CASH', child: Text('현금')),
                  ],
                  (v) => setState(() => _paymentMethod = v ?? 'TRANSFER'),
                ),
                _buildTextField('공급가액', _totalSupplyCtrl,
                    keyboardType: TextInputType.number),
                _buildTextField('부가세', _totalVatCtrl,
                    keyboardType: TextInputType.number),
                _buildTextField('합계', _totalAmountCtrl,
                    keyboardType: TextInputType.number),
              ]),
              const SizedBox(height: 12),

              // 항목 리스트
              _buildSection('항목', [
                ..._items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${i + 1}. ${item.itemName ?? '-'}  ${_formatAmount(item.totalAmount)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _items.removeAt(i)),
                          child: Icon(Icons.close,
                              size: 18, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }),
                if (_items.isEmpty)
                  Text(
                    'OCR로 자동 추가되거나 없음',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade400),
                  ),
              ]),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    ValueChanged<T?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: items.any((e) => e.value == value) ? value : null,
        items: items,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          border: const OutlineInputBorder(),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14, color: Color(0xFF3A3A3A)),
        isExpanded: true,
      ),
    );
  }

  Widget _buildDatePicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _transactionDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
          );
          if (picked != null) setState(() => _transactionDate = picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: '거래일자',
            labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          child: Text(
            '${_transactionDate.year}-${_transactionDate.month.toString().padLeft(2, '0')}-${_transactionDate.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 14),
          ),
        ),
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
}
