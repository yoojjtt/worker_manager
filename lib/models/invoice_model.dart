import 'dart:ui' show Color;

class InvoiceModel {
  final int? seq;
  final String? companyKey;
  final String? hyunjangKey;
  final String? hyunjangName;
  final String? invoiceMonth;
  final String? vendorName;
  final String? accountBank;
  final String? accountNumber;
  final String? accountHolder;
  final int? totalSupply;
  final int? totalVat;
  final int? totalAmount;
  final String? imagePath;
  final String? docType;
  final String? title;
  final int? accountCategorySeq;
  final String? accountCategoryName;
  final int? partnerSeq;
  final String? paymentMethod;
  final String? transactionDate;
  final String? status;
  final String? requestedBy;
  final String? requestedDT;
  final String? createDT;
  final List<InvoiceItemModel>? items;

  InvoiceModel({
    this.seq,
    this.companyKey,
    this.hyunjangKey,
    this.hyunjangName,
    this.invoiceMonth,
    this.vendorName,
    this.accountBank,
    this.accountNumber,
    this.accountHolder,
    this.totalSupply,
    this.totalVat,
    this.totalAmount,
    this.imagePath,
    this.docType,
    this.title,
    this.accountCategorySeq,
    this.accountCategoryName,
    this.partnerSeq,
    this.paymentMethod,
    this.transactionDate,
    this.status,
    this.requestedBy,
    this.requestedDT,
    this.createDT,
    this.items,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      seq: json['seq'] as int?,
      companyKey: json['company_key']?.toString(),
      hyunjangKey: json['hyunjang_key']?.toString(),
      hyunjangName: json['hyunjang_name'] as String?,
      invoiceMonth: json['invoice_month'] as String?,
      vendorName: json['vendor_name'] as String?,
      accountBank: json['account_bank'] as String?,
      accountNumber: json['account_number'] as String?,
      accountHolder: json['account_holder'] as String?,
      totalSupply: json['total_supply'] as int?,
      totalVat: json['total_vat'] as int?,
      totalAmount: json['total_amount'] as int?,
      imagePath: json['image_path'] as String?,
      docType: json['doc_type'] as String?,
      title: json['title'] as String?,
      accountCategorySeq: json['account_category_seq'] as int?,
      accountCategoryName: json['account_category_name'] as String?,
      partnerSeq: json['partner_seq'] as int?,
      paymentMethod: json['payment_method'] as String?,
      transactionDate: json['transaction_date'] as String?,
      status: json['status'] as String?,
      requestedBy: json['requested_by'] as String?,
      requestedDT: json['requested_DT'] as String?,
      createDT: json['create_DT'] as String?,
      items: json['items'] != null
          ? (json['items'] as List)
              .map((e) =>
                  InvoiceItemModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'DRAFT': return '임시저장';
      case 'CONFIRMED': return '확인완료';
      case 'REQUESTED': return '결재요청';
      case 'APPROVED': return '승인';
      case 'REJECTED': return '반려';
      case 'PAID': return '지급완료';
      default: return status ?? '-';
    }
  }

  Color get statusColor {
    switch (status) {
      case 'DRAFT': return const Color(0xFF9E9E9E);
      case 'CONFIRMED': return const Color(0xFF1B2E5C);
      case 'REQUESTED': return const Color(0xFFFF9800);
      case 'APPROVED': return const Color(0xFF4CAF50);
      case 'REJECTED': return const Color(0xFFF44336);
      case 'PAID': return const Color(0xFF9C27B0);
      default: return const Color(0xFF9E9E9E);
    }
  }
}

class InvoiceItemModel {
  final int? seq;
  final int? itemNo;
  final String? itemName;
  final int? supplyAmount;
  final int? vatAmount;
  final int? totalAmount;

  InvoiceItemModel({
    this.seq,
    this.itemNo,
    this.itemName,
    this.supplyAmount,
    this.vatAmount,
    this.totalAmount,
  });

  factory InvoiceItemModel.fromJson(Map<String, dynamic> json) {
    return InvoiceItemModel(
      seq: json['seq'] as int?,
      itemNo: json['item_no'] as int?,
      itemName: json['item_name'] as String?,
      supplyAmount: json['supply_amount'] as int?,
      vatAmount: json['vat_amount'] as int?,
      totalAmount: json['total_amount'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (itemNo != null) 'item_no': itemNo,
    if (itemName != null) 'item_name': itemName,
    if (supplyAmount != null) 'supply_amount': supplyAmount,
    if (vatAmount != null) 'vat_amount': vatAmount,
    if (totalAmount != null) 'total_amount': totalAmount,
  };
}
