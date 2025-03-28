import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';
import '../services/storage_service.dart';

class AuthInterceptor extends Interceptor {
  final Dio dio;
  final StorageService storageService;
  bool _isRefreshing = false;
  
  AuthInterceptor({
    required this.dio,
    required this.storageService,
  });
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    // No interceptamos las solicitudes de autenticación
    if (options.path.contains('/api/auth/') && 
        !options.path.contains('/api/auth/refresh-token')) {
      return handler.next(options);
    }
    
    // Obtenemos el token almacenado
    final token = await storageService.getToken();
    
    if (token != null) {
      // Si el token está expirado, intentamos renovarlo
      if (token.isExpired && !_isRefreshing) {
        try {
          _isRefreshing = true;
          final newToken = await _refreshToken(token.refreshToken);
          
          if (newToken != null) {
            // Actualizamos el token en el almacenamiento
            await storageService.saveToken(newToken);
            
            // Actualizamos el header con el nuevo token
            options.headers['Authorization'] = 'Bearer ${newToken.accessToken}';
          } else {
            // Si no se pudo renovar el token, eliminamos los datos de autenticación
            await storageService.clearAll();
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error al renovar token: $e');
          }
          await storageService.clearAll();
        } finally {
          _isRefreshing = false;
        }
      } else if (!token.isExpired) {
        // Si el token es válido, lo incluimos en la solicitud
        options.headers['Authorization'] = 'Bearer ${token.accessToken}';
      }
    }
    
    return handler.next(options);
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Si recibimos un error 401 (Unauthorized), limpiamos los datos de autenticación
    if (err.response?.statusCode == 401) {
      storageService.clearAll();
    }
    return handler.next(err);
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
