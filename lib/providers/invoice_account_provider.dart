import 'package:flutter/foundation.dart';
import '../models/invoice_account.dart';
import '../models/payment.dart';
import '../models/invoice.dart';
import '../models/client.dart' as client_model;
import '../services/api_service.dart';
import 'client_provider.dart';

class InvoiceAccountProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ClientProvider _clientProvider = ClientProvider();
  List<InvoiceAccount> _invoiceAccounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Variables para el sistema de caché
  DateTime? _lastFetchTime;
  bool _hasRegisteredPayment = false;
  
  // Tiempo de caché en minutos
  static const int _cacheTimeMinutes = 60;
  
  List<InvoiceAccount> get invoiceAccounts => _invoiceAccounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  List<InvoiceAccount> get pendingInvoiceAccounts => _invoiceAccounts
      .where((account) => 
          account.status == InvoiceAccountStatus.pending || 
          account.status == InvoiceAccountStatus.partiallyPaid)
      .toList();
  
  List<InvoiceAccount> get expiredInvoiceAccounts => _invoiceAccounts
      .where((account) => account.isExpired && account.status != InvoiceAccountStatus.paid)
      .toList();
  
  InvoiceAccountProvider() {
    // No cargar cuentas automáticamente al iniciar
    // Se cargarán después de la autenticación
  }
  
  // Método para verificar si es necesario recargar los datos
  bool _shouldRefreshData({bool forceRefresh = false}) {
    // Si se fuerza la recarga, siempre devolver true
    if (forceRefresh) return true;
    
    // Si se ha registrado un pago, es necesario recargar
    if (_hasRegisteredPayment) return true;
    
    // Si nunca se han cargado datos, es necesario recargar
    if (_lastFetchTime == null) return true;
    
    // Verificar si ha pasado el tiempo de caché
    final now = DateTime.now();
    final difference = now.difference(_lastFetchTime!);
    return difference.inMinutes >= _cacheTimeMinutes;
  }
  
  // Método para cargar las facturas con caché
  Future<void> loadInvoiceAccounts({
    String? status, 
    String? dateStart, 
    String? dateEnd,
    bool forceRefresh = false
  }) async {
    // Si no es necesario recargar los datos, retornar inmediatamente
    if (!_shouldRefreshData(forceRefresh: forceRefresh)) {
      print('Usando datos en caché. Última actualización: ${_lastFetchTime!.toIso8601String()}');
      return;
    }
    
    // Si ya está cargando, evitar múltiples peticiones simultáneas
    if (_isLoading) {
      print('Ya se está cargando datos, ignorando petición adicional');
      return;
    }
    
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
      
      // Limitar el número de intentos para evitar bucles infinitos
      int maxRetries = 1;
      int retryCount = 0;
      InvoiceResponse? invoiceResponse;
      
      while (invoiceResponse == null && retryCount <= maxRetries) {
        try {
          invoiceResponse = await _apiService.getInvoices(
            status: status,
            dateStart: dateStart,
            dateEnd: dateEnd,
            includeClients: true, // Incluir información de clientes
          );
          
          if (invoiceResponse == null && retryCount < maxRetries) {
            // Esperar un poco antes de reintentar
            await Future.delayed(const Duration(seconds: 1));
            retryCount++;
          }
        } catch (apiError) {
          print('Error al cargar facturas (intento ${retryCount + 1}): $apiError');
          if (retryCount < maxRetries) {
            await Future.delayed(const Duration(seconds: 1));
            retryCount++;
          } else {
            rethrow;
          }
        }
      }
      
      if (invoiceResponse != null) {
        // Convertir las facturas a cuentas
        _invoiceAccounts = await _convertInvoicesToAccounts(invoiceResponse.invoices);
        
        // Actualizar variables de caché
        _lastFetchTime = DateTime.now();
        _hasRegisteredPayment = false; // Reiniciar la bandera después de cargar
      } else {
        _errorMessage = "No se pudieron cargar las facturas después de varios intentos";
      }
    } catch (e) {
      print('Error al cargar facturas: $e');
      _errorMessage = "Error al cargar facturas: ${e.toString()}";
      // No limpiar la lista de facturas en caso de error para mantener los datos anteriores
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<List<InvoiceAccount>> _convertInvoicesToAccounts(List<Invoice> invoices) async {
    List<InvoiceAccount> accounts = [];
    
    for (var invoice in invoices) {
      // Determinar el estado de la cuenta
      InvoiceAccountStatus status;
      
      if (invoice.status == 'paid') {
        status = InvoiceAccountStatus.paid;
      } else if (invoice.paymentsAmount > 0) {
        status = InvoiceAccountStatus.partiallyPaid;
      } else {
        status = InvoiceAccountStatus.pending;
      }
      
      // Crear un objeto Customer a partir de los datos del cliente
      Customer customer;
      
      // Usar el cliente incluido en la factura si está disponible
      if (invoice.client != null) {
        // Si tenemos el cliente incluido en la factura, usamos esa información
        customer = Customer(
          id: invoice.client!.id.toString(),
          commercialName: invoice.client!.businessName,
          legalName: invoice.client!.businessName,
          ruc: invoice.client!.documentNumber,
          contact: Contact(
            name: invoice.client!.contactName,
            address: invoice.client!.address,
            phone: invoice.client!.phone,
            location: invoice.client!.location,
          ),
        );
      } else {
        // Intentar obtener información detallada del cliente solo si no está incluida en la factura
        client_model.Client? clientInfo = await _clientProvider.getClientById(invoice.clientId);
        
        if (clientInfo != null) {
          // Si tenemos información detallada del cliente, la usamos
          customer = Customer(
            id: clientInfo.id.toString(),
            commercialName: clientInfo.businessName,
            legalName: clientInfo.businessName,
            ruc: clientInfo.documentNumber,
            contact: Contact(
              name: clientInfo.contactName,
              address: clientInfo.address,
              phone: clientInfo.phone,
              location: clientInfo.location,
            ),
          );
        } else {
          // Si no tenemos información detallada, usamos los datos básicos de la factura
          customer = Customer(
            id: invoice.clientId.toString(),
            commercialName: invoice.clientName ?? "Cliente sin nombre",
            legalName: invoice.clientName ?? "Cliente sin nombre",
            ruc: invoice.documentNumber ?? "Sin documento",
            contact: Contact(
              name: invoice.clientName ?? "Cliente sin nombre",
              address: "Dirección no disponible",
              phone: "Teléfono no disponible",
              location: null,
            ),
          );
        }
      }
      
      // Crear un objeto InvoiceAccount a partir de la factura
      final account = InvoiceAccount(
        id: invoice.id.toString(),
        customer: customer,
        concept: invoice.concept,
        invoiceNumber: invoice.invoiceNumber,
        expirationDate: invoice.dueDate,
        totalAmount: invoice.amount,
        paidAmount: invoice.paymentsAmount,
        status: status,
        // Aquí se podrían agregar los pagos si estuvieran disponibles
        payments: [],
      );
      
      accounts.add(account);
    }
    
    return accounts;
  }
  
  InvoiceAccount getInvoiceAccountById(String id) {
    try {
      final account = _invoiceAccounts.firstWhere((account) => account.id == id);
      return account;
    } catch (e) {
      // Si no se encuentra la cuenta, lanzar una excepción más descriptiva
      throw Exception('No se encontró la factura con ID $id. Error: $e');
    }
  }
  
  Future<void> addPayment(String invoiceAccountId, Payment payment) async {
    try {
      // Buscar la factura
      final index = _invoiceAccounts.indexWhere((account) => account.id == invoiceAccountId);
      
      if (index != -1) {
        final currentAccount = _invoiceAccounts[index];
        
        // Convertir el método de pago a string para la API
        String paymentMethodString;
        switch (payment.method) {
          case PaymentMethod.cash:
            paymentMethodString = 'cash';
            break;
          case PaymentMethod.transfer:
            paymentMethodString = 'transfer';
            break;
          case PaymentMethod.pos:
            paymentMethodString = 'pos';
            break;
          case PaymentMethod.qr:
            paymentMethodString = 'qr';
            break;
        }
        
        // Enviar el pago al backend
        await _apiService.registerPayment(
          invoiceId: currentAccount.id,
          amount: payment.amount,
          paymentMethod: paymentMethodString,
          reconciliationCode: payment.reconciliationCode,
          cashReceived: payment.cashReceived,
          cashChange: payment.cashChange,
        );
        
        // Crear una nueva lista de pagos con el nuevo pago añadido
        final updatedPayments = List<Payment>.from(currentAccount.payments)..add(payment);
        
        // Calcular el nuevo monto pagado
        final newPaidAmount = currentAccount.paidAmount + payment.amount;
        
        // Determinar el nuevo estado
        InvoiceAccountStatus newStatus;
        if (newPaidAmount >= currentAccount.totalAmount) {
          newStatus = InvoiceAccountStatus.paid;
        } else if (newPaidAmount > 0) {
          newStatus = InvoiceAccountStatus.partiallyPaid;
        } else {
          newStatus = currentAccount.status;
        }
        
        // Crear un nuevo objeto InvoiceAccount con los valores actualizados
        final updatedAccount = InvoiceAccount(
          id: currentAccount.id,
          customer: currentAccount.customer,
          concept: currentAccount.concept,
          invoiceNumber: currentAccount.invoiceNumber,
          expirationDate: currentAccount.expirationDate,
          totalAmount: currentAccount.totalAmount,
          paidAmount: newPaidAmount,
          status: newStatus,
          payments: updatedPayments,
        );
        
        // Reemplazar la cuenta antigua con la actualizada
        _invoiceAccounts[index] = updatedAccount;
        
        // Marcar que se ha registrado un pago para forzar recarga en próxima solicitud
        _hasRegisteredPayment = true;
        
        // Notificar a los oyentes
        notifyListeners();
        
        // Actualizar la última vez que se cargaron las facturas para forzar una recarga en la próxima solicitud
        // pero no inmediatamente para evitar múltiples llamadas a la API
        _lastFetchTime = DateTime.now().subtract(const Duration(minutes: 55));
        
        print('Pago registrado con éxito: ${payment.amount} para la factura ${invoiceAccountId}');
        print('Monto pagado: ${updatedAccount.paidAmount}, Monto pendiente: ${updatedAccount.remainingAmount}');
      } else {
        throw Exception('No se encontró la factura con ID $invoiceAccountId');
      }
    } catch (e) {
      print('Error al registrar el pago: $e');
      rethrow; // Relanzar la excepción para que pueda ser manejada por el llamador
    }
  }
}
