import 'package:flutter/foundation.dart';
import '../models/auth_token.dart';

/// Servicio para simular funcionalidades en modo de desarrollo
class MockService {
  static const String mockOtpCode = '123456';
  
  /// Simula el envío de un OTP y muestra el código en la consola
  static Future<bool> sendMockOtp(String destination, {String method = 'sms'}) async {
    // Simular un pequeño retraso en la red
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (kDebugMode) {
      print('=================================================');
      print('🔑 CÓDIGO OTP SIMULADO ENVIADO A $destination:');
      print('🔑 CÓDIGO: $mockOtpCode');
      print('🔑 MÉTODO: $method');
      print('=================================================');
    }
    
    return true;
  }
  
  /// Verifica si un código OTP coincide con el código simulado y devuelve un token
  static Future<AuthToken?> verifyMockOtp(String phoneNumber, String code) async {
    // Simular un pequeño retraso en la red
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (code == mockOtpCode) {
      // Crear un token simulado
      final now = DateTime.now();
      final expiryDate = now.add(const Duration(hours: 1));
      
      return AuthToken(
        accessToken: 'mock_access_token_${now.millisecondsSinceEpoch}',
        refreshToken: 'mock_refresh_token_${now.millisecondsSinceEpoch}',
        expiryDate: expiryDate,
      );
    }
    
    return null;
  }
  
  /// Simula la obtención de datos del usuario actual
  static Future<Map<String, dynamic>> getMockCurrentUser() async {
    // Simular un pequeño retraso en la red
    await Future.delayed(const Duration(milliseconds: 800));
    
    return {
      'id': '1',
      'name': 'Usuario Demo',
      'email': 'demo@example.com',
      'phone_number': '+51987654321',
      'role': 'user',
      'profile_picture': null,
    };
  }
  
  /// Simula el cierre de sesión
  static Future<bool> mockLogout() async {
    // Simular un pequeño retraso en la red
    await Future.delayed(const Duration(milliseconds: 800));
    
    return true;
  }
}
