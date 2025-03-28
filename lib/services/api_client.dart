import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';
import '../services/storage_service.dart';
import '../config/app_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  
  late Dio dio;
  final StorageService _storageService = StorageService();
  
  factory ApiClient() {
    return _instance;
  }
  
  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: Duration(seconds: AppConfig.connectionTimeoutSeconds),
        receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    
    // Agregar interceptores
    dio.interceptors.add(_createAuthInterceptor());
    
    // Agregar interceptor de logging en modo debug
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }
  
  // Crear interceptor de autenticación
  Interceptor _createAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        // No interceptamos las solicitudes de autenticación excepto refresh token
        if (options.path.contains('/api/auth/') && 
            !options.path.contains('/api/auth/refresh-token')) {
          return handler.next(options);
        }
        
        // Obtenemos el token almacenado
        final token = await _storageService.getToken();
        
        if (token != null) {
          // Si el token está expirado, intentamos renovarlo
          if (token.isExpired) {
            try {
              final newToken = await _refreshToken(token.refreshToken);
              
              if (newToken != null) {
                // Actualizamos el token en el almacenamiento
                await _storageService.saveToken(newToken);
                
                // Actualizamos el header con el nuevo token
                options.headers['Authorization'] = 'Bearer ${newToken.accessToken}';
              } else {
                // Si no se pudo renovar el token, eliminamos los datos de autenticación
                await _storageService.clearAll();
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error al renovar token: $e');
              }
              await _storageService.clearAll();
            }
          } else {
            // Si el token es válido, lo incluimos en la solicitud
            options.headers['Authorization'] = 'Bearer ${token.accessToken}';
          }
        }
        
        return handler.next(options);
      },
      onError: (DioException error, handler) async {
        // Si recibimos un error 401 (Unauthorized), limpiamos los datos de autenticación
        if (error.response?.statusCode == 401) {
          await _storageService.clearAll();
        }
        return handler.next(error);
      },
    );
  }
  
  // Método para renovar el token
  Future<AuthToken?> _refreshToken(String refreshToken) async {
    try {
      final response = await dio.post(
        '/api/auth/refresh-token',
        data: {
          'refresh_token': refreshToken,
        },
      );
      
      if (response.statusCode == 200) {
        return AuthToken.fromJson(response.data);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error en _refreshToken: $e');
      }
      return null;
    }
  }
}
