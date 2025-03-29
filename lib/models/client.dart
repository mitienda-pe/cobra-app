import 'package:latlong2/latlong.dart';

class Client {
  final int id;
  final String? uuid;
  final String businessName;
  final String documentNumber;
  final String contactName;
  final String email;
  final String phone;
  final String address;
  final String status;
  final double? latitude;
  final double? longitude;
  final int organizationId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int invoicesCount;
  final double invoicesAmount;

  Client({
    required this.id,
    this.uuid,
    required this.businessName,
    required this.documentNumber,
    required this.contactName,
    required this.email,
    required this.phone,
    required this.address,
    required this.status,
    this.latitude,
    this.longitude,
    required this.organizationId,
    required this.createdAt,
    required this.updatedAt,
    this.invoicesCount = 0,
    this.invoicesAmount = 0,
  });

  LatLng? get location {
    if (latitude != null && longitude != null) {
      return LatLng(latitude!, longitude!);
    }
    return null;
  }

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: json['id'],
      uuid: json['uuid'],
      businessName: json['business_name'] ?? 'Sin nombre',
      documentNumber: json['document_number'] ?? 'Sin documento',
      contactName: json['contact_name'] ?? 'Sin contacto',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      address: json['address'] ?? '',
      status: json['status'] ?? 'active',
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      organizationId: json['organization_id'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : DateTime.now(),
      invoicesCount: json['invoices_count'] ?? 0,
      invoicesAmount: json['invoices_amount'] ?? 0.0,
    );
  }
}

class ClientResponse {
  final bool success;
  final List<Client> clients;
  final Pagination? pagination;

  ClientResponse({
    required this.success,
    required this.clients,
    this.pagination,
  });

  factory ClientResponse.fromJson(Map<String, dynamic> json) {
    List<Client> clientsList = [];
    if (json['clients'] != null) {
      clientsList = List<Client>.from(
        json['clients'].map((client) => Client.fromJson(client))
      );
    }

    return ClientResponse(
      success: json['success'] ?? true,
      clients: clientsList,
      pagination: json['pagination'] != null 
          ? Pagination.fromJson(json['pagination']) 
          : null,
    );
  }
}

class Pagination {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  Pagination({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      currentPage: json['current_page'],
      lastPage: json['last_page'],
      perPage: json['per_page'],
      total: json['total'],
    );
  }
}
