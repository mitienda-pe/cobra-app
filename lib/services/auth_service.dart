import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'storage_service.dart';

class AuthService {
  final ApiService _apiService = ApiService();
  final StorageService _storageService = StorageService();
  
  // Método para solicitar OTP
  Future<bool> requestOtp(String phoneNumber, {String method = 'sms'}) async {
    return await _apiService.requestOtp(phoneNumber, method: method);
  }
  
  // Método para verificar OTP y guardar el token
  Future<bool> verifyOtp(String phoneNumber, String code) async {
    final token = await _apiService.verifyOtp(phoneNumber, code);
    
    if (token != null) {
      // Guardar el token
      await _storageService.saveToken(token);
      
      // Configurar el token en el servicio API
      _apiService.setAuthToken(token.accessToken);
      
      // Obtener y guardar datos del usuario
      await _fetchAndSaveUserData();
      
      return true;
    }
    
    return false;
  }
  
  // Método para renovar el token JWT
  Future<bool> refreshToken() async {
    final currentToken = await _storageService.getToken();
    
    if (currentToken == null) {
      return false;
    }
    
    try {
      final newToken = await _apiService.refreshToken(currentToken.refreshToken);
      
      if (newToken != null) {
        // Guardar el nuevo token
        await _storageService.saveToken(newToken);
        
        // Configurar el nuevo token en el servicio API
        _apiService.setAuthToken(newToken.accessToken);
        
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al renovar el token: $e');
      }
    }
    
    return false;
  }
  
  // Método para obtener y guardar datos del usuario
  Future<User?> _fetchAndSaveUserData() async {
    try {
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        final user = User.fromJson(userData);
        await _storageService.saveUser(user);
        return user;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener datos del usuario: $e');
      }
      
      // Si hay un error al obtener los datos del usuario, intentar obtener
      // el usuario almacenado localmente para no bloquear el flujo de la aplicación
      try {
        final storedUser = await _storageService.getUser();
        if (storedUser != null) {
          return storedUser;
        }
      } catch (storageError) {
        if (kDebugMode) {
          print('Error al obtener usuario almacenado: $storageError');
        }
      }
    }
    return null;
  }
  
  // Método para verificar si hay un token válido almacenado
  Future<bool> hasValidToken() async {
    final token = await _storageService.getToken();
    
    if (token == null) {
      return false;
    }
    
    // Si el token está a punto de expirar, intentar renovarlo
    if (token.isExpired || token.isAboutToExpire) {
      return await refreshToken();
    }
    
    return !token.isExpired;
  }
  
  // Método para obtener el token almacenado
  Future<AuthToken?> getToken() async {
    return await _storageService.getToken();
  }
  
  // Método para obtener el usuario almacenado
  Future<User?> getUser() async {
    return await _storageService.getUser();
  }
  
  // Método para cerrar sesión
  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (e) {
      if (kDebugMode) {
        print('Error al cerrar sesión: $e');
      }
    } finally {
      _apiService.clearAuthToken();
      await _storageService.clearAll();
    }
  }
}
