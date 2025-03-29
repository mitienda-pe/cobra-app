import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../models/invoice_account.dart';
import '../models/payment.dart';
import '../providers/invoice_account_provider.dart';

class RegisterPaymentScreen extends StatefulWidget {
  final String invoiceAccountId;
  
  const RegisterPaymentScreen({super.key, required this.invoiceAccountId});

  @override
  State<RegisterPaymentScreen> createState() => _RegisterPaymentScreenState();
}

class _RegisterPaymentScreenState extends State<RegisterPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reconciliationCodeController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  double _cashChange = 0.0;
  
  @override
  void dispose() {
    _amountController.dispose();
    _reconciliationCodeController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context);
    final invoiceAccount = invoiceAccountProvider.getInvoiceAccountById(widget.invoiceAccountId);
    
    final currencyFormat = NumberFormat.currency(
      locale: 'es_PE',
      symbol: 'S/',
      decimalDigits: 2,
    );
    
    // Inicializar el monto con el monto pendiente si no se ha inicializado aún
    if (_amountController.text.isEmpty) {
      _amountController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoice-account-detail/${widget.invoiceAccountId}'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información de la factura
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
                        invoiceAccount.customer.commercialName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        invoiceAccount.concept,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
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
                                currencyFormat.format(invoiceAccount.totalAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Monto Pendiente',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                currencyFormat.format(invoiceAccount.remainingAmount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Formulario de pago
              Text(
                'Información del Pago',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              
              // Monto a pagar
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}$'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Monto a Pagar',
                        prefixText: 'S/ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Ingrese un monto';
                        }
                        
                        final amount = double.tryParse(value);
                        if (amount == null) {
                          return 'Monto inválido';
                        }
                        
                        if (amount <= 0) {
                          return 'El monto debe ser mayor a 0';
                        }
                        
                        if (amount > invoiceAccount.remainingAmount) {
                          return 'El monto no puede ser mayor al pendiente';
                        }
                        
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          // Actualizar el vuelto si el método es efectivo
                          if (_selectedMethod == PaymentMethod.cash) {
                            _updateCashChange();
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _amountController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
                        
                        // Actualizar el vuelto si el método es efectivo
                        if (_selectedMethod == PaymentMethod.cash) {
                          _updateCashChange();
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Pago Total'),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Método de pago
              Text(
                'Método de Pago',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              
              // Opciones de método de pago
              Row(
                children: [
                  _buildPaymentMethodOption(
                    method: PaymentMethod.cash,
                    icon: Icons.money,
                    label: 'Efectivo',
                  ),
                  _buildPaymentMethodOption(
                    method: PaymentMethod.transfer,
                    icon: Icons.account_balance,
                    label: 'Transferencia',
                  ),
                  _buildPaymentMethodOption(
                    method: PaymentMethod.pos,
                    icon: Icons.credit_card,
                    label: 'POS',
                  ),
                  _buildPaymentMethodOption(
                    method: PaymentMethod.qr,
                    icon: Icons.qr_code,
                    label: 'QR',
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Campos específicos según el método de pago
              if (_selectedMethod == PaymentMethod.cash) ...[
                // Campos para pago en efectivo
                TextFormField(
                  controller: _cashReceivedController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}$'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Monto Recibido',
                    prefixText: 'S/ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el monto recibido';
                    }
                    
                    final cashReceived = double.tryParse(value);
                    if (cashReceived == null) {
                      return 'Monto inválido';
                    }
                    
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    if (cashReceived < amount) {
                      return 'El monto recibido debe ser mayor o igual al monto a pagar';
                    }
                    
                    return null;
                  },
                  onChanged: (_) {
                    _updateCashChange();
                  },
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Vuelto',
                    prefixText: 'S/ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                  ),
                  child: Text(
                    _cashChange.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                // Campo para código de conciliación (transferencia, POS, QR)
                TextFormField(
                  controller: _reconciliationCodeController,
                  decoration: InputDecoration(
                    labelText: _getReconciliationLabel(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingrese el código de conciliación';
                    }
                    return null;
                  },
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Botón de registro de pago
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _registerPayment(context, invoiceAccount);
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
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodOption({
    required PaymentMethod method,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedMethod == method;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMethod = method;
            
            // Limpiar campos específicos
            if (method != PaymentMethod.cash) {
              _cashReceivedController.clear();
              _cashChange = 0.0;
            } else {
              _reconciliationCodeController.clear();
              _updateCashChange();
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withOpacity(0.2)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  String _getReconciliationLabel() {
    switch (_selectedMethod) {
      case PaymentMethod.transfer:
        return 'Código de Operación';
      case PaymentMethod.pos:
        return 'Número de Voucher';
      case PaymentMethod.qr:
        return 'Código de Transacción';
      default:
        return 'Código de Conciliación';
    }
  }
  
  void _updateCashChange() {
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
    
    setState(() {
      _cashChange = cashReceived > amount ? cashReceived - amount : 0.0;
    });
  }
  
  void _registerPayment(BuildContext context, InvoiceAccount invoiceAccount) {
    if (_formKey.currentState!.validate()) {
      final amount = double.parse(_amountController.text);
      final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
      
      // Crear objeto de pago según el método
      final payment = Payment(
        id: 'p${DateTime.now().millisecondsSinceEpoch}',
        invoiceAccountId: invoiceAccount.id,
        amount: amount,
        date: DateTime.now(),
        method: _selectedMethod,
        reconciliationCode: _selectedMethod != PaymentMethod.cash
            ? _reconciliationCodeController.text
            : null,
        cashReceived: _selectedMethod == PaymentMethod.cash
            ? double.parse(_cashReceivedController.text)
            : null,
        cashChange: _selectedMethod == PaymentMethod.cash ? _cashChange : null,
      );
      
      // Registrar el pago
      invoiceAccountProvider.addPayment(invoiceAccount.id, payment);
      
      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pago de ${amount.toStringAsFixed(2)} registrado con éxito'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Regresar a la pantalla de detalle
      Navigator.pop(context);
    }
  }
}
