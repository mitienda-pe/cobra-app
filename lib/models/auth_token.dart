import 'dart:convert';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthToken {
  final String accessToken;
  final String refreshToken;
  final DateTime expiryDate;

  AuthToken({
    required this.accessToken,
    required this.refreshToken,
    required this.expiryDate,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  
  // Verificar si el token expirará en menos de 5 minutos
  bool get isAboutToExpire {
    final now = DateTime.now();
    final timeUntilExpiry = expiryDate.difference(now);
    return timeUntilExpiry.inMinutes < 5 && !isExpired;
  }

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    // Verificar si la respuesta sigue el nuevo formato con 'data'
    if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
      final data = json['data'] as Map<String, dynamic>;
      
      // Extraer el token y la información de expiración
      final String token = data['token'] ?? '';
      final String expiresIn = data['expires_in'] ?? '30 days';
      
      // Calcular la fecha de expiración basada en 'expires_in'
      final DateTime expiryDate = _calculateExpiryDate(expiresIn);
      
      // Para el refreshToken, usamos el mismo token por ahora
      // En una implementación real, esto debería manejarse adecuadamente
      return AuthToken(
        accessToken: token,
        refreshToken: token, // Usar el mismo token como refreshToken
        expiryDate: expiryDate,
      );
    } else {
      // Formato anterior para compatibilidad
      try {
        // Decodificar el token para obtener la fecha de expiración
        final Map<String, dynamic> decodedToken = JwtDecoder.decode(json['access_token']);
        final int expTimestamp = decodedToken['exp'] * 1000; // Convertir a milisegundos
        
        return AuthToken(
          accessToken: json['access_token'],
          refreshToken: json['refresh_token'],
          expiryDate: DateTime.fromMillisecondsSinceEpoch(expTimestamp),
        );
      } catch (e) {
        // Si hay un error al decodificar, establecer una expiración predeterminada
        final now = DateTime.now();
        return AuthToken(
          accessToken: json['access_token'] ?? '',
          refreshToken: json['refresh_token'] ?? '',
          expiryDate: now.add(const Duration(days: 30)),
        );
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'expiry_date': expiryDate.toIso8601String(),
    };
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }
  
  // Método para calcular la fecha de expiración basada en una cadena como "30 days"
  static DateTime _calculateExpiryDate(String expiresIn) {
    final now = DateTime.now();
    
    // Extraer el número y la unidad de tiempo
    final RegExp regex = RegExp(r'(\d+)\s+(\w+)');
    final match = regex.firstMatch(expiresIn);
    
    if (match != null) {
      final int value = int.tryParse(match.group(1) ?? '0') ?? 0;
      final String unit = match.group(2) ?? '';
      
      switch (unit.toLowerCase()) {
        case 'minute':
        case 'minutes':
          return now.add(Duration(minutes: value));
        case 'hour':
        case 'hours':
          return now.add(Duration(hours: value));
        case 'day':
        case 'days':
          return now.add(Duration(days: value));
        case 'week':
        case 'weeks':
          return now.add(Duration(days: value * 7));
        case 'month':
        case 'months':
          return now.add(Duration(days: value * 30));
        default:
          return now.add(const Duration(days: 30)); // Valor predeterminado
      }
    }
    
    // Si no se puede analizar, usar un valor predeterminado
    return now.add(const Duration(days: 30));
  }
}
