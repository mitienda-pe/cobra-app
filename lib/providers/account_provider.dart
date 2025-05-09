import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/payment.dart';
import '../models/invoice.dart';
import '../models/client.dart' as client_model;
import '../services/api_service.dart';
import 'client_provider.dart';

class AccountProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final ClientProvider _clientProvider = ClientProvider();
  List<Account> _accounts = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  List<Account> get pendingAccounts => _accounts
      .where((account) => 
          account.status == AccountStatus.pending || 
          account.status == AccountStatus.partiallyPaid)
      .toList();
  
  List<Account> get expiredAccounts => _accounts
      .where((account) => account.isExpired && account.status != AccountStatus.paid)
      .toList();
  
  AccountProvider() {
    // No cargar cuentas automáticamente al iniciar
    // Se cargarán después de la autenticación
  }
  
  Future<void> loadAccounts({String? status, String? dateStart, String? dateEnd}) async {
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
      
      final invoiceResponse = await _apiService.getInvoices(
        status: status,
        dateStart: dateStart,
        dateEnd: dateEnd,
        includeClients: true, // Incluir información de clientes
      );
      
      if (invoiceResponse != null) {
        // Convertir las facturas a cuentas
        _accounts = await _convertInvoicesToAccounts(invoiceResponse.invoices);
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      } else {
        _isLoading = false;
        _errorMessage = "No se pudieron cargar las facturas";
        notifyListeners();
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = "Error al cargar las facturas: $e";
      if (kDebugMode) {
        print(_errorMessage);
      }
      notifyListeners();
    }
  }
  
  Future<List<Account>> _convertInvoicesToAccounts(List<Invoice> invoices) async {
    List<Account> accounts = [];
    
    // Primero, cargar los clientes para tener la información disponible
    await _clientProvider.loadClients();
    
    for (var invoice in invoices) {
      // Determinar el estado de la cuenta basado en los datos de la factura
      AccountStatus status;
      if (invoice.isPaid) {
        status = AccountStatus.paid;
      } else if (invoice.isExpired) {
        status = AccountStatus.expired;
      } else if (invoice.paymentsAmount > 0) {
        status = AccountStatus.partiallyPaid;
      } else {
        status = AccountStatus.pending;
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
      
      // Crear un objeto Account a partir de la factura
      accounts.add(Account(
        id: invoice.id.toString(),
        customer: customer,
        concept: invoice.concept,
        invoiceNumber: invoice.invoiceNumber,
        expirationDate: invoice.dueDate,
        totalAmount: invoice.amount,
        paidAmount: invoice.paymentsAmount,
        status: status,
        payments: [], // Los pagos podrían ser cargados por separado si es necesario
      ));
    }
    
    return accounts;
  }
  
  Account getAccountById(String id) {
    return _accounts.firstWhere((account) => account.id == id);
  }
  
  void addPayment(String accountId, Payment payment) {
    final index = _accounts.indexWhere((account) => account.id == accountId);
    if (index != -1) {
      final account = _accounts[index];
      final updatedPayments = [...account.payments, payment];
      final updatedPaidAmount = account.paidAmount + payment.amount;
      
      AccountStatus updatedStatus;
      if (updatedPaidAmount >= account.totalAmount) {
        updatedStatus = AccountStatus.paid;
      } else if (updatedPaidAmount > 0) {
        updatedStatus = AccountStatus.partiallyPaid;
      } else {
        updatedStatus = account.isExpired ? AccountStatus.expired : AccountStatus.pending;
      }
      
      _accounts[index] = Account(
        id: account.id,
        customer: account.customer,
        concept: account.concept,
        invoiceNumber: account.invoiceNumber,
        expirationDate: account.expirationDate,
        totalAmount: account.totalAmount,
        paidAmount: updatedPaidAmount,
        status: updatedStatus,
        payments: updatedPayments,
      );
      
      notifyListeners();
    }
  }
}
