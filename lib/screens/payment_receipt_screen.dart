import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../models/instalment.dart';
import '../models/invoice.dart';
import '../models/client.dart';
import '../services/instalment_service.dart';

class PaymentReceiptScreen extends StatefulWidget {
  final Map<String, dynamic> paymentData;
  final Instalment instalment;
  final double amount;
  final String paymentMethod;
  final String? reconciliationCode;
  final double? cashReceived;
  final double? cashChange;

  const PaymentReceiptScreen({
    Key? key,
    required this.paymentData,
    required this.instalment,
    required this.amount,
    required this.paymentMethod,
    this.reconciliationCode,
    this.cashReceived,
    this.cashChange,
  }) : super(key: key);

  @override
  State<PaymentReceiptScreen> createState() => _PaymentReceiptScreenState();
}

class _PaymentReceiptScreenState extends State<PaymentReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();
  bool _isSharing = false;
  final currencyFormat = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
    decimalDigits: 2,
  );
  
  String _getPaymentMethodName(String method) {
    switch (method) {
      case 'cash':
        return 'Efectivo';
      case 'transfer':
        return 'Transferencia';
      case 'pos':
        return 'POS';
      case 'qr':
        return 'QR';
      default:
        return method;
    }
  }

  Future<void> _shareReceipt() async {
    setState(() {
      _isSharing = true;
    });

    try {
      // Capturar el widget como imagen
      RenderRepaintBoundary boundary = _receiptKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Guardar la imagen temporalmente
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/recibo_pago.png').create();
        await file.writeAsBytes(pngBytes);
        
        // Compartir la imagen
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Recibo de pago - ${widget.instalment.invoice?.invoiceNumber ?? 'N/A'}',
          subject: 'Recibo de pago',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al compartir: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.instalment.invoice;
    final client = widget.instalment.client;
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final paymentDate = DateTime.now();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobante de Pago'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _isSharing ? null : _shareReceipt,
            tooltip: 'Compartir',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RepaintBoundary(
              key: _receiptKey,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'COMPROBANTE DE PAGO',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fecha: ${dateFormat.format(paymentDate)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                        ],
                      ),
                    ),
                    
                    // Datos del cliente
                    if (client != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'CLIENTE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Nombre: ${client.businessName}'),
                      Text('Documento: ${client.documentNumber}'),
                      Text('Contacto: ${client.contactName}'),
                      Text('Email: ${client.email}'),
                      Text('Teléfono: ${client.phone}'),
                      const SizedBox(height: 8),
                      const Divider(),
                    ],
                    
                    // Datos de la factura
                    if (invoice != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'FACTURA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Número: ${invoice.invoiceNumber}'),
                      Text('Monto total: ${currencyFormat.format(invoice.amount)}'),
                      if (invoice.issueDate != null)
                        Text('Fecha de emisión: ${DateFormat('dd/MM/yyyy').format(invoice.issueDate!)}'),
                      const SizedBox(height: 8),
                      const Divider(),
                    ],
                    
                    // Datos de la cuota
                    const SizedBox(height: 16),
                    const Text(
                      'CUOTA',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Número: ${widget.instalment.number}'),
                    Text('Monto original: ${currencyFormat.format(widget.instalment.amount)}'),
                    Text('Monto pendiente: ${currencyFormat.format(widget.instalment.remainingAmount)}'),
                    Text('Fecha de vencimiento: ${DateFormat('dd/MM/yyyy').format(widget.instalment.dueDate)}'),
                    const SizedBox(height: 8),
                    const Divider(),
                    
                    // Datos del pago
                    const SizedBox(height: 16),
                    const Text(
                      'PAGO',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('ID de pago: ${widget.paymentData['payment_id'] ?? 'N/A'}'),
                    Text('Monto pagado: ${currencyFormat.format(widget.amount)}'),
                    Text('Método de pago: ${_getPaymentMethodName(widget.paymentMethod)}'),
                    if (widget.reconciliationCode != null && widget.reconciliationCode!.isNotEmpty)
                      Text('Código de conciliación: ${widget.reconciliationCode}'),
                    if (widget.paymentMethod == 'cash') ...[
                      if (widget.cashReceived != null)
                        Text('Efectivo recibido: ${currencyFormat.format(widget.cashReceived)}'),
                      if (widget.cashChange != null)
                        Text('Cambio: ${currencyFormat.format(widget.cashChange)}'),
                    ],
                    
                    // Pie de página
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Gracias por su pago',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Fecha y hora de emisión: ${dateFormat.format(DateTime.now())}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSharing ? null : _shareReceipt,
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('Finalizar'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
