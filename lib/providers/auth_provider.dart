import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'account_provider.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  
  bool _isAuthenticated = false;
  String _phoneNumber = '';
  User? _user;
  Map<String, dynamic>? _userData;
  
  bool get isAuthenticated => _isAuthenticated;
  String get phoneNumber => _phoneNumber;
  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  
  AuthProvider() {
    _initAuthState();
  }
  
  // Inicializar el estado de autenticación
  Future<void> _initAuthState() async {
    try {
      // Verificar si hay un token válido
      final hasToken = await _authService.hasValidToken();
      
      if (hasToken) {
        // Obtener usuario almacenado
        final user = await _authService.getUser();
        
        if (user != null) {
          _user = user;
          _phoneNumber = user.phoneNumber ?? '';
          _isAuthenticated = true;
          // Obtener datos adicionales del usuario
          await _fetchUserData();
          
          // Configurar el token en el ApiService
          final authToken = await _authService.getToken();
          if (authToken != null) {
            _apiService.setAuthToken(authToken.accessToken);
          }
          
          notifyListeners();
        } else {
          // Si tenemos token pero no usuario, intentamos obtener los datos del usuario
          await _fetchUserData();
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al inicializar estado de autenticación: $e');
      }
    }
  }
  
  // Obtener datos del usuario
  Future<void> _fetchUserData() async {
    try {
      // Obtener el modelo de usuario
      final user = await _authService.getUser();
      
      if (user != null) {
        _user = user;
        _phoneNumber = user.phoneNumber ?? '';
        _isAuthenticated = true;
      }
      
      // Obtener datos adicionales del usuario desde la API
      final userData = await _apiService.getCurrentUser();
      if (userData != null) {
        _userData = userData;
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener datos del usuario: $e');
      }
    }
  }
  
  // Método para solicitar OTP
  Future<bool> requestOTP(String phoneNumber, {String method = 'sms'}) async {
    _phoneNumber = phoneNumber;
    return await _authService.requestOtp(phoneNumber, method: method);
  }
  
  // Método para verificar OTP
  Future<bool> verifyOTP(String phoneNumber, String otp, {BuildContext? context}) async {
    // Actualizar el número de teléfono almacenado
    _phoneNumber = phoneNumber;
    
    try {
      final success = await _authService.verifyOtp(phoneNumber, otp);
      
      if (success) {
        _isAuthenticated = true;
        
        // Intentar obtener los datos del usuario, pero continuar incluso si falla
        try {
          await _fetchUserData();
        } catch (e) {
          if (kDebugMode) {
            print('Error al obtener datos del usuario después de verificar OTP: $e');
          }
          // No interrumpir el flujo de autenticación si hay un error al obtener los datos
        }
        
        // Cargar las facturas si tenemos un contexto
        if (context != null) {
          try {
            // Obtener el AccountProvider y cargar las facturas
            final accountProvider = Provider.of<AccountProvider>(context, listen: false);
            accountProvider.loadAccounts();
          } catch (e) {
            if (kDebugMode) {
              print('Error al cargar las facturas después de verificar OTP: $e');
            }
          }
        }
        
        notifyListeners();
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al verificar OTP: $e');
      }
    }
    
    return false;
  }
  
  // Método para cerrar sesión
  Future<void> logout() async {
    await _authService.logout();
    _isAuthenticated = false;
    _user = null;
    _userData = null;
    _phoneNumber = '';
    notifyListeners();
  }
  
  // Método para actualizar los datos del usuario
  Future<void> updateUserData() async {
    await _fetchUserData();
  }
}
