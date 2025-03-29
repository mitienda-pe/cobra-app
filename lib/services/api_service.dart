import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/auth_token.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import 'api_client.dart';
import 'mock_service.dart';
import 'package:dio/dio.dart';

class ApiService {
  static const String baseUrl = 'https://cobra.mitienda.host';

  final ApiClient _apiClient = ApiClient();

  // Flag para usar servicios simulados en desarrollo
  // Temporalmente establecido a false para probar el envío real de SMS
  final bool _useMockServices = false; // kDebugMode;

  Map<String, dynamic>? _lastUserData;

  ApiService() {
    // Configurar encabezados por defecto para todas las solicitudes
    _apiClient.dio.options.headers['Accept'] = 'application/json';
    _apiClient.dio.options.headers['Content-Type'] = 'application/json';

    // Configurar interceptores para depuración
    if (kDebugMode) {
      _apiClient.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            print('REQUEST[${options.method}] => PATH: ${options.path}');
            print('REQUEST HEADERS: ${options.headers}');
            print('REQUEST DATA: ${options.data}');
            return handler.next(options);
          },
          onResponse: (response, handler) {
            print('RESPONSE[${response.statusCode}] => PATH: ${response.requestOptions.path}');
            print('RESPONSE DATA: ${response.data}');
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            print('ERROR[${e.response?.statusCode}] => PATH: ${e.requestOptions.path}');
            print('ERROR MESSAGE: ${e.message}');
            print('ERROR DATA: ${e.response?.data}');
            return handler.next(e);
          },
        ),
      );
    }
  }

  // Método para configurar el token de autenticación
  void setAuthToken(String token) {
    _apiClient.dio.options.headers['Authorization'] = 'Bearer $token';
  }

  // Método para eliminar el token de autenticación
  void clearAuthToken() {
    _apiClient.dio.options.headers.remove('Authorization');
  }

  // Método para verificar si hay un token de autenticación configurado
  bool hasAuthToken() {
    return _apiClient.dio.options.headers.containsKey('Authorization') &&
           _apiClient.dio.options.headers['Authorization'] != null &&
           _apiClient.dio.options.headers['Authorization'].toString().startsWith('Bearer ');
  }

  // Método para obtener el token actual
  String? getCurrentToken() {
    if (hasAuthToken()) {
      final authHeader = _apiClient.dio.options.headers['Authorization'] as String;
      return authHeader.substring(7); // Eliminar 'Bearer ' del inicio
    }
    return null;
  }

  // Método para obtener información del dispositivo
  Future<String> _getDeviceInfo() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      Map<String, dynamic> deviceData = {};

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceData = {
          'platform': 'Android',
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'version': androidInfo.version.release,
          'sdk': androidInfo.version.sdkInt.toString(),
          'id': androidInfo.id,
        };
      } else if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        deviceData = {
          'platform': 'iOS',
          'model': iosInfo.model,
          'name': iosInfo.name,
          'systemName': iosInfo.systemName,
          'systemVersion': iosInfo.systemVersion,
          'identifierForVendor': iosInfo.identifierForVendor,
        };
      } else {
        deviceData = {
          'platform': Platform.operatingSystem,
          'version': Platform.operatingSystemVersion,
        };
      }

      return jsonEncode(deviceData);
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener información del dispositivo: $e');
      }
      // Devolver información básica en caso de error
      return jsonEncode({
        'platform': Platform.operatingSystem,
        'error': 'No se pudo obtener información detallada',
      });
    }
  }

  // Método para solicitar un código OTP
  Future<bool> requestOtp(String phoneNumber, {String method = 'sms'}) async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        return await MockService.sendMockOtp(phoneNumber, method: method);
      }

      // Obtener información del dispositivo
      String deviceInfo = await _getDeviceInfo();

      // En producción, llamar a la API real
      final response = await _apiClient.dio.post(
        '/index.php/api/auth/request-otp',
        data: jsonEncode({
          'phone': phoneNumber, 
          'device_info': deviceInfo,
          'organization_code': '263274', // Código de organización por defecto, podría ser configurable
        }),
      );

      if (kDebugMode) {
        print('Respuesta completa: ${response.toString()}');
      }

      // Verificar si la respuesta tiene el formato esperado
      if (response.statusCode == 200) {
        if (response.data is Map && 
            response.data.containsKey('status') && 
            response.data['status'] == 'success') {
          return true;
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error en requestOtp: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return false;
    }
  }

  // Método para verificar un código OTP
  Future<AuthToken?> verifyOtp(String phoneNumber, String code) async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        final authToken = await MockService.verifyMockOtp(phoneNumber, code);
        if (authToken != null) {
          // Configurar el token en los headers para futuras solicitudes
          setAuthToken(authToken.accessToken);
        }
        return authToken;
      }

      // Obtener información del dispositivo
      String deviceInfo = await _getDeviceInfo();

      // En producción, llamar a la API real
      final response = await _apiClient.dio.post(
        '/index.php/api/auth/verify-otp',
        data: jsonEncode({
          'phone': phoneNumber, 
          'code': code,
          'device_info': deviceInfo,
        }),
      );

      if (response.statusCode == 200) {
        // Guardar los datos del usuario para uso posterior
        if (response.data is Map && 
            response.data.containsKey('data') && 
            response.data['data'] is Map && 
            response.data['data'].containsKey('user')) {
          _lastUserData = response.data['data']['user'];
        }
        
        // Crear objeto AuthToken a partir de la respuesta
        final authToken = AuthToken.fromJson(response.data);
        
        // Configurar el token en los headers para futuras solicitudes
        setAuthToken(authToken.accessToken);
        
        return authToken;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en verifyOtp: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return null;
    }
  }

  // Método para renovar el token JWT
  Future<AuthToken?> refreshToken(String refreshToken) async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        // Crear un token simulado renovado
        final now = DateTime.now();
        final expiryDate = now.add(const Duration(hours: 1));

        final authToken = AuthToken(
          accessToken: 'mock_access_token_refreshed_${now.millisecondsSinceEpoch}',
          refreshToken: 'mock_refresh_token_${now.millisecondsSinceEpoch}',
          expiryDate: expiryDate,
        );
        
        // Configurar el token en los headers para futuras solicitudes
        setAuthToken(authToken.accessToken);
        
        return authToken;
      }

      // En producción, llamar a la API real
      final response = await _apiClient.dio.post(
        '/index.php/api/auth/refresh-token',
        data: jsonEncode({
          'refresh_token': refreshToken,
        }),
      );

      if (response.statusCode == 200) {
        final authToken = AuthToken.fromJson(response.data);
        
        // Configurar el token en los headers para futuras solicitudes
        setAuthToken(authToken.accessToken);
        
        return authToken;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en refreshToken: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return null;
    }
  }

  // Método para obtener datos del usuario actual
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        return await MockService.getMockCurrentUser();
      }

      // Si tenemos datos del usuario guardados de la verificación OTP, usarlos
      if (_lastUserData != null) {
        return _lastUserData;
      }

      // Obtener el token actual de los headers
      String? token = getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible');
        }
        return null;
      }

      // Intentar obtener los datos del usuario desde la API usando el nuevo endpoint
      try {
        final response = await _apiClient.dio.get(
          '/index.php/api/auth/profile',
          queryParameters: {'token': token},
        );
        
        if (response.statusCode == 200) {
          // Si la respuesta contiene datos en el formato nuevo
          if (response.data is Map && 
              response.data.containsKey('data') && 
              response.data['data'] is Map) {
            return response.data['data'];
          }
          return response.data;
        }
      } catch (apiError) {
        if (kDebugMode) {
          print('Error al obtener datos del usuario desde la API: $apiError');
        }
      }

      // Si no se pudieron obtener los datos, devolver null
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en getCurrentUser: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return null;
    }
  }

  // Método para cerrar sesión
  Future<bool> logout() async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        return await MockService.mockLogout();
      }

      // Verificar si hay un token disponible
      String? token = getCurrentToken();
      
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible para cerrar sesión');
        }
        return false;
      }

      // En producción, llamar a la API real con el token como parámetro de consulta
      final response = await _apiClient.dio.post(
        '/index.php/api/auth/logout',
        queryParameters: {'token': token},
      );

      // Si la respuesta es exitosa, limpiar el token
      if (response.statusCode == 200) {
        clearAuthToken();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error en logout: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return false;
    }
  }

  // Método para obtener facturas (invoices) de la cartera del usuario
  Future<InvoiceResponse?> getInvoices({
    int? clientId,
    String? clientUuid,
    int? portfolioId,
    String? status,
    String? search,
    String? dateStart,
    String? dateEnd,
    int page = 1,
    int limit = 20,
    bool includeClients = false,
  }) async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        // Implementar mock service para invoices si es necesario
        return null;
      }

      // Obtener el token actual de los headers
      String? token = getCurrentToken();
      
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible para obtener facturas');
        }
        return null;
      }

      // Construir parámetros de consulta
      final Map<String, dynamic> queryParams = {
        'page': page.toString(),
        'limit': limit.toString(),
      };

      // Añadir parámetros opcionales si están presentes
      if (clientId != null) queryParams['client_id'] = clientId.toString();
      if (clientUuid != null) queryParams['client_uuid'] = clientUuid;
      if (portfolioId != null) queryParams['portfolio_id'] = portfolioId.toString();
      if (status != null) queryParams['status'] = status;
      if (search != null) queryParams['search'] = search;
      if (dateStart != null) queryParams['date_start'] = dateStart;
      if (dateEnd != null) queryParams['date_end'] = dateEnd;
      if (includeClients) queryParams['include_clients'] = 'true';

      // Realizar la solicitud a la API con la nueva ruta
      try {
        final response = await _apiClient.dio.get(
          '/index.php/api/invoices',
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
          print('Respuesta completa de invoices: ${response.toString()}');
        }

        if (response.statusCode == 200) {
          // Verificar si la respuesta sigue el nuevo formato con status, message y data
          if (response.data is Map && 
              response.data.containsKey('status') && 
              response.data['status'] == 'success' &&
              response.data.containsKey('data')) {
            
            // Si la respuesta tiene el nuevo formato, extraer los datos
            final data = response.data['data'];
            return InvoiceResponse.fromJson(data);
          } else {
            // Si la respuesta tiene el formato anterior
            return InvoiceResponse.fromJson(response.data);
          }
        }
      } catch (apiError) {
        if (kDebugMode) {
          print('Error al obtener facturas: $apiError');
          if (apiError is DioException && apiError.response != null) {
            print('Código de estado: ${apiError.response?.statusCode}');
            print('Datos de respuesta: ${apiError.response?.data}');
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error general en getInvoices: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return null;
    }
  }

  // Método para obtener una factura específica por ID
  Future<Map<String, dynamic>?> getInvoiceById(int invoiceId) async {
    try {
      // En modo desarrollo, usar servicio simulado
      if (_useMockServices) {
        // Implementar mock service para invoice detail si es necesario
        return null;
      }

      // Obtener el token actual de los headers
      String? token = getCurrentToken();

      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          print('No hay token de autenticación disponible para obtener detalles de factura');
        }
        return null;
      }

      // Realizar la solicitud a la API con la ruta actualizada
      try {
        final response = await _apiClient.dio.get(
          '/index.php/api/invoices/$invoiceId',
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );
        
        if (kDebugMode) {
          print('Respuesta completa de invoice por ID: ${response.toString()}');
        }

        if (response.statusCode == 200) {
          // Verificar si la respuesta sigue el nuevo formato con status, message y data
          if (response.data is Map && 
              response.data.containsKey('status') && 
              response.data['status'] == 'success' &&
              response.data.containsKey('data')) {
            
            // Si la respuesta tiene el nuevo formato, extraer los datos
            return response.data['data'];
          } else {
            // Si la respuesta tiene el formato anterior
            return response.data;
          }
        }
      } catch (apiError) {
        if (kDebugMode) {
          print('Error al obtener factura por ID: $apiError');
          if (apiError is DioException && apiError.response != null) {
            print('Código de estado: ${apiError.response?.statusCode}');
            print('Datos de respuesta: ${apiError.response?.data}');
          }
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error general en getInvoiceById: $e');
        if (e is DioException && e.response != null) {
          print('Código de estado: ${e.response?.statusCode}');
          print('Datos de respuesta: ${e.response?.data}');
        }
      }
      return null;
    }
  }

  // Método para obtener las facturas del usuario
  Future<InvoiceResponse?> getInvoicesFromUser({
    String? status, 
    String? dateStart, 
    String? dateEnd,
    bool includeClients = false
  }) async {
    try {
      Map<String, dynamic> queryParams = {};
      
      if (status != null && status.isNotEmpty) {
        queryParams['status'] = status;
      }
      
      if (dateStart != null && dateStart.isNotEmpty) {
        queryParams['date_start'] = dateStart;
      }
      
      if (dateEnd != null && dateEnd.isNotEmpty) {
        queryParams['date_end'] = dateEnd;
      }
      
      if (includeClients) {
        queryParams['include_clients'] = 'true';
      }
      
      final response = await _apiClient.dio.get('/index.php/api/invoices', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        return InvoiceResponse.fromJson(response.data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener facturas: $e');
      }
    }
    
    return null;
  }

  // Método para obtener los clientes del usuario
  Future<ClientResponse?> getClients({int? portfolioId, String? search, int page = 1, int limit = 20}) async {
    try {
      Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit
      };
      
      if (portfolioId != null) {
        queryParams['portfolio_id'] = portfolioId;
      }
      
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      
      final response = await _apiClient.dio.get('/index.php/api/clients', queryParameters: queryParams);
      
      if (response.statusCode == 200) {
        return ClientResponse.fromJson(response.data);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener clientes: $e');
      }
    }
    
    return null;
  }

  // Método para obtener un cliente específico por su ID
  Future<Client?> getClientById(int clientId) async {
    try {
      final response = await _apiClient.dio.get('/index.php/api/clients/$clientId');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Client.fromJson(response.data['client']);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener cliente por ID: $e');
      }
    }
    
    return null;
  }
}
