import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../models/instalment.dart';
import '../services/instalment_service.dart';

class InstalmentDetailScreen extends StatefulWidget {
  final int instalmentId;

  const InstalmentDetailScreen({
    super.key,
    required this.instalmentId,
  });

  @override
  State<InstalmentDetailScreen> createState() => _InstalmentDetailScreenState();
}

class _InstalmentDetailScreenState extends State<InstalmentDetailScreen> {
  final InstalmentService _instalmentService = InstalmentService();
  
  bool _isLoading = true;
  Instalment? _instalment;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadInstalment();
  }

  Future<void> _loadInstalment() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (kDebugMode) {
        print('===== LOADING INSTALMENT DETAIL =====');
        print('Instalment ID: ${widget.instalmentId}');
      }
      
      // Obtener la cuota por su ID
      final instalment = await _instalmentService.getInstalment(
        widget.instalmentId,
        includeClient: true,
        includeInvoice: true,
        includePayments: true,
      );

      if (kDebugMode) {
        print('Instalment loaded: ${instalment != null}');
      }

      if (instalment != null) {
        if (kDebugMode) {
          print('===== DETAIL SCREEN DEBUG =====');
          print('Instalment ID: ${instalment.id}');
          print('Invoice ID: ${instalment.invoiceId}');
          print('Has invoice object: ${instalment.invoice != null}');
          if (instalment.invoice != null) {
            print('Invoice Number: ${instalment.invoice!.invoiceNumber}');
          }
          print('Has client object: ${instalment.client != null}');
          if (instalment.client != null) {
            print('Client Name: ${instalment.client!.businessName}');
          }
          print('Has additionalData: ${instalment.additionalData != null}');
          if (instalment.additionalData != null) {
            print('AdditionalData keys: ${instalment.additionalData!.keys.join(', ')}');
            instalment.additionalData!.forEach((key, value) {
              if (key.toLowerCase().contains('invoice') || 
                  key.toLowerCase().contains('factura') ||
                  key.toLowerCase().contains('client') ||
                  key.toLowerCase().contains('cliente')) {
                print('Key: $key, Value: $value');
              }
            });
          }
          print('===== END DETAIL SCREEN DEBUG =====');
        }
        
        if (mounted) {
          setState(() {
            _instalment = instalment;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'No se pudo cargar la información de la cuota. Intente nuevamente.';
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al cargar la cuota: $e');
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Cuota'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.go('/instalments');
          },
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _instalment == null
              ? Center(child: Text(_errorMessage ?? 'No se encontró la cuota'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Información de la cuota
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Información de la Cuota',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_instalment!.status).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: _getStatusColor(_instalment!.status),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      _getStatusText(_instalment!.status),
                                      style: TextStyle(
                                        color: _getStatusColor(_instalment!.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              const SizedBox(height: 8),
                              Text(
                                'Número: ${_instalment!.number}/${_instalment!.invoice?.instalmentCount ?? 1}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Monto: ${currencyFormat.format(_instalment!.amount)}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Vencimiento: ${dateFormat.format(_instalment!.dueDate)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: _instalment!.isOverdue ? Colors.red : null,
                                  fontWeight: _instalment!.isOverdue ? FontWeight.bold : null,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Progreso de Pago:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: _instalment!.amount > 0
                                    ? (_instalment!.amount - _instalment!.remainingAmount) / _instalment!.amount
                                    : 1.0,
                                backgroundColor: Colors.grey[300],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getStatusColor(_instalment!.status),
                                ),
                                minHeight: 10,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Pagado: ${currencyFormat.format(_instalment!.amount - _instalment!.remainingAmount)}',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Pendiente: ${currencyFormat.format(_instalment!.remainingAmount)}',
                                    style: TextStyle(
                                      color: _instalment!.remainingAmount > 0
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Información del cliente
                      if (_instalment?.client != null)
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Información del Cliente',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Divider(),
                                const SizedBox(height: 8),
                                Text(
                                  'Empresa: ${_instalment!.client!.businessName}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_instalment!.client!.documentNumber.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'RUC: ${_instalment!.client!.documentNumber}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                if (_instalment!.client!.contactName.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Contacto: ${_instalment!.client!.contactName}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                if (_instalment!.client!.address.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Dirección: ${_instalment!.client!.address}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                if (_instalment!.client!.phone.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Teléfono: ${_instalment!.client!.phone}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                if (_instalment!.client!.email.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      'Email: ${_instalment!.client!.email}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Información de la factura
                      if (_instalment?.invoice != null)
                        Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Información de la Factura',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const Divider(),
                                const SizedBox(height: 8),
                                Text(
                                  'Número: ${_instalment!.invoice?.invoiceNumber ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Concepto: ${_instalment!.invoice?.concept ?? "N/A"}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Monto Total: ${currencyFormat.format(_instalment!.invoice?.amount ?? 0)}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                if (_instalment!.invoice?.issueDate != null) ...[
                                  Text(
                                    'Fecha de Emisión: ${dateFormat.format(_instalment!.invoice!.issueDate!)}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                                Text(
                                  'Vencimiento: ${_instalment!.invoice?.dueDate != null ? dateFormat.format(_instalment!.invoice!.dueDate) : "N/A"}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Estado: ${_instalment!.invoice?.status ?? "N/A"}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (_instalment!.invoice?.instalmentCount != null && _instalment!.invoice!.instalmentCount > 1) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Número de cuotas: ${_instalment!.invoice!.instalmentCount}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                                // Mostrar datos adicionales si existen
                                if (_instalment!.additionalData != null && _instalment!.additionalData!.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Información Adicional',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (_instalment!.additionalData!.containsKey('notes') && 
                                      _instalment!.additionalData!['notes'] != null) ...[
                                    Text(
                                      'Notas: ${_instalment!.additionalData!['notes'].toString()}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                    const SizedBox(height: 4),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                          
                      // Botón para registrar pago
                      if (_instalment!.status == 'pending')
                        const SizedBox(height: 16),
                      if (_instalment!.status == 'pending')
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (kDebugMode) {
                                print('Registrando pago para cuota ID=${_instalment!.id}');
                                print('Estado: ${_instalment!.status}, Monto Pendiente: ${_instalment!.remainingAmount}');
                              }
                              // Navegar a la pantalla de pago
                              context.push('/instalments/${_instalment!.id}/pay');
                            },
                            icon: const Icon(Icons.payment),
                            label: const Text('Registrar Pago'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'paid':
        return 'Pagada';
      case 'cancelled':
        return 'Cancelada';
      case 'rejected':
        return 'Rechazada';
      default:
        return 'Desconocido';
    }
  }
}
