import 'package:intl/intl.dart';
import 'client.dart';

class Invoice {
  final int id;
  final int clientId;
  final String? clientName;
  final String? documentNumber;
  final String invoiceNumber;
  final String concept;
  final double amount;
  final DateTime dueDate;
  final DateTime? issueDate;
  final String status;
  final String? externalId;
  final String? notes;
  final int organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? uuid;
  final String? currency;
  final String? deletedAt;
  final Client? client;
  
  // Campos que pueden no estar en la respuesta de la API
  final int paymentsCount;
  final double paymentsAmount;
  final int daysOverdue;
  final int instalmentCount;

  Invoice({
    required this.id,
    required this.clientId,
    this.clientName,
    this.documentNumber,
    required this.invoiceNumber,
    required this.concept,
    required this.amount,
    required this.dueDate,
    this.issueDate,
    required this.status,
    this.externalId,
    this.notes,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
    this.uuid,
    this.currency,
    this.deletedAt,
    this.client,
    this.paymentsCount = 0,
    this.paymentsAmount = 0,
    this.daysOverdue = 0,
    this.instalmentCount = 1,
  });

  double get remainingAmount => amount - paymentsAmount;
  
  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  
  bool get isExpired => daysOverdue > 0;

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    // Manejar diferentes formatos de fecha/hora
    DateTime parseDateTime(String? dateTimeStr) {
      if (dateTimeStr == null) return DateTime.now();
      
      try {
        // Intentar con formato ISO
        return DateTime.parse(dateTimeStr);
      } catch (_) {
        try {
          // Intentar con formato yyyy-MM-dd HH:mm:ss
          return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTimeStr);
        } catch (_) {
          // Si todo falla, devolver la fecha actual
          return DateTime.now();
        }
      }
    }
    
    // Convertir valor a double
    double parseAmount(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }
    
    // Parsear el cliente si está presente en la respuesta
    Client? client;
    if (json['client'] != null) {
      client = Client.fromJson(json['client']);
    }
    
    return Invoice(
      id: json['id'] ?? 0,
      clientId: json['client_id'] ?? 0,
      clientName: json['client_name'],
      documentNumber: json['document_number'],
      invoiceNumber: json['invoice_number'] ?? '',
      concept: json['concept'] ?? '',
      amount: parseAmount(json['amount']),
      dueDate: json['due_date'] != null ? dateFormat.parse(json['due_date']) : DateTime.now(),
      issueDate: json['issue_date'] != null ? dateFormat.parse(json['issue_date']) : null,
      status: json['status'] ?? 'pending',
      externalId: json['external_id'],
      notes: json['notes'],
      organizationId: json['organization_id'] ?? 0,
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
      uuid: json['uuid'],
      currency: json['currency'],
      deletedAt: json['deleted_at'],
      client: client,
      paymentsCount: json['payments_count'] ?? 0,
      paymentsAmount: parseAmount(json['payments_amount']),
      daysOverdue: json['days_overdue'] ?? 0,
      instalmentCount: json['instalment_count'] ?? 1,
    );
  }
}

class InvoiceResponse {
  final List<Invoice> invoices;
  final Pagination? pagination;

  InvoiceResponse({
    required this.invoices,
    this.pagination,
  });

  factory InvoiceResponse.fromJson(Map<String, dynamic> json) {
    // Verificar si la respuesta contiene el campo 'invoices'
    if (json.containsKey('invoices')) {
      return InvoiceResponse(
        invoices: (json['invoices'] as List)
            .map((invoice) => Invoice.fromJson(invoice))
            .toList(),
        pagination: json.containsKey('pagination') 
            ? Pagination.fromJson(json['pagination']) 
            : null,
      );
    } else {
      // Si no hay campo 'invoices', devolver una lista vacía
      return InvoiceResponse(
        invoices: [],
        pagination: null,
      );
    }
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
