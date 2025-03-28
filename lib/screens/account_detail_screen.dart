import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/account.dart';
import '../models/payment.dart';
import '../models/invoice.dart';
import '../providers/account_provider.dart';
import '../services/api_service.dart';

class AccountDetailScreen extends StatefulWidget {
  final String accountId;
  
  const AccountDetailScreen({super.key, required this.accountId});

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> {
  final ApiService _apiService = ApiService();
  List<Invoice>? _invoices;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInvoices();
  }

  Future<void> _fetchInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtener el ID del cliente desde el account
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      final account = accountProvider.getAccountById(widget.accountId);
      
      // Llamar a la API para obtener las facturas
      final response = await _apiService.getInvoices(
        clientId: int.tryParse(account.customer.id),
      );

      setState(() {
        _invoices = response?.invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar las facturas: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<AccountProvider>(context);
    final account = accountProvider.getAccountById(widget.accountId);
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_PE',
      symbol: 'S/',
      decimalDigits: 2,
    );
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/accounts'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tarjeta de información del cliente
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withOpacity(0.2),
                          radius: 24,
                          child: Icon(
                            Icons.business,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.customer.commercialName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'RUC: ${account.customer.ruc}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      'Razón Social',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      account.customer.legalName,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Contacto',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      account.customer.contact.name,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Dirección',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      account.customer.contact.address,
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Teléfono',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          account.customer.contact.phone,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.phone),
                          color: Theme.of(context).primaryColor,
                          onPressed: () {
                            // Implementar llamada telefónica
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.message),
                          color: Theme.of(context).primaryColor,
                          onPressed: () {
                            // Implementar envío de mensaje
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Tarjeta de información de la cuenta
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Información de la Cuenta',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Concepto',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                account.concept,
                                style: const TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fecha de Vencimiento',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                dateFormat.format(account.expirationDate),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: account.isExpired ? Colors.red : null,
                                  fontWeight: account.isExpired ? FontWeight.bold : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estado',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              _buildStatusChip(account),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monto Total',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                currencyFormat.format(account.totalAmount),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (account.status == AccountStatus.partiallyPaid) ...[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Monto Pendiente',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  currencyFormat.format(account.remainingAmount),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (account.status == AccountStatus.partiallyPaid) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: account.paidAmount / account.totalAmount,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pagado: ${currencyFormat.format(account.paidAmount)} (${(account.paidAmount / account.totalAmount * 100).toStringAsFixed(0)}%)',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Historial de pagos
            if (account.payments.isNotEmpty) ...[
              Text(
                'Historial de Pagos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: account.payments.length,
                itemBuilder: (context, index) {
                  final payment = account.payments[index];
                  return _buildPaymentItem(payment, dateFormat, currencyFormat);
                },
              ),
              const SizedBox(height: 16),
            ],
            
            // Sección de facturas
            Text(
              'Facturas por Cobrar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            
            // Mostrar indicador de carga, error o lista de facturas
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                child: Column(
                  children: [
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _fetchInvoices,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_invoices == null || _invoices!.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No hay facturas disponibles para este cliente.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _invoices!.length,
                itemBuilder: (context, index) {
                  final invoice = _invoices![index];
                  return _buildInvoiceItem(invoice, dateFormat, currencyFormat);
                },
              ),
          ],
        ),
      ),
      bottomNavigationBar: account.status != AccountStatus.paid
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).go('/register-payment/${account.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Registrar Pago',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            )
          : null,
    );
  }
  
  Widget _buildStatusChip(Account account) {
    Color color;
    String text;
    
    switch (account.status) {
      case AccountStatus.paid:
        color = Colors.green;
        text = 'Pagado';
        break;
      case AccountStatus.partiallyPaid:
        color = Colors.orange;
        text = 'Pago Parcial';
        break;
      case AccountStatus.expired:
        color = Colors.red;
        text = 'Vencido';
        break;
      case AccountStatus.pending:
        color = account.isExpired ? Colors.red : Colors.blue;
        text = account.isExpired ? 'Vencido' : 'Pendiente';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  Widget _buildPaymentItem(
    Payment payment,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    IconData methodIcon;
    String methodName;
    
    switch (payment.method) {
      case PaymentMethod.cash:
        methodIcon = Icons.money;
        methodName = 'Efectivo';
        break;
      case PaymentMethod.transfer:
        methodIcon = Icons.account_balance;
        methodName = 'Transferencia';
        break;
      case PaymentMethod.pos:
        methodIcon = Icons.credit_card;
        methodName = 'POS';
        break;
      case PaymentMethod.qr:
        methodIcon = Icons.qr_code;
        methodName = 'QR';
        break;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.2),
              radius: 20,
              child: Icon(
                methodIcon,
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    methodName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    dateFormat.format(payment.date),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  if (payment.reconciliationCode != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Código: ${payment.reconciliationCode}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              currencyFormat.format(payment.amount),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInvoiceItem(
    Invoice invoice,
    DateFormat dateFormat,
    NumberFormat currencyFormat,
  ) {
    Color statusColor;
    String statusText;
    
    switch (invoice.status) {
      case 'paid':
        statusColor = Colors.green;
        statusText = 'Pagado';
        break;
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = 'Cancelado';
        break;
      case 'rejected':
        statusColor = Colors.red.shade800;
        statusText = 'Rechazado';
        break;
      case 'pending':
        statusColor = invoice.isExpired ? Colors.red : Colors.blue;
        statusText = invoice.isExpired ? 'Vencido' : 'Pendiente';
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'Pendiente';
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              invoice.concept,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vencimiento',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      dateFormat.format(invoice.dueDate),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: invoice.isExpired ? Colors.red : null,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Monto',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      currencyFormat.format(invoice.amount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (invoice.paymentsCount > 0) ...[
              const SizedBox(height: 8),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pagos realizados: ${invoice.paymentsCount}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Pagado',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        currencyFormat.format(invoice.paymentsAmount),
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: invoice.paymentsAmount / invoice.amount,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Pendiente: ${currencyFormat.format(invoice.remainingAmount)}',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            if (invoice.status == 'pending') ...[
              ElevatedButton(
                onPressed: () {
                  GoRouter.of(context).go('/register-payment/${invoice.id}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  minimumSize: const Size(double.infinity, 36),
                ),
                child: const Text('Registrar Pago'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
