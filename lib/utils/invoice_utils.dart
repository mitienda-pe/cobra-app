import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/invoice.dart';

/// Utilidad para obtener facturas con información de clientes incluida
class InvoiceUtils {
  static Future<List<Invoice>> fetchInvoicesWithClients({
    required Dio dio,
    required String baseUrl,
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    String? dateStart,
    String? dateEnd,
    int? clientId,
    int? portfolioId,
  }) async {
    try {
      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
        'include_clients': 'true', // Siempre incluir información de clientes
      };

      // Añadir parámetros opcionales si están presentes
      if (clientId != null) queryParams['client_id'] = clientId.toString();
      if (portfolioId != null) queryParams['portfolio_id'] = portfolioId.toString();
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;
      if (dateStart != null) queryParams['date_start'] = dateStart;
      if (dateEnd != null) queryParams['date_end'] = dateEnd;

      // Realizar la solicitud a la API
      final response = await dio.get(
        '$baseUrl/api/invoices',
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        
        // Verificar si la respuesta sigue el nuevo formato con status, message y data
        if (data is Map && 
            data.containsKey('status') && 
            data['status'] == 'success' &&
            data.containsKey('data')) {
          
          // Si la respuesta tiene el nuevo formato, extraer los datos
          final invoicesData = data['data']['invoices'] as List;
          return invoicesData.map((json) => Invoice.fromJson(json)).toList();
        } else if (data is Map && data.containsKey('invoices')) {
          // Si la respuesta tiene el formato anterior
          final invoicesData = data['invoices'] as List;
          return invoicesData.map((json) => Invoice.fromJson(json)).toList();
        }
      }
      
      // Si no se pudo procesar la respuesta, devolver una lista vacía
      return [];
    } catch (e) {
      print('Error al obtener facturas con clientes: $e');
      return [];
    }
  }

  /// Método para mostrar la información del cliente en la UI
  static Widget buildClientInfo(Invoice invoice) {
    if (invoice.client == null) {
      return const Text('Información de cliente no disponible');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Nombre: ${invoice.client!.businessName}'),
        Text('Documento: ${invoice.client!.documentNumber}'),
        if (invoice.client!.contactName.isNotEmpty)
          Text('Contacto: ${invoice.client!.contactName}'),
        if (invoice.client!.email.isNotEmpty)
          Text('Email: ${invoice.client!.email}'),
        if (invoice.client!.phone.isNotEmpty)
          Text('Teléfono: ${invoice.client!.phone}'),
      ],
    );
  }
}
