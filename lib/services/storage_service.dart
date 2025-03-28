import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_token.dart';
import '../models/user.dart';
import '../config/app_config.dart';

class StorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Guardar token de autenticación
  Future<void> saveToken(AuthToken token) async {
    await _storage.write(
      key: AppConfig.tokenStorageKey,
      value: jsonEncode(token.toJson()),
    );
  }
  
  // Obtener token de autenticación
  Future<AuthToken?> getToken() async {
    final tokenJson = await _storage.read(key: AppConfig.tokenStorageKey);
    if (tokenJson != null) {
      return AuthToken.fromJson(jsonDecode(tokenJson));
    }
    return null;
  }
  
  // Guardar datos del usuario
  Future<void> saveUser(User user) async {
    await _storage.write(
      key: AppConfig.userStorageKey,
      value: jsonEncode(user.toJson()),
    );
  }
  
  // Obtener datos del usuario
  Future<User?> getUser() async {
    final userJson = await _storage.read(key: AppConfig.userStorageKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }
  
  // Limpiar todos los datos almacenados
  Future<void> clearAll() async {
    await _storage.delete(key: AppConfig.tokenStorageKey);
    await _storage.delete(key: AppConfig.userStorageKey);
  }
}
