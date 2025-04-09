import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/instalment.dart';
import '../services/instalment_service.dart';

class InstalmentPaymentScreen extends StatefulWidget {
  final int instalmentId;

  const InstalmentPaymentScreen({
    super.key,
    required this.instalmentId,
  });

  @override
  State<InstalmentPaymentScreen> createState() => _InstalmentPaymentScreenState();
}

class _InstalmentPaymentScreenState extends State<InstalmentPaymentScreen> {
  final InstalmentService _instalmentService = InstalmentService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _cashReceivedController = TextEditingController();
  final TextEditingController _reconciliationCodeController = TextEditingController();

  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isGeneratingQR = false;
  Instalment? _instalment;
  String _paymentMethod = 'cash'; // Valores posibles: 'cash', 'transfer', 'pos', 'qr'
  double _amountToPay = 0.0;
  double _cashReceived = 0.0;
  double _cashChange = 0.0;
  String? _errorMessage;
  Map<String, dynamic>? _qrData;

  @override
  void initState() {
    super.initState();
    _loadInstalment();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cashReceivedController.dispose();
    _reconciliationCodeController.dispose();
    super.dispose();
  }

  Future<void> _loadInstalment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Obtener la cuota por su ID usando el nuevo método
      final instalment = await _instalmentService.getInstalment(
        widget.instalmentId,
        includeClient: true,
        includeInvoice: true,
        includePayments: true,
      );

      if (instalment != null) {
        if (mounted) {
          setState(() {
            _instalment = instalment;
            _amountToPay = instalment.remainingAmount;
            _amountController.text = _amountToPay.toStringAsFixed(2);
            _isLoading = false;
          });
        }
      } else {
        throw Exception('No se encontró la cuota');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error al cargar la cuota: $e';
        });
      }
    }
  }

  void _updateAmountToPay(String value) {
    setState(() {
      _amountToPay = double.tryParse(value) ?? 0.0;
      
      // Si el método de pago es efectivo, actualizar el cambio
      if (_paymentMethod == 'cash') {
        _updateCashChange();
      }
    });
  }

  void _updateCashReceived(String value) {
    setState(() {
      _cashReceived = double.tryParse(value) ?? 0.0;
      _updateCashChange();
    });
  }

  void _updateCashChange() {
    setState(() {
      _cashChange = _cashReceived - _amountToPay;
    });
  }

  bool _validatePayment() {
    // Validar que el monto a pagar sea mayor que cero
    if (_amountToPay <= 0) {
      setState(() {
        _errorMessage = 'El monto a pagar debe ser mayor que cero';
      });
      return false;
    }

    // Validar que el monto a pagar no sea mayor que el monto pendiente
    if (_instalment != null && _amountToPay > _instalment!.remainingAmount) {
      setState(() {
        _errorMessage = 'El monto a pagar no puede ser mayor que el monto pendiente';
      });
      return false;
    }

    // Si el método de pago es efectivo, validar que el efectivo recibido sea suficiente
    if (_paymentMethod == 'cash' && _cashReceived < _amountToPay) {
      setState(() {
        _errorMessage = 'El efectivo recibido debe ser al menos igual al monto a pagar';
      });
      return false;
    }

    // Si el método de pago es transferencia, POS o QR, validar que haya un código de conciliación
    if (_paymentMethod != 'cash' && _reconciliationCodeController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Ingrese un código de conciliación para este método de pago';
      });
      return false;
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  Future<void> _registerPayment() async {
    if (!_validatePayment()) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final response = await _instalmentService.registerInstalmentPayment(
        instalmentId: _instalment!.id.toString(),
        amount: _amountToPay,
        paymentMethod: _paymentMethod,
        reconciliationCode: _paymentMethod != 'cash' ? _reconciliationCodeController.text : null,
        cashReceived: _paymentMethod == 'cash' ? _cashReceived : null,
        cashChange: _paymentMethod == 'cash' ? _cashChange : null,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        if (response['success'] == true) {
          // Navegar a la pantalla de comprobante de pago usando GoRouter
          if (mounted) {
            // Preparar los datos para pasar a la pantalla de comprobante
            final Map<String, dynamic> receiptData = {
              'paymentData': response,
              'instalment': _instalment!,
              'amount': _amountToPay,
              'paymentMethod': _paymentMethod,
              'reconciliationCode': _paymentMethod != 'cash' ? _reconciliationCodeController.text : null,
              'cashReceived': _paymentMethod == 'cash' ? _cashReceived : null,
              'cashChange': _paymentMethod == 'cash' ? _cashChange : null,
            };
            
            // Usar GoRouter para la navegación
            GoRouter.of(context).push('/payment-receipt', extra: receiptData);
          }
        } else {
          setState(() {
            _errorMessage = response['message'] ?? 'Error al registrar el pago';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Error al registrar el pago: $e';
        });
      }
    }
  }

  // Este método ya no se utiliza
  // ignore: unused_element
  Future<void> _showSuccessDialog(Map<String, dynamic> response) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Pago registrado'),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(response['message'] ?? 'El pago se ha registrado correctamente'),
                const SizedBox(height: 8),
                Text(
                  'ID de pago: ${response['payment_id'] ?? 'No disponible'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: const Text('Aceptar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Método de pago',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Efectivo'),
                value: 'cash',
                groupValue: _paymentMethod,
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Transferencia'),
                value: 'transfer',
                groupValue: _paymentMethod,
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('POS'),
                value: 'pos',
                groupValue: _paymentMethod,
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('QR'),
                value: 'qr',
                groupValue: _paymentMethod,
                onChanged: (value) {
                  setState(() {
                    _paymentMethod = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Efectivo recibido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _cashReceivedController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            hintText: '0.00',
          ),
          onChanged: _updateCashReceived,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cambio a devolver:',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            Text(
              NumberFormat.currency(
                locale: 'es_AR',
                symbol: '\$',
                decimalDigits: 2,
              ).format(_cashChange),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: _cashChange < 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReconciliationCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Código de conciliación',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _reconciliationCodeController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.confirmation_number),
            hintText: 'Ingrese el código de referencia',
          ),
        ),
      ],
    );
  }
  
  Widget _buildQRPaymentField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pago con QR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        if (_qrData != null) ...[  
          // Mostrar el QR generado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                // Imagen del QR
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _qrData!['qr_image_url'],
                    height: 200,
                    width: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        width: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error_outline, size: 48),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                // Información del QR
                Text(
                  'Orden: ${_qrData!['order_id']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Expira: ${_formatExpirationDate(_qrData!['expiration'])}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),
                // Botón para abrir el QR en el navegador
                OutlinedButton.icon(
                  onPressed: () => _launchQRUrl(_qrData!['qr_image_url']),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir en navegador'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _reconciliationCodeController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.confirmation_number),
              hintText: 'Ingrese el código de transacción QR',
              labelText: 'Código de transacción',
            ),
          ),
        ] else ...[  
          // Botón para generar QR
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGeneratingQR ? null : _generateQRCode,
              icon: _isGeneratingQR 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                  : const Icon(Icons.qr_code),
              label: Text(_isGeneratingQR ? 'Generando QR...' : 'Generar código QR'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Genera un código QR para que el cliente pueda pagar con su aplicación bancaria o billetera digital.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }
  
  String _formatExpirationDate(String dateString) {
    try {
      final DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return dateString;
    }
  }
  
  Future<void> _launchQRUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al abrir URL: $e')),
        );
      }
    }
  }
  
  Future<void> _generateQRCode() async {
    if (_instalment == null) return;
    
    setState(() {
      _isGeneratingQR = true;
      _errorMessage = null;
    });
    
    try {
      final result = await _instalmentService.generateInstalmentQR(_instalment!.id.toString());
      
      if (mounted) {
        setState(() {
          _isGeneratingQR = false;
          
          if (result['success'] == true) {
            _qrData = result;
          } else {
            _errorMessage = result['message'] ?? 'Error al generar el código QR';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeneratingQR = false;
          _errorMessage = 'Error al generar el código QR: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_AR',
      symbol: '\$',
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Pago'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _instalment == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage ?? 'No se pudo cargar la cuota',
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          GoRouter.of(context).pop();
                        },
                        child: const Text('Volver'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información de la cuota
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Cuota #${_instalment!.number}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(_instalment!.dueDate),
                                    style: TextStyle(
                                      color: _instalment!.isOverdue ? Colors.red : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (_instalment!.client != null)
                                Text(
                                  _instalment!.client!.businessName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                  ),
                                ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Monto total:'),
                                  Text(
                                    currencyFormat.format(_instalment!.amount),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Pagado:'),
                                  Text(
                                    currencyFormat.format(_instalment!.paidAmount),
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Pendiente:',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    currencyFormat.format(_instalment!.remainingAmount),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Formulario de pago
                      const Text(
                        'Monto a pagar',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: '0.00',
                        ),
                        onChanged: _updateAmountToPay,
                      ),
                      const SizedBox(height: 16),

                      // Selector de método de pago
                      _buildPaymentMethodSelector(),
                      const SizedBox(height: 16),

                      // Campos específicos según el método de pago
                      if (_paymentMethod == 'cash')
                        _buildCashFields()
                      else if (_paymentMethod == 'qr')
                        _buildQRPaymentField()
                      else
                        _buildReconciliationCodeField(),
                      const SizedBox(height: 16),

                      // Resumen del pago
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Resumen del pago',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Monto a pagar:'),
                                  Text(
                                    currencyFormat.format(_amountToPay),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Saldo pendiente después del pago:'),
                                  Text(
                                    currencyFormat.format(_instalment!.remainingAmount - _amountToPay),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: (_instalment!.remainingAmount - _amountToPay) <= 0
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Mensaje de error
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Botón de registrar pago
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isProcessing ? null : _registerPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: _isProcessing
                              ? const CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                )
                              : const Text(
                                  'Registrar Pago',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
