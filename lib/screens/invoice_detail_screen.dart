import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/invoice_account.dart';
import '../models/payment.dart';
import '../models/invoice.dart';
import '../providers/invoice_account_provider.dart';
import '../services/api_service.dart';
import '../utils/currency_formatter.dart';
import '../utils/logger.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceAccountId;

  const InvoiceDetailScreen({
    super.key,
    required this.invoiceAccountId,
  });

  @override
  InvoiceDetailScreenState createState() => InvoiceDetailScreenState();
}

class InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final ApiService _apiService = ApiService();
  List<Invoice>? _invoices;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchInvoices();
      }
    });
  }

  Future<void> _fetchInvoices() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final accountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
      final account = accountProvider.getInvoiceAccountById(widget.invoiceAccountId);
      
      Logger.info('Solicitando facturas para cliente UUID: ${account.customer.id} con include_clients=true');
      
      final response = await _apiService.getInvoices(
        clientUuid: account.customer.id, // Usar UUID en lugar de ID numérico
        includeClients: true, // Incluir información de clientes
      );

      if (response != null) {
        Logger.info('Facturas obtenidas: ${response.invoices.length}');
        
        final filteredInvoices = response.invoices.where((invoice) {
          return invoice.clientId.toString() == account.customer.id.toString();
        }).toList();
        
        Logger.info('Facturas filtradas del mismo cliente: ${filteredInvoices.length}');
        
        if (filteredInvoices.isNotEmpty) {
          final firstInvoice = filteredInvoices.first;
          Logger.info('Primera factura - ID: ${firstInvoice.id}, Número: ${firstInvoice.invoiceNumber}');
          Logger.info('Cliente en factura: ${firstInvoice.client != null ? "SÍ" : "NO"}');
          if (firstInvoice.client != null) {
            Logger.info('Datos del cliente: ID=${firstInvoice.client!.id}, Nombre=${firstInvoice.client!.businessName}');
          }
        }
        
        setState(() {
          _invoices = filteredInvoices;
          _isLoading = false;
        });
      } else {
        Logger.warning('No se recibió respuesta de facturas');
        setState(() {
          _invoices = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar las facturas: $e';
      });
      if (kDebugMode) {
        print(_errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
    final account = accountProvider.getInvoiceAccountById(widget.invoiceAccountId);
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    final invoice = _invoices?.isNotEmpty == true ? _invoices!.first : null;
    final currencyFormat = CurrencyFormatter.getCurrencyFormat(invoice?.currency);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Factura'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoices'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchInvoices,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Información del cliente
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).primaryColor.withAlpha(26), // 0.1 * 255 = 25.5 ≈ 26
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  account.customer.commercialName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                              _buildStatusChip(account),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'RUC: ${account.customer.ruc}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Contacto: ${account.customer.contact.name}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dirección: ${account.customer.contact.address}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Teléfono: ${account.customer.contact.phone}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    
                    // Información de la factura
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información de la Factura',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Número de Factura:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        account.invoiceNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Concepto:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          account.concept,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Fecha de Vencimiento:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        dateFormat.format(account.expirationDate),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: account.isExpired ? Colors.red : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Monto Total:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        currencyFormat.format(account.totalAmount),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (account.paidAmount > 0) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Monto Pagado:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(account.paidAmount),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Saldo Pendiente:',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          currencyFormat.format(account.remainingAmount),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: account.remainingAmount > 0 ? Colors.red : Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: account.paidAmount / account.totalAmount,
                                      backgroundColor: Colors.grey[200],
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Pagos realizados
                    if (account.payments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pagos Realizados',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: account.payments.length,
                              itemBuilder: (context, index) {
                                final payment = account.payments[index];
                                return _buildPaymentItem(payment, dateFormat, currencyFormat, invoice?.currency);
                              },
                            ),
                          ],
                        ),
                      ),
                    
                    // Facturas relacionadas
                    if (_invoices != null && _invoices!.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          const Text(
                            'Facturas relacionadas del mismo cliente',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _invoices!.length,
                            itemBuilder: (context, index) {
                              final invoice = _invoices![index];
                              // No mostrar la factura actual en la lista de facturas relacionadas
                              if (invoice.id.toString() == account.id.toString()) {
                                return const SizedBox.shrink();
                              }
                              return _buildInvoiceItem(invoice, dateFormat, currencyFormat, false);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),
      bottomNavigationBar: account.status != InvoiceAccountStatus.paid
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
  
  Widget _buildStatusChip(InvoiceAccount account) {
    Color color;
    String text;
    
    switch (account.status) {
      case InvoiceAccountStatus.paid:
        color = Colors.green;
        text = 'Pagado';
        break;
      case InvoiceAccountStatus.partiallyPaid:
        color = Colors.orange;
        text = 'Pago Parcial';
        break;
      case InvoiceAccountStatus.expired:
        color = Colors.red;
        text = 'Vencido';
        break;
      case InvoiceAccountStatus.pending:
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
        color: color.withAlpha(51), // 0.2 * 255 = 51
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
    [String? currency]
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
              backgroundColor: Colors.green.withAlpha(51), // 0.2 * 255 = 51
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
    [bool showPayButton = false]
  ) {
    // Use the invoice's currency for formatting
    final invoiceCurrencyFormat = CurrencyFormatter.getCurrencyFormat(invoice.currency);
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
      child: InkWell(
        onTap: () {
          // Navegar al detalle de esta factura
          GoRouter.of(context).go('/invoice-detail/${invoice.id}');
        },
        borderRadius: BorderRadius.circular(8),
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
                      color: statusColor.withAlpha(51), // 0.2 * 255 = 51
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
              _buildClientInfo(invoice),
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
                        invoiceCurrencyFormat.format(invoice.amount),
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
                          invoiceCurrencyFormat.format(invoice.paymentsAmount),
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
                      'Pendiente: ${invoiceCurrencyFormat.format(invoice.remainingAmount)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
              // Solo mostrar el botón de pago si showPayButton es true y la factura está pendiente
              if (showPayButton && invoice.status == 'pending') ...[
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    GoRouter.of(context).go('/register-payment/${invoice.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: const Size(double.infinity, 36),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Registrar Pago'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Método para construir la información del cliente
  Widget _buildClientInfo(Invoice invoice) {
    if (invoice.client == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Text(
          'Información de cliente no disponible',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Cliente: ${invoice.client!.businessName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Icon(Icons.badge, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Doc: ${invoice.client!.documentNumber}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          if (invoice.client!.contactName.isNotEmpty) Row(
            children: [
              Icon(Icons.person, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Contacto: ${invoice.client!.contactName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
