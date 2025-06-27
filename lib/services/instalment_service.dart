import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/instalment.dart';
import '../utils/logger.dart';
import 'api_client.dart';
import 'api_service.dart';

class InstalmentService {
  final ApiClient _apiClient = ApiClient();
  final ApiService _apiService = ApiService();

  // Obtener cuotas pendientes de mis carteras
  Future<List<Instalment>> getMyInstalments({
    String status = 'pending',
    String dueDate = 'all',
    bool includeClient = true,
    bool includeInvoice = true,
    bool includeClientLocation = true,
  }) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible para obtener cuotas');
        }
        return [];
      }

      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {
        'status': status,
        'due_date': dueDate,
      };

      // Añadir parámetros opcionales
      if (includeClient) queryParams['include_client'] = 'true';
      if (includeInvoice) queryParams['include_invoice'] = 'true';
      if (includeClientLocation) {
        queryParams['include_client_location'] = 'true';
      }

      if (kDebugMode) {
        print('Query parameters: $queryParams');
      }

      // Realizar la solicitud a la API con la URL base completa y opciones de autenticación explícitas
      final response = await _apiClient.dio.get(
        '/api/portfolio/instalments',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        print('Respuesta completa de instalments: ${response.toString()}');
      }

      if (response.statusCode == 200) {
        // Verificar si la respuesta sigue el formato con status, message y data
        if (response.data is Map &&
            response.data.containsKey('status') &&
            response.data['status'] == 'success' &&
            response.data.containsKey('data')) {
          // Si la respuesta tiene el formato, extraer los datos
          final data = response.data['data'];

          // Verificar si data es una lista directamente (nuevo formato)
          if (data is List) {
            return data.map((item) => Instalment.fromJson(item)).toList();
          }

          // Verificar si la respuesta contiene el campo 'instalments'
          if (data is Map && data.containsKey('instalments')) {
            return (data['instalments'] as List)
                .map((item) => Instalment.fromJson(item))
                .toList();
          }
        } else if (response.data is Map &&
            response.data.containsKey('instalments')) {
          // Si la respuesta tiene el formato anterior
          return (response.data['instalments'] as List)
              .map((item) => Instalment.fromJson(item))
              .toList();
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error en getMyInstalments: $e');
      }
      return [];
    }
  }

  // Obtener cuotas de una factura
  Future<List<Instalment>> getInvoiceInstalments(
    String invoiceId, {
    bool includePayments = false,
    bool includeClient = false,
  }) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print(
            'No hay token de autenticación disponible para obtener cuotas de factura',
          );
        }
        return [];
      }

      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {};

      // Añadir parámetros opcionales
      if (includePayments) queryParams['include_payments'] = 'true';
      if (includeClient) queryParams['include_client'] = 'true';

      if (kDebugMode) {
        print('Query parameters: $queryParams');
      }

      // Realizar la solicitud a la API
      final response = await _apiClient.dio.get(
        '/api/instalments/invoice/$invoiceId',
        queryParameters: queryParams,
        options: _apiService.getAuthOptions(),
      );

      if (kDebugMode) {
        print(
          'Respuesta completa de instalments por factura: ${response.toString()}',
        );
      }

      if (response.statusCode == 200) {
        // Verificar si la respuesta sigue el formato con status, message y data
        if (response.data is Map &&
            response.data.containsKey('status') &&
            response.data['status'] == 'success' &&
            response.data.containsKey('data')) {
          // Si la respuesta tiene el formato, extraer los datos
          final data = response.data['data'];
          final instalmentResponse = InstalmentResponse.fromJson(data);
          return instalmentResponse.instalments;
        } else if (response.data is Map &&
            response.data.containsKey('instalments')) {
          // Si la respuesta tiene el formato directo
          final instalmentResponse = InstalmentResponse.fromJson(response.data);
          return instalmentResponse.instalments;
        }
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error en getInvoiceInstalments: $e');
      }
      return [];
    }
  }

  // Obtener detalles de una cuota específica
  Future<Instalment?> getInstalmentById(String instalmentId) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print(
            'No hay token de autenticación disponible para obtener detalles de cuota',
          );
        }
        return null;
      }

      // Asegurar que el cliente API está correctamente configurado
      if (!_apiClient.dio.options.headers.containsKey('Authorization') ||
          _apiClient.dio.options.headers['Authorization'] == null ||
          !_apiClient.dio.options.headers['Authorization'].toString().contains(
            token,
          )) {
        if (kDebugMode) {
          print(
            'Reestableciendo encabezados de autorización para la solicitud',
          );
        }

        // Establecer el encabezado de autorización manualmente
        _apiClient.dio.options.headers['Authorization'] = 'Bearer $token';
      }

      // Realizar la solicitud a la API
      final response = await _apiClient.dio.get(
        '/api/instalments/$instalmentId',
        options: _apiService.getAuthOptions(),
      );

      if (kDebugMode) {
        print(
          'Respuesta completa de detalles de cuota: ${response.toString()}',
        );
      }

      if (response.statusCode == 200) {
        try {
          // Verificar si la respuesta sigue el formato con status, message y data
          if (response.data is Map &&
              response.data.containsKey('status') &&
              response.data['status'] == 'success' &&
              response.data.containsKey('data')) {
            // Si la respuesta tiene el formato, extraer los datos
            final data = response.data['data'];
            if (kDebugMode) {
              print('Procesando datos de cuota: $data');
            }
            return Instalment.fromJson(data);
          } else if (response.data is Map &&
              response.data.containsKey('instalment')) {
            // Si la respuesta tiene el formato directo
            final data = response.data['instalment'];
            if (kDebugMode) {
              print('Procesando datos de cuota (formato alternativo): $data');
            }
            return Instalment.fromJson(data);
          } else {
            if (kDebugMode) {
              print('Formato de respuesta no reconocido: ${response.data}');
            }
          }
        } catch (parseError) {
          if (kDebugMode) {
            print('Error al procesar datos de cuota: $parseError');
            print('Datos recibidos: ${response.data}');
          }
        }
      } else {
        if (kDebugMode) {
          print('Error en la respuesta: ${response.statusCode}');
          print('Datos de error: ${response.data}');
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en getInstalmentById: $e');
        if (e is DioException && e.response != null) {
          print('ERROR DATA: ${e.response?.data}');

          // Si el error es 401 (No autorizado), podría ser un problema con el token
          if (e.response?.statusCode == 401) {
            print('Error de autorización. Posible token inválido o expirado.');
          }
        }
      }
      return null;
    }
  }

  // Obtener una cuota específica por su ID
  Future<Instalment?> getInstalment(
    int instalmentId, {
    bool includeClient = true,
    bool includeInvoice = true,
    bool includePayments = false,
  }) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token disponible para obtener la cuota');
        }
        return null;
      }

      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {};

      // Añadir parámetros opcionales - asegurarse de que coincidan con lo que espera el backend
      if (includeClient) queryParams['include_client'] = 'true';
      if (includeInvoice) queryParams['include_invoice'] = 'true';
      if (includePayments) queryParams['include_payments'] = 'true';

      // Añadir parámetros adicionales que podrían ser necesarios según la memoria compartida
      if (includeClient) {
        queryParams['include_clients'] = 'true'; // Formato alternativo que podría esperar el backend
      }

      // Use Logger instead of print for consistent logging
      Logger.debug('===== INSTALMENT SERVICE DEBUG =====');
      Logger.debug('Requesting instalment with ID: $instalmentId');
      Logger.debug(
        'Include client: $includeClient, Include invoice: $includeInvoice, Include payments: $includePayments',
      );
      Logger.debug('Token available: ${token.isNotEmpty}');
      Logger.debug('API endpoint: /api/instalments/$instalmentId');
      Logger.debug('Query parameters: $queryParams');

      // Realizar la solicitud a la API usando el endpoint específico para una cuota
      final response = await _apiClient.dio.get(
        '/api/instalments/$instalmentId',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        print('Response status code: ${response.statusCode}');
        print('Response data type: ${response.data.runtimeType}');
        if (response.data is Map) {
          print(
            'Response data keys: ${(response.data as Map).keys.join(', ')}',
          );

          if (response.data.containsKey('status')) {
            print('Response status: ${response.data['status']}');
          }

          if (response.data.containsKey('message')) {
            print('Response message: ${response.data['message']}');
          }

          if (response.data.containsKey('data')) {
            print('Data is present in response');
            if (response.data['data'] is Map) {
              print(
                'Data keys: ${(response.data['data'] as Map).keys.join(', ')}',
              );
            } else {
              print('Data is not a Map: ${response.data['data'].runtimeType}');
            }
          } else {
            print('No data key in response');
          }

          if (response.data.containsKey('instalment')) {
            print('Instalment is present in response');
            if (response.data['instalment'] is Map) {
              print(
                'Instalment keys: ${(response.data['instalment'] as Map).keys.join(', ')}',
              );
            } else {
              print(
                'Instalment is not a Map: ${response.data['instalment'].runtimeType}',
              );
            }
          } else {
            print('No instalment key in response');
          }
        }
        print('===== END INSTALMENT SERVICE DEBUG =====');
      }

      if (response.statusCode == 200) {
        // Verificar si la respuesta sigue el formato con status, message y data
        if (response.data is Map &&
            response.data.containsKey('status') &&
            response.data['status'] == 'success' &&
            response.data.containsKey('data')) {
          // Si la respuesta tiene el formato, extraer los datos
          final data = response.data['data'];

          // Asegurarnos de que tengamos la información de la factura
          if (includeInvoice &&
              data is Map &&
              !data.containsKey('invoice') &&
              data.containsKey('invoice_id')) {
            // Si no tenemos el objeto invoice pero tenemos el invoice_id, intentar obtener más datos
            if (data.containsKey('invoice_number')) {
              // Si tenemos el número de factura directamente en la respuesta, crear un objeto invoice básico
              if (!data.containsKey('invoice')) {
                data['invoice'] = {
                  'id': data['invoice_id'],
                  'invoice_number': data['invoice_number'],
                };
              }
            }
          }

          // Asegurarnos de que tengamos la información del cliente
          if (includeClient &&
              data is Map &&
              !data.containsKey('client') &&
              data.containsKey('client_id')) {
            // Si no tenemos el objeto client pero tenemos el client_id, intentar obtener más datos
            if (data.containsKey('client_business_name')) {
              // Si tenemos el nombre del cliente directamente en la respuesta, crear un objeto client básico
              if (!data.containsKey('client')) {
                data['client'] = {
                  'id': data['client_id'],
                  'business_name': data['client_business_name'],
                };
              }
            }
          }

          if (kDebugMode) {
            print('Creating Instalment from data: $data');
          }

          return Instalment.fromJson(data);
        } else if (response.data is Map &&
            response.data.containsKey('instalment')) {
          // Si la respuesta tiene el formato directo
          final data = response.data['instalment'];

          // Asegurarnos de que tengamos la información de la factura
          if (includeInvoice &&
              data is Map &&
              !data.containsKey('invoice') &&
              data.containsKey('invoice_id')) {
            // Si no tenemos el objeto invoice pero tenemos el invoice_id, intentar obtener más datos
            if (data.containsKey('invoice_number')) {
              // Si tenemos el número de factura directamente en la respuesta, crear un objeto invoice básico
              if (!data.containsKey('invoice')) {
                data['invoice'] = {
                  'id': data['invoice_id'],
                  'invoice_number': data['invoice_number'],
                };
              }
            }
          }

          // Asegurarnos de que tengamos la información del cliente
          if (includeClient &&
              data is Map &&
              !data.containsKey('client') &&
              data.containsKey('client_id')) {
            // Si no tenemos el objeto client pero tenemos el client_id, intentar obtener más datos
            if (data.containsKey('client_business_name')) {
              // Si tenemos el nombre del cliente directamente en la respuesta, crear un objeto client básico
              if (!data.containsKey('client')) {
                data['client'] = {
                  'id': data['client_id'],
                  'business_name': data['client_business_name'],
                };
              }
            }
          }

          if (kDebugMode) {
            print('Creating Instalment from instalment data: $data');
          }

          return Instalment.fromJson(data);
        } else {
          if (kDebugMode) {
            print('Response format not recognized: ${response.data}');
          }
        }
      } else {
        if (kDebugMode) {
          print(
            'Error response: ${response.statusCode} - ${response.statusMessage}',
          );
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en getInstalment: $e');
      }
      return null;
    }
  }

  // Crear cuotas para una factura
  Future<bool> createInstalments(
    String invoiceId,
    List<Map<String, dynamic>> instalmentData,
  ) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible para crear cuotas');
        }
        return false;
      }

      // Preparar datos para la solicitud
      final Map<String, dynamic> requestData = {
        'invoice_id': invoiceId,
        'instalments': instalmentData,
      };

      // Realizar la solicitud a la API
      final response = await _apiClient.dio.post(
        '/api/instalments/create',
        data: jsonEncode(requestData),
        options: _apiService.getAuthOptions(),
      );

      if (kDebugMode) {
        print(
          'Respuesta completa de creación de cuotas: ${response.toString()}',
        );
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('Error en createInstalments: $e');
      }
      return false;
    }
  }

  // Eliminar todas las cuotas de una factura
  Future<bool> deleteInvoiceInstalments(String invoiceId) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print(
            'No hay token de autenticación disponible para eliminar cuotas',
          );
        }
        return false;
      }

      // Realizar la solicitud a la API
      final response = await _apiClient.dio.delete(
        '/api/instalments/invoice/$invoiceId',
        options: _apiService.getAuthOptions(),
      );

      if (kDebugMode) {
        print(
          'Respuesta completa de eliminación de cuotas: ${response.toString()}',
        );
      }

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error en deleteInvoiceInstalments: $e');
      }
      return false;
    }
  }

  // Verificar si una cuota puede ser pagada
  bool canBePaid(Instalment instalment) {
    // Una cuota puede ser pagada si:
    // 1. Está en estado pendiente
    // 2. No está vencida (opcional, depende de las reglas de negocio)
    // 3. No tiene un paymentId asociado

    return instalment.status == 'pending' && instalment.paymentId == null;
  }

  // Registrar pago de una cuota
  Future<Map<String, dynamic>> registerInstalmentPayment({
    required String instalmentId,
    required double amount,
    required String paymentMethod,
    String? reconciliationCode,
    double? cashReceived,
    double? cashChange,
  }) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible para registrar pago');
        }
        return {'success': false, 'message': 'No hay sesión activa'};
      }

      // Primero, obtener los detalles de la cuota para conseguir el invoice_id
      final instalment = await getInstalmentById(instalmentId);

      if (instalment == null) {
        return {
          'success': false,
          'message': 'No se pudo obtener la información de la cuota',
        };
      }

      // Preparar datos para la solicitud
      final Map<String, dynamic> requestData = {
        'payment_type': 'instalment', // Especificar que es un pago de cuota
        'instalment_id': instalmentId,
        'invoice_id': instalment.invoiceId.toString(), // Añadir el invoice_id
        'amount': amount,
        'payment_method': paymentMethod,
        'payment_date': DateTime.now().toIso8601String(),
      };

      // Añadir información adicional del invoice si está disponible
      if (instalment.invoice != null) {
        requestData['invoice_uuid'] = instalment.invoice!.uuid;
        requestData['invoice_number'] = instalment.invoice!.invoiceNumber;
        requestData['client_id'] = instalment.invoice!.clientId.toString();
      }

      // Añadir información del cliente si está disponible
      if (instalment.client != null) {
        requestData['client_uuid'] = instalment.client!.uuid;
        requestData['client_business_name'] = instalment.client!.businessName;
      }

      // Añadir campos opcionales si están presentes
      if (reconciliationCode != null && reconciliationCode.isNotEmpty) {
        requestData['reconciliation_code'] = reconciliationCode;
      }

      if (cashReceived != null) {
        requestData['cash_received'] = cashReceived;
      }

      if (cashChange != null) {
        requestData['cash_change'] = cashChange;
      }

      if (kDebugMode) {
        print('Datos de solicitud para registro de pago: $requestData');
      }

      // Realizar la solicitud a la API
      final response = await _apiClient.dio.post(
        '/api/payments/register',
        data: jsonEncode(requestData),
        options: _apiService.getAuthOptions(),
      );

      if (kDebugMode) {
        print('Respuesta completa de registro de pago: ${response.toString()}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data is Map) {
          // Verificar si la respuesta tiene el formato con status y message
          if (response.data.containsKey('status') &&
              response.data['status'] == 'success') {
            return {
              'success': true,
              'message':
                  response.data['message'] ?? 'Pago registrado correctamente',
              'payment_id': response.data['data']?['payment_id'] ?? 'N/A',
            };
          }
          // Verificar si la respuesta tiene el formato con payment directamente
          else if (response.data.containsKey('payment')) {
            final payment = response.data['payment'];
            return {
              'success': true,
              'message': 'Pago registrado correctamente',
              'payment_id':
                  payment['id']?.toString() ?? payment['uuid'] ?? 'N/A',
            };
          }
          // Si no coincide con ningún formato conocido, devolver los datos tal cual
          return {
            'success': true,
            'message': 'Pago registrado',
            'data': response.data,
          };
        }
        return {'success': true, 'message': 'Pago registrado correctamente'};
      } else {
        return {'success': false, 'message': 'Error al registrar el pago'};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error en registerInstalmentPayment: $e');
      }
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Obtener cuotas de un portafolio específico (patrón RESTful)
  Future<List<Instalment>> getPortfolioInstalments(
    String portfolioUuid, {
    String status = 'pending',
    String dueDate = 'all',
    bool includeClient = true,
    bool includeInvoice = true,
  }) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print(
            'No hay token de autenticación disponible para obtener cuotas del portafolio',
          );
        }
        return [];
      }

      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {
        'status': status,
        'due_date': dueDate,
      };

      // Añadir parámetros opcionales
      if (includeClient) queryParams['include_client'] = 'true';
      if (includeInvoice) queryParams['include_invoice'] = 'true';

      if (kDebugMode) {
        print('Query parameters: $queryParams');
      }

      // Realizar la solicitud a la API usando el patrón RESTful
      final response = await _apiClient.dio.get(
        '/api/portfolio/$portfolioUuid/instalments',
        queryParameters: queryParams,
        options: _apiService.getAuthOptions(),
      );

      if (kDebugMode) {
        print(
          'Respuesta completa de instalments (RESTful): ${response.toString()}',
        );
      }

      if (response.statusCode == 200) {
        List<Instalment> instalments = [];

        // Verificar si la respuesta sigue el formato con status, message y data
        if (response.data is Map &&
            response.data.containsKey('status') &&
            response.data['status'] == 'success' &&
            response.data.containsKey('data')) {
          // Si la respuesta tiene el formato, extraer los datos
          final data = response.data['data'];

          // Verificar si la respuesta contiene el campo 'instalments'
          if (data.containsKey('instalments')) {
            instalments =
                (data['instalments'] as List)
                    .map((item) => Instalment.fromJson(item))
                    .toList();
          } else if (data is List) {
            // Si data es directamente una lista de cuotas
            instalments =
                data.map((item) => Instalment.fromJson(item)).toList();
          }
        } else if (response.data is Map &&
            response.data.containsKey('instalments')) {
          // Si la respuesta tiene el formato anterior
          instalments =
              (response.data['instalments'] as List)
                  .map((item) => Instalment.fromJson(item))
                  .toList();
        }

        return instalments;
      }

      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Error en getPortfolioInstalments: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return [];
    }
  }

  // Generar código QR dinámico para pago de cuota
  Future<Map<String, dynamic>> generateInstalmentQR(String instalmentId) async {
    try {
      // Verificar si hay un token disponible
      String? token = _apiService.getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay sesión activa para generar QR');
        }
        return {'success': false, 'message': 'No hay sesión activa'};
      }

      // Asegurar que el cliente API está correctamente configurado
      if (!_apiClient.dio.options.headers.containsKey('Authorization') ||
          _apiClient.dio.options.headers['Authorization'] == null ||
          !_apiClient.dio.options.headers['Authorization'].toString().contains(
            token,
          )) {
        if (kDebugMode) {
          print(
            'Reestableciendo encabezados de autorización para la solicitud de QR',
          );
        }

        // Establecer el encabezado de autorización manualmente
        _apiClient.dio.options.headers['Authorization'] = 'Bearer $token';
      }

      // Obtener los detalles de la cuota
      try {
        final instalment = await getInstalmentById(instalmentId);

        if (instalment == null) {
          if (kDebugMode) {
            print(
              'No se pudo obtener la información de la cuota ID: $instalmentId',
            );
          }
          return {
            'success': false,
            'message': 'No se encontró la cuota especificada',
          };
        }

        // Obtener el monto pendiente de la cuota
        final double amount = instalment.remainingAmount;

        if (kDebugMode) {
          print(
            'Generando QR para pago de cuota ID: $instalmentId, monto: $amount',
          );
        }

        // Intentar con la ruta correcta según la documentación
        try {
          // Usar la ruta exacta para generar QR para cuotas
          if (kDebugMode) {
            print(
              'Generando QR para cuota ID: $instalmentId con monto: $amount',
            );
          }

          final response = await _apiClient.dio.get(
            '/api/payments/generate-instalment-qr/$instalmentId',
            queryParameters: {'amount': amount.toString()},
            options: _apiService.getAuthOptions(),
          );

          if (kDebugMode) {
            print('*** Request ***');
            print('uri: ${response.requestOptions.uri}');
            print('method: ${response.requestOptions.method}');
            print('responseType: ${response.requestOptions.responseType}');
            print(
              'followRedirects: ${response.requestOptions.followRedirects}',
            );
            print(
              'persistentConnection: ${response.requestOptions.persistentConnection}',
            );
            print('connectTimeout: ${response.requestOptions.connectTimeout}');
            print('sendTimeout: ${response.requestOptions.sendTimeout}');
            print('receiveTimeout: ${response.requestOptions.receiveTimeout}');
            print(
              'receiveDataWhenStatusError: ${response.requestOptions.receiveDataWhenStatusError}',
            );
            Logger.debug('extra: ${response.requestOptions.extra}');
            Logger.debug('headers:');
            response.requestOptions.headers.forEach((key, value) {
              Logger.debug(' $key: $value');
            });
            Logger.debug('data:');
            Logger.debug('${response.requestOptions.data}');
            Logger.debug('');
          }

          if (response.statusCode == 200) {
            if (kDebugMode) {
              print('QR generado exitosamente: ${response.data}');
            }
            return _processQRResponse(response);
          } else {
            if (kDebugMode) {
              print(
                'Error al generar QR: ${response.statusCode} - ${response.data}',
              );
            }
            return {
              'success': false,
              'message': 'Error al generar QR: ${response.statusCode}',
            };
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error al generar QR: $e');
            if (e is DioException && e.response != null) {
              print('ERROR DATA: ${e.response?.data}');

              // Si el error es 401 (No autorizado), podría ser un problema con el token
              if (e.response?.statusCode == 401) {
                print(
                  'Error de autorización al generar QR. Posible token inválido o expirado.',
                );
                return {
                  'success': false,
                  'message':
                      'Sesión expirada. Por favor, vuelva a iniciar sesión.',
                };
              }
            }
          }

          return {
            'success': false,
            'message': 'Error al generar el código QR: ${e.toString()}',
          };
        }
      } catch (instalmentError) {
        if (kDebugMode) {
          print('Error al obtener detalles de la cuota: $instalmentError');
        }
        return {
          'success': false,
          'message':
              'Error al obtener detalles de la cuota: ${instalmentError.toString()}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error general al generar QR: $e');
      }

      return {
        'success': false,
        'message': 'Error al generar el código QR: ${e.toString()}',
      };
    }
  }

  // Método auxiliar para procesar la respuesta del QR
  Map<String, dynamic> _processQRResponse(Response response) {
    if (kDebugMode) {
      print('Procesando respuesta QR: ${response.data}');
    }

    if (response.data is Map) {
      // Formato como en el ejemplo proporcionado
      if (response.data.containsKey('success') &&
          response.data['success'] == true) {
        return {
          'success': true,
          'qr_data': response.data['qr_data'] ?? '',
          'qr_image_url': response.data['qr_image_url'] ?? '',
          'order_id': response.data['order_id'] ?? '',
          'expiration': response.data['expiration'] ?? '',
        };
      }
      // Formato alternativo con 'status'
      else if (response.data.containsKey('status') &&
          response.data['status'] == 'success') {
        final data =
            response.data.containsKey('data')
                ? response.data['data']
                : response.data;
        return {
          'success': true,
          'qr_data': data['qr_data'] ?? '',
          'qr_image_url': data['qr_image_url'] ?? '',
          'order_id': data['order_id'] ?? '',
          'expiration': data['expiration'] ?? '',
        };
      }
      // Si la respuesta tiene directamente la URL del QR
      else if (response.data.containsKey('qr_image_url') ||
          response.data.containsKey('qr_data')) {
        return {
          'success': true,
          'qr_data': response.data['qr_data'] ?? '',
          'qr_image_url': response.data['qr_image_url'] ?? '',
          'order_id': response.data['order_id'] ?? response.data['id'] ?? '',
          'expiration': response.data['expiration'] ?? '',
        };
      }
      // Si la respuesta tiene un mensaje de error
      else if (response.data.containsKey('message') ||
          response.data.containsKey('error')) {
        final errorMessage =
            response.data['message'] ??
            response.data['error'] ??
            'Error desconocido';
        if (kDebugMode) {
          print('Error en la respuesta del servidor: $errorMessage');
        }
        return {'success': false, 'message': errorMessage};
      }
      // Caso para cualquier otro formato de respuesta
      else {
        if (kDebugMode) {
          print('Formato de respuesta no reconocido: ${response.data}');
        }
        return {
          'success': false,
          'message': 'Formato de respuesta no reconocido',
          'data': response.data,
        };
      }
    }
    return {'success': false, 'message': 'Formato de respuesta no reconocido'};
  }
}
