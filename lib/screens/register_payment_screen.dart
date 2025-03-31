import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/payment.dart';
import '../providers/invoice_account_provider.dart';
import '../models/invoice_account.dart';

class RegisterPaymentScreen extends StatefulWidget {
  final String invoiceAccountId;
  
  const RegisterPaymentScreen({
    super.key,
    required this.invoiceAccountId,
  });
  
  @override
  State<RegisterPaymentScreen> createState() => _RegisterPaymentScreenState();
}

class _RegisterPaymentScreenState extends State<RegisterPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reconciliationCodeController = TextEditingController();
  final _cashReceivedController = TextEditingController();
  
  // Formato para moneda (S/ 0.00)
  final currencyFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
  );
  
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  double _cashChange = 0.0;
  double _remainingAfterPayment = 0.0;
  bool _isProcessingInput = false;
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    
    // Inicializar el monto pendiente después del pago
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
          final invoiceAccount = invoiceAccountProvider.getInvoiceAccountById(widget.invoiceAccountId);
          
          // Inicializar el monto a pagar con el monto pendiente
          _amountController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
          
          // Inicializar el monto recibido para pagos en efectivo
          _cashReceivedController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
          
          // Actualizar los cálculos
          _updateRemainingAmount(invoiceAccount);
          _updateCashChange();
        } catch (e) {
          print('Error al inicializar pantalla de pagos: $e');
          // No hacer nada más, simplemente evitar que la app se bloquee
        }
      }
    });
    
    // Agregar listeners a los controladores de texto
    _amountController.addListener(_onAmountChanged);
    _cashReceivedController.addListener(_updateCashChange);
  }
  
  @override
  void dispose() {
    // Eliminar listeners para evitar fugas de memoria
    _amountController.removeListener(_onAmountChanged);
    _cashReceivedController.removeListener(_updateCashChange);
    
    // Liberar controladores
    _amountController.dispose();
    _cashReceivedController.dispose();
    _reconciliationCodeController.dispose();
    
    super.dispose();
  }
  
  void _onAmountChanged() {
    if (mounted) {
      final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
      final invoiceAccount = invoiceAccountProvider.getInvoiceAccountById(widget.invoiceAccountId);
      _updateRemainingAmount(invoiceAccount);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context);
    final invoiceAccount = invoiceAccountProvider.getInvoiceAccountById(widget.invoiceAccountId);
    
    // Inicializar el monto con el monto pendiente si no se ha inicializado aún
    if (_amountController.text.isEmpty) {
      _amountController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/invoice-detail/${widget.invoiceAccountId}'),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Registrando pago...'),
                ],
              ),
            )
          : SingleChildScrollView(
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
              
              // Mostrar información sobre el monto pendiente después del pago
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información del pago',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monto pendiente actual:'),
                        Text(
                          '${currencyFormat.format(invoiceAccount.remainingAmount)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Monto a pagar:'),
                        Text(
                          '${currencyFormat.format(double.tryParse(_amountController.text) ?? 0.0)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Quedará pendiente:'),
                        Text(
                          '${currencyFormat.format(_remainingAfterPayment)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _remainingAfterPayment > 0 ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedMethod == PaymentMethod.cash) ...[
                      const SizedBox(height: 4),
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Monto recibido:'),
                          Text(
                            '${currencyFormat.format(double.tryParse(_cashReceivedController.text) ?? 0.0)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cambio a devolver:'),
                          Text(
                            '${currencyFormat.format(_cashChange)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _cashChange > 0 ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
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
                        helperText: 'Puede ser menor al monto pendiente (pago parcial)',
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
                        if (mounted && !_isProcessingInput) {
                          _isProcessingInput = true;
                          // Usar Future.delayed para reducir la frecuencia de actualizaciones
                          Future.delayed(const Duration(milliseconds: 300), () {
                            if (mounted) {
                              setState(() {
                                // Actualizar el vuelto si el método es efectivo
                                if (_selectedMethod == PaymentMethod.cash) {
                                  _updateCashChange();
                                }
                                // Actualizar el monto pendiente después del pago
                                _updateRemainingAmount(invoiceAccount);
                              });
                            }
                            _isProcessingInput = false;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted && !_isProcessingInput) {
                        _isProcessingInput = true;
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            setState(() {
                              _amountController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
                              
                              // Actualizar el vuelto si el método es efectivo
                              if (_selectedMethod == PaymentMethod.cash) {
                                _updateCashChange();
                              }
                              // Actualizar el monto pendiente después del pago
                              _updateRemainingAmount(invoiceAccount);
                            });
                          }
                          _isProcessingInput = false;
                        });
                      }
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
              TextFormField(
                controller: _cashReceivedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'^\d+\.?\d{0,2}$'),
                  ),
                ],
                decoration: InputDecoration(
                  labelText: _selectedMethod == PaymentMethod.cash ? 'Monto Recibido en Efectivo' : 'Monto Recibido',
                  prefixText: 'S/ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '0.00',
                  helperText: _selectedMethod == PaymentMethod.cash 
                      ? 'Debe ser al menos igual al monto a pagar (para calcular el cambio)' 
                      : 'Monto recibido por este método de pago',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ingrese el monto recibido';
                  }
                  
                  final cashReceived = double.tryParse(value);
                  if (cashReceived == null) {
                    return 'Monto inválido';
                  }
                  
                  // Para pagos en efectivo, verificar que el monto recibido sea suficiente
                  if (_selectedMethod == PaymentMethod.cash) {
                    final amount = double.tryParse(_amountController.text) ?? 0.0;
                    
                    // El monto recibido debe ser al menos igual al monto a pagar
                    // para poder calcular el cambio correctamente
                    if (cashReceived < amount) {
                      return 'El monto recibido debe ser al menos igual al monto a pagar';
                    }
                  }
                  
                  return null;
                },
                onChanged: (_) {
                  if (mounted && !_isProcessingInput) {
                    _isProcessingInput = true;
                    // Usar Future.delayed para reducir la frecuencia de actualizaciones
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        _updateCashChange();
                        _updateRemainingAmount(
                          Provider.of<InvoiceAccountProvider>(context, listen: false)
                              .getInvoiceAccountById(widget.invoiceAccountId)
                        );
                      }
                      _isProcessingInput = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              if (_selectedMethod == PaymentMethod.cash) ...[
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
              ],
              const SizedBox(height: 16),
              if (_selectedMethod != PaymentMethod.cash) ...[
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
                  onPressed: _isLoading ? null : () => _registerPayment(context, invoiceAccount),
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
            
            // Si cambiamos a efectivo, verificar que el monto recibido sea suficiente
            if (method == PaymentMethod.cash) {
              final amount = double.tryParse(_amountController.text) ?? 0.0;
              final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
              
              // Si el monto recibido es menor que el monto a pagar, actualizarlo
              // para evitar errores de validación
              if (cashReceived < amount) {
                _cashReceivedController.text = amount.toStringAsFixed(2);
              }
              
              _updateCashChange();
            }
          });
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    if (!mounted) return;
    
    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final cashReceived = double.tryParse(_cashReceivedController.text) ?? 0.0;
      
      setState(() {
        _cashChange = _selectedMethod == PaymentMethod.cash ? 
          (cashReceived > amount ? cashReceived - amount : 0.0) : 0.0;
      });
    } catch (e) {
      print('Error al actualizar cambio: $e');
    }
  }
  
  void _updateRemainingAmount(InvoiceAccount invoiceAccount) {
    if (!mounted) return;
    
    try {
      final amount = double.tryParse(_amountController.text) ?? 0.0;
      final newRemainingAmount = invoiceAccount.remainingAmount - amount;
      
      setState(() {
        _remainingAfterPayment = newRemainingAmount;
      });
    } catch (e) {
      print('Error al actualizar monto restante: $e');
    }
  }
  
  Future<void> _registerPayment(BuildContext context, InvoiceAccount invoiceAccount) async {
    if (!mounted) return;
    
    if (_formKey.currentState!.validate()) {
      // Mostrar indicador de carga
      setState(() {
        _isLoading = true;
      });
      
      try {
        final amount = double.parse(_amountController.text);
        final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
        
        // Crear objeto de pago según el método
        final payment = Payment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          invoiceAccountId: invoiceAccount.id,
          amount: amount,
          date: DateTime.now(),
          method: _selectedMethod,
          reconciliationCode: _selectedMethod != PaymentMethod.cash
              ? _reconciliationCodeController.text
              : null,
          cashReceived: _selectedMethod == PaymentMethod.cash 
              ? double.tryParse(_cashReceivedController.text) 
              : amount, // Para métodos que no son efectivo, el monto recibido es igual al monto a pagar
          cashChange: _selectedMethod == PaymentMethod.cash ? _cashChange : 0.0,
        );
        
        // Enviar el pago al backend
        await invoiceAccountProvider.addPayment(invoiceAccount.id, payment);
        
        // Mostrar mensaje de éxito
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pago registrado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Volver a la pantalla anterior
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Manejar errores
        print('Error al registrar el pago: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al registrar el pago: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          
          // Ocultar indicador de carga
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
