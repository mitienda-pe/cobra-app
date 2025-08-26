import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../models/payment.dart';
import '../providers/invoice_account_provider.dart';
import '../models/invoice_account.dart';
import '../utils/currency_formatter.dart';
import '../utils/logger.dart';
import '../services/payment_notification_service.dart';
import '../config/app_config.dart';

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
  
  // Formato para moneda (se determinará según la moneda de la factura)
  late NumberFormat currencyFormat;
  
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  double _cashChange = 0.0;
  double _remainingAfterPayment = 0.0;
  bool _isProcessingInput = false;
  bool _isLoading = false;
  
  // Para notificaciones de pago QR
  bool _isMonitoringQRPayment = false;
  String? _currentQRId;
  final PaymentNotificationService _notificationService = PaymentNotificationService();
  
  @override
  void initState() {
    super.initState();
    
    // Inicializar el monto pendiente después del pago
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
          final invoiceAccount = invoiceAccountProvider.getInvoiceAccountById(widget.invoiceAccountId);
          
          // Inicializar el formateador de moneda con la moneda correcta
          // Como InvoiceAccount no tiene directamente el campo currency, usamos el valor predeterminado
          currencyFormat = CurrencyFormatter.getCurrencyFormat(null);
          
          // Inicializar el monto a pagar con el monto pendiente
          _amountController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
          
          // Inicializar el monto recibido para pagos en efectivo
          _cashReceivedController.text = invoiceAccount.remainingAmount.toStringAsFixed(2);
          
          // Actualizar los cálculos
          _updateRemainingAmount(invoiceAccount);
          _updateCashChange();
        } catch (e) {
          Logger.error('Error al inicializar pantalla de pagos', e);
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
    // Detener monitoreo de notificaciones si está activo
    _notificationService.stopMonitoring();
    _notificationService.dispose();
    
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
                  color: Colors.blue.withAlpha(26),  // 0.1 * 255 = 25.5 ≈ 26
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(77)),  // 0.3 * 255 = 76.5 ≈ 77
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
                          currencyFormat.format(invoiceAccount.remainingAmount),
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
                          currencyFormat.format(double.tryParse(_amountController.text) ?? 0.0),
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
                          currencyFormat.format(_remainingAfterPayment),
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
                            currencyFormat.format(double.tryParse(_cashReceivedController.text) ?? 0.0),
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
                            currencyFormat.format(_cashChange),
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
                    // Capture provider reference before async gap
                    final provider = Provider.of<InvoiceAccountProvider>(context, listen: false);
                    
                    // Usar Future.delayed para reducir la frecuencia de actualizaciones
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) {
                        _updateCashChange();
                        _updateRemainingAmount(
                          provider.getInvoiceAccountById(widget.invoiceAccountId)
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
              
              // Botones según el método de pago
              if (_selectedMethod == PaymentMethod.qr) ...[
                // Botón especial para generar QR
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _isMonitoringQRPayment) ? null : () => _generateQRPayment(context, invoiceAccount),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Theme.of(context).primaryColor,
                    ),
                    icon: _isMonitoringQRPayment 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.qr_code, color: Colors.white),
                    label: Text(
                      _isMonitoringQRPayment 
                          ? 'Esperando pago...' 
                          : 'Generar QR para Pago',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_isMonitoringQRPayment) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withAlpha(77)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.qr_code_scanner, size: 40, color: Colors.blue),
                        SizedBox(height: 8),
                        Text(
                          'Escaneando pagos...',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'El pago se detectará automáticamente cuando sea completado',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ] else ...[
                // Botón normal de registro para otros métodos
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
            color: isSelected ? Theme.of(context).primaryColor.withAlpha(26) : Colors.transparent,  // 0.1 * 255 = 25.5 ≈ 26
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
      Logger.error('Error al actualizar cambio', e);
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
      Logger.error('Error al actualizar monto restante', e);
    }
  }
  
  /// Genera un QR para pago e inicia el monitoreo de notificaciones
  Future<void> _generateQRPayment(BuildContext context, InvoiceAccount invoiceAccount) async {
    if (!mounted || _isMonitoringQRPayment) return;
    
    if (_formKey.currentState!.validate()) {
      // Capture context and scaffold messenger before async operations
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      
      setState(() {
        _isLoading = true;
        _isMonitoringQRPayment = true;
      });
      
      try {
        final amount = double.parse(_amountController.text);
        
        Logger.info('[QR] Iniciando generación de QR para monto: $amount');
        final qrResponse = await _generateQRFromAPI(invoiceAccount, amount);
        Logger.info('[QR] Respuesta recibida: ${qrResponse.substring(0, 200)}...');
        
        // Extraer QR ID de la respuesta  
        Logger.info('[QR] ANTES de extractQrId - qrResponse: ${qrResponse.substring(0, 300)}...');
        
        // NUEVA LÓGICA DE EXTRACCIÓN DIRECTA (TEMPORAL PARA DEBUG)
        String? qrId;
        try {
          final jsonData = json.decode(qrResponse);
          if (jsonData.containsKey('qr_data') && jsonData['qr_data'] is Map) {
            final qrData = jsonData['qr_data'] as Map<String, dynamic>;
            if (qrData.containsKey('hash')) {
              final hashString = qrData['hash'].toString();
              final emvMatch = RegExp(r'30(\d{2})(\d{20})').firstMatch(hashString);
              if (emvMatch != null) {
                qrId = emvMatch.group(2);
                Logger.info('[QR] ✅ QR ID EXTRAÍDO DIRECTAMENTE: $qrId');
              }
            }
          }
          // Fallback al order_id si no funciona la extracción EMV
          if (qrId == null && jsonData.containsKey('order_id')) {
            qrId = jsonData['order_id'].toString();
            Logger.info('[QR] ⚠️ Usando order_id como fallback: $qrId');
          }
        } catch (e) {
          Logger.error('[QR] Error en extracción: $e');
        }
        
        Logger.info('[QR] DESPUÉS de extracción - QR ID final: $qrId');
        
        if (qrId != null) {
          _currentQRId = qrId;
          
          Logger.info('[QR] Iniciando monitoreo para QR ID: $qrId');
          // Iniciar monitoreo de notificaciones
          await _notificationService.startMonitoring(
            qrId: qrId,
            onPaymentSuccess: (paymentData) => _onQRPaymentSuccess(paymentData, invoiceAccount),
            onTimeout: _onQRPaymentTimeout,
          );
          
          Logger.info('[QR] Monitoreo iniciado correctamente');
          
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            
            // Mostrar el QR al usuario
            _showQRCodeDialog(qrResponse);
          }
          
        } else {
          throw Exception('No se pudo extraer el ID del QR generado');
        }
        
      } catch (e) {
        Logger.error('Error generando QR', e);
        
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Error generando QR: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
          
          setState(() {
            _isLoading = false;
            _isMonitoringQRPayment = false;
          });
        }
      }
    }
  }
  
  /// Maneja el pago exitoso recibido por notificación
  void _onQRPaymentSuccess(Map<String, dynamic> paymentData, InvoiceAccount invoiceAccount) {
    if (!mounted) return;
    
    Logger.info('Pago QR recibido: $paymentData');
    
    setState(() {
      _isMonitoringQRPayment = false;
      _currentQRId = null;
    });
    
    // Navegar a pantalla de recibo o detalle del pago
    final paymentId = paymentData['payment_id']?.toString();
    if (paymentId != null) {
      context.go('/payment-receipt/$paymentId');
    } else {
      // Fallback: volver a la pantalla anterior
      Navigator.of(context).pop();
    }
  }
  
  /// Maneja el timeout del monitoreo de pagos
  void _onQRPaymentTimeout() {
    if (!mounted) return;
    
    setState(() {
      _isMonitoringQRPayment = false;
      _currentQRId = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No se detectó el pago. Puedes verificar manualmente en el listado de pagos.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
      ),
    );
  }
  
  /// Llama a la API real para generar QR
  Future<String> _generateQRFromAPI(InvoiceAccount invoiceAccount, double amount) async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/api/payments/generate-instalment-qr/${invoiceAccount.id}?amount=$amount'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        // Retornar la respuesta completa como string para poder extraer el order_id
        return response.body;
      } else {
        throw Exception('Error generando QR: ${response.statusCode}');
      }
    } catch (e) {
      Logger.error('Error al generar QR desde API: $e');
      rethrow;
    }
  }
  
  /// Muestra el QR code en un dialog
  void _showQRCodeDialog(String qrResponse) {
    try {
      final qrData = json.decode(qrResponse);
      final qrImageUrl = qrData['qr_image_url'];
      final amount = _amountController.text;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Escanea para Pagar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (qrImageUrl != null) 
                Image.network(
                  qrImageUrl, 
                  height: 200, 
                  width: 200,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.qr_code, size: 100);
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const CircularProgressIndicator();
                  },
                )
              else 
                const Icon(Icons.qr_code, size: 100),
              const SizedBox(height: 16),
              Text('Monto: S/ $amount', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('QR ID: ${_currentQRId ?? 'N/A'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('El pago se detectará automáticamente', textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopQRMonitoring();
              },
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    } catch (e) {
      Logger.error('Error mostrando QR dialog: $e');
      // Fallback a un dialog simple
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Código QR generado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.qr_code, size: 100),
              const SizedBox(height: 16),
              Text('QR ID: ${_currentQRId ?? 'N/A'}'),
              const SizedBox(height: 8),
              const Text('Escanea el código QR para completar el pago'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _stopQRMonitoring();
              },
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
    }
  }
  
  /// Detiene el monitoreo de pagos QR
  void _stopQRMonitoring() {
    if (_isMonitoringQRPayment) {
      _notificationService.stopMonitoring();
      setState(() {
        _isMonitoringQRPayment = false;
        _currentQRId = null;
      });
    }
  }

  Future<void> _registerPayment(BuildContext context, InvoiceAccount invoiceAccount) async {
    if (!mounted) return;
    
    if (_formKey.currentState!.validate()) {
      // Mostrar indicador de carga
      setState(() {
        _isLoading = true;
      });
      
      // Store context references before async gap
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final invoiceAccountProvider = Provider.of<InvoiceAccountProvider>(context, listen: false);
      
      try {
        final amount = double.parse(_amountController.text);
        
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
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Pago registrado con éxito'),
              backgroundColor: Colors.green,
            ),
          );
          
          // Volver a la pantalla anterior
          navigator.pop();
        }
      } catch (e) {
        // Manejar errores
        Logger.error('Error al registrar el pago', e);
        
        // Ya tenemos scaffoldMessenger capturado antes de la operación asíncrona
        // No necesitamos volver a obtenerlo aquí
        
        // Check if still mounted before showing the snackbar
        if (mounted) {
          scaffoldMessenger.showSnackBar(
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
