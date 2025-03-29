import 'package:flutter/foundation.dart';
import '../models/client.dart';
import '../services/api_service.dart';

class ClientProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Client> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<int, Client> _clientsCache = {}; // Cache de clientes por ID
  
  List<Client> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  ClientProvider() {
    // No cargar clientes automáticamente al iniciar
    // Se cargarán después de la autenticación
  }
  
  Future<void> loadClients({int? portfolioId, String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      // Verificar si hay un token en los headers de la API
      bool hasToken = _apiService.hasAuthToken();
      
      if (!hasToken) {
        _isLoading = false;
        _errorMessage = "No hay sesión activa. Por favor inicie sesión.";
        notifyListeners();
        return;
      }
      
      final clientResponse = await _apiService.getClients(
        portfolioId: portfolioId,
        search: search,
      );
      
      if (clientResponse != null) {
        _clients = clientResponse.clients;
        
        // Actualizar el cache de clientes
        for (var client in _clients) {
          _clientsCache[client.id] = client;
        }
        
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      } else {
        _isLoading = false;
        _errorMessage = "No se pudieron cargar los clientes";
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Error al cargar los clientes: $e";
      if (kDebugMode) {
        print(_errorMessage);
      }
      notifyListeners();
    }
  }
  
  // Obtener un cliente por su ID, primero del cache, luego de la API si es necesario
  Future<Client?> getClientById(int clientId) async {
    // Verificar si el cliente está en el cache
    if (_clientsCache.containsKey(clientId)) {
      return _clientsCache[clientId];
    }
    
    // Si no está en el cache, obtenerlo de la API
    try {
      final client = await _apiService.getClientById(clientId);
      
      if (client != null) {
        // Actualizar el cache
        _clientsCache[clientId] = client;
        return client;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener cliente por ID: $e');
      }
    }
    
    return null;
  }
}
