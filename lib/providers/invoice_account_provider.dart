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
  
  Future<void> loadInvoiceAccounts({String? status, String? dateStart, String? dateEnd}) async {
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
        _invoiceAccounts = await _convertInvoicesToAccounts(invoiceResponse.invoices);
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
    return _invoiceAccounts.firstWhere(
      (account) => account.id == id,
      orElse: () => throw Exception('InvoiceAccount no encontrado con ID: $id'),
    );
  }
  
  Future<void> addPayment(String accountId, Payment payment) async {
    // Buscar la cuenta por ID
    final accountIndex = _invoiceAccounts.indexWhere((account) => account.id == accountId);
    
    if (accountIndex == -1) {
      throw Exception('InvoiceAccount no encontrado con ID: $accountId');
    }
    
    // Obtener la cuenta actual
    final currentAccount = _invoiceAccounts[accountIndex];
    
    // Crear una lista mutable de pagos
    final List<Payment> updatedPayments = List.from(currentAccount.payments)
      ..add(payment);
    
    // Calcular el nuevo monto pagado
    final double newPaidAmount = currentAccount.paidAmount + payment.amount;
    
    // Determinar el nuevo estado
    InvoiceAccountStatus newStatus;
    if (newPaidAmount >= currentAccount.totalAmount) {
      newStatus = InvoiceAccountStatus.paid;
    } else {
      newStatus = InvoiceAccountStatus.partiallyPaid;
    }
    
    // Crear una nueva cuenta con los pagos actualizados
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
    
    // Actualizar la lista de cuentas
    _invoiceAccounts[accountIndex] = updatedAccount;
    
    // Notificar a los oyentes
    notifyListeners();
  }
}
