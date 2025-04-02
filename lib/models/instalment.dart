import 'package:intl/intl.dart';
import 'invoice.dart' show Invoice, Pagination;
import 'client.dart' hide Pagination;

class Instalment {
  final int id;
  final int invoiceId;
  final int number;
  final double amount;
  final double paidAmount;
  final double remainingAmount;
  final DateTime dueDate;
  final String status; // 'pending', 'paid', 'cancelled', 'rejected'
  final int? paymentId;
  final DateTime? paymentDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isOverdue;
  final Map<String, dynamic>? additionalData;
  
  // Relaciones
  final Invoice? invoice;
  final Client? client;

  Instalment({
    required this.id,
    required this.invoiceId,
    required this.number,
    required this.amount,
    required this.paidAmount,
    required this.remainingAmount,
    required this.dueDate,
    required this.status,
    this.paymentId,
    this.paymentDate,
    required this.createdAt,
    required this.updatedAt,
    required this.isOverdue,
    this.additionalData,
    this.invoice,
    this.client,
  });

  factory Instalment.fromJson(Map<String, dynamic> json) {
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
    Client? clientObj;
    if (json['client'] != null) {
      clientObj = Client.fromJson(json['client']);
    } else if (json['client_business_name'] != null) {
      // Convertir valores de ubicación a double
      double? lat;
      double? lng;
      
      if (json['client_latitude'] != null) {
        if (json['client_latitude'] is double) {
          lat = json['client_latitude'];
        } else if (json['client_latitude'] is int) {
          lat = (json['client_latitude'] as int).toDouble();
        } else if (json['client_latitude'] is String) {
          lat = double.tryParse(json['client_latitude']);
        }
      }
      
      if (json['client_longitude'] != null) {
        if (json['client_longitude'] is double) {
          lng = json['client_longitude'];
        } else if (json['client_longitude'] is int) {
          lng = (json['client_longitude'] as int).toDouble();
        } else if (json['client_longitude'] is String) {
          lng = double.tryParse(json['client_longitude']);
        }
      }
      
      // Crear un cliente básico con los datos disponibles
      clientObj = Client(
        id: 0,
        uuid: json['client_uuid'] ?? '',
        businessName: json['client_business_name'] ?? 'Cliente no disponible',
        documentNumber: json['client_document'] ?? 'N/A',
        contactName: json['client_contact_name'] ?? 'N/A',
        email: json['client_email'] ?? 'N/A',
        phone: json['client_phone'] ?? 'N/A',
        address: json['client_address'] ?? 'N/A',
        latitude: lat,
        longitude: lng,
        status: 'active',
        organizationId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    // Parsear la factura si está presente en la respuesta
    Invoice? invoiceObj;
    if (json['invoice'] != null) {
      invoiceObj = Invoice.fromJson(json['invoice']);
    } else if (json['invoice_id'] != null) {
      // Crear una factura básica con los datos disponibles
      DateTime? invoiceDueDate;
      if (json['invoice_due_date'] != null) {
        try {
          invoiceDueDate = dateFormat.parse(json['invoice_due_date']);
        } catch (e) {
          // Si hay un error al parsear la fecha, intentar con el formato completo
          try {
            invoiceDueDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(json['invoice_due_date']);
          } catch (e) {
            // Si sigue fallando, usar la fecha de vencimiento de la cuota
            invoiceDueDate = json['due_date'] != null ? dateFormat.parse(json['due_date']) : null;
          }
        }
      }
      
      DateTime? invoiceIssueDate;
      if (json['invoice_issue_date'] != null) {
        try {
          invoiceIssueDate = dateFormat.parse(json['invoice_issue_date']);
        } catch (e) {
          // Si hay un error al parsear la fecha, intentar con el formato completo
          try {
            invoiceIssueDate = DateFormat('yyyy-MM-dd HH:mm:ss').parse(json['invoice_issue_date']);
          } catch (e) {
            // Si sigue fallando, usar la fecha actual
            invoiceIssueDate = DateTime.now();
          }
        }
      }
      
      invoiceObj = Invoice(
        id: json['invoice_id'] ?? 0,
        uuid: json['invoice_uuid'] ?? '',
        clientId: json['client_id'] ?? 0,
        invoiceNumber: json['invoice_number'] ?? 'N/A',
        amount: parseAmount(json['invoice_amount'] ?? json['amount']),
        instalmentCount: json['invoice_instalment_count'] ?? 1,
        concept: json['invoice_concept'] ?? 'Factura',
        dueDate: invoiceDueDate ?? DateTime.now(),
        issueDate: invoiceIssueDate,
        status: 'pending',
        organizationId: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
    
    // Calcular montos si no vienen en la respuesta
    double amount = parseAmount(json['amount']);
    double paidAmount = parseAmount(json['paid_amount'] ?? 0);
    double remainingAmount = parseAmount(json['remaining_amount'] ?? (amount - paidAmount));
    
    Map<String, dynamic>? additionalData;
    if (json.length > 15) {
      additionalData = {};
      json.forEach((key, value) {
        if (![
          'id',
          'uuid',
          'invoice_id',
          'number',
          'amount',
          'paid_amount',
          'remaining_amount',
          'due_date',
          'status',
          'payment_id',
          'payment_date',
          'created_at',
          'updated_at',
          'deleted_at',
          'is_overdue',
          'client',
          'invoice',
        ].contains(key) && value != null) {
          additionalData![key] = value;
        }
      });
    }
    
    return Instalment(
      id: json['id'] ?? 0,
      invoiceId: json['invoice_id'] ?? 0,
      number: json['number'] ?? 0,
      amount: amount,
      paidAmount: paidAmount,
      remainingAmount: remainingAmount,
      dueDate: json['due_date'] != null ? dateFormat.parse(json['due_date']) : DateTime.now(),
      status: json['status'] ?? 'pending',
      paymentId: json['payment_id'],
      paymentDate: json['payment_date'] != null ? parseDateTime(json['payment_date']) : null,
      createdAt: parseDateTime(json['created_at']),
      updatedAt: parseDateTime(json['updated_at']),
      isOverdue: json['is_overdue'] ?? false,
      additionalData: additionalData,
      invoice: invoiceObj,
      client: clientObj,
    );
  }

  Map<String, dynamic> toJson() {
    final dateFormat = DateFormat('yyyy-MM-dd');
    
    return {
      'id': id,
      'invoice_id': invoiceId,
      'number': number,
      'amount': amount,
      'paid_amount': paidAmount,
      'remaining_amount': remainingAmount,
      'due_date': dateFormat.format(dueDate),
      'status': status,
      'payment_id': paymentId,
      'payment_date': paymentDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_overdue': isOverdue,
      if (additionalData != null) ...additionalData!,
    };
  }
}

class InstalmentResponse {
  final List<Instalment> instalments;
  final Pagination? pagination;

  InstalmentResponse({
    required this.instalments,
    this.pagination,
  });

  factory InstalmentResponse.fromJson(Map<String, dynamic> json) {
    // Verificar si la respuesta contiene el campo 'instalments'
    if (json.containsKey('instalments')) {
      return InstalmentResponse(
        instalments: (json['instalments'] as List)
            .map((instalment) => Instalment.fromJson(instalment))
            .toList(),
        pagination: json.containsKey('pagination') 
            ? Pagination.fromJson(json['pagination']) 
            : null,
      );
    } else {
      // Si no hay campo 'instalments', devolver una lista vacía
      return InstalmentResponse(
        instalments: [],
        pagination: null,
      );
    }
  }
}
