import 'package:flutter/foundation.dart';
import '../models/account.dart';
import '../models/payment.dart';
import '../models/invoice.dart';
import '../services/api_service.dart';

class AccountProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
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
  
  Future<void> loadAccounts() async {
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
      
      final invoiceResponse = await _apiService.getInvoices();
      
      if (invoiceResponse != null) {
        _accounts = _convertInvoicesToAccounts(invoiceResponse.invoices);
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
  
  List<Account> _convertInvoicesToAccounts(List<Invoice> invoices) {
    return invoices.map((invoice) {
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
      
      // Crear un objeto Customer a partir de los datos del cliente en la factura
      final customer = Customer(
        id: invoice.clientId.toString(),
        commercialName: invoice.clientName,
        legalName: invoice.clientName, // Usar el mismo nombre como nombre legal
        ruc: invoice.documentNumber,
        contact: Contact(
          name: invoice.clientName,
          address: "Dirección no disponible", // Podría ser actualizado si la API proporciona esta información
          phone: "Teléfono no disponible", // Podría ser actualizado si la API proporciona esta información
          location: null, // Podría ser actualizado si la API proporciona esta información
        ),
      );
      
      // Crear un objeto Account a partir de la factura
      return Account(
        id: invoice.id.toString(),
        customer: customer,
        concept: invoice.concept,
        expirationDate: invoice.dueDate,
        totalAmount: invoice.amount,
        paidAmount: invoice.paymentsAmount,
        status: status,
        payments: [], // Los pagos podrían ser cargados por separado si es necesario
      );
    }).toList();
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
