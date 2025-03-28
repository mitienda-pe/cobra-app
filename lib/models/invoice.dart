import 'package:intl/intl.dart';

class Invoice {
  final int id;
  final int clientId;
  final String clientName;
  final String documentNumber;
  final String invoiceNumber;
  final String concept;
  final double amount;
  final DateTime dueDate;
  final String status;
  final String? externalId;
  final String? notes;
  final int organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int paymentsCount;
  final double paymentsAmount;
  final int daysOverdue;

  Invoice({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.documentNumber,
    required this.invoiceNumber,
    required this.concept,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.externalId,
    this.notes,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
    required this.paymentsCount,
    required this.paymentsAmount,
    required this.daysOverdue,
  });

  double get remainingAmount => amount - paymentsAmount;
  
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  
  bool get isExpired => daysOverdue > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final dateTimeFormat = DateFormat('yyyy-MM-ddTHH:mm:ssZ');
    
    return Invoice(
      id: json['id'],
      clientId: json['client_id'],
      clientName: json['client_name'],
      documentNumber: json['document_number'],
      invoiceNumber: json['invoice_number'],
      concept: json['concept'],
      amount: (json['amount'] is int) 
          ? (json['amount'] as int).toDouble() 
          : json['amount'],
      dueDate: dateFormat.parse(json['due_date']),
      status: json['status'],
      externalId: json['external_id'],
      notes: json['notes'],
      organizationId: json['organization_id'],
      createdAt: dateTimeFormat.parse(json['created_at']),
      updatedAt: dateTimeFormat.parse(json['updated_at']),
      paymentsCount: json['payments_count'],
      paymentsAmount: (json['payments_amount'] is int) 
          ? (json['payments_amount'] as int).toDouble() 
          : json['payments_amount'],
      daysOverdue: json['days_overdue'],
    );
  }
}

class InvoiceResponse {
  final bool success;
  final List<Invoice> invoices;
  final Pagination pagination;

  InvoiceResponse({
    required this.success,
    required this.invoices,
    required this.pagination,
  });

  factory InvoiceResponse.fromJson(Map<String, dynamic> json) {
    return InvoiceResponse(
      success: json['success'],
      invoices: (json['invoices'] as List)
          .map((invoice) => Invoice.fromJson(invoice))
          .toList(),
      pagination: Pagination.fromJson(json['pagination']),
    );
  }
}

class Pagination {
  final int currentPage;
  final int perPage;
  final int totalPages;
  final int totalItems;

  Pagination({
    required this.currentPage,
    required this.perPage,
    required this.totalPages,
    required this.totalItems,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      currentPage: json['current_page'],
      perPage: json['per_page'],
      totalPages: json['total_pages'],
      totalItems: json['total_items'],
    );
  }
}
