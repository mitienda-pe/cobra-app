import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_client_sse/constants/sse_request_type_enum.dart';
import 'package:flutter_client_sse/flutter_client_sse.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../utils/logger.dart';

class PaymentNotificationService {
  static final PaymentNotificationService _instance = PaymentNotificationService._internal();
  factory PaymentNotificationService() => _instance;
  PaymentNotificationService._internal();

  StreamSubscription<SSEModel>? _sseSubscription;
  Timer? _pollingTimer;
  bool _isMonitoring = false;

  /// Inicia el monitoreo de pagos para un QR específico
  Future<void> startMonitoring({
    required String qrId,
    required Function(Map<String, dynamic>) onPaymentSuccess,
    Function()? onTimeout,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    if (_isMonitoring) {
      Logger.warning('PaymentNotificationService: Ya hay un monitoreo activo');
      return;
    }

    _isMonitoring = true;
    Logger.info('PaymentNotificationService: Iniciando monitoreo para QR: $qrId');

    // Intentar SSE primero
    bool sseSuccess = await _startSSE(qrId, onPaymentSuccess);
    
    if (!sseSuccess) {
      Logger.info('PaymentNotificationService: SSE falló, iniciando polling');
      _startPolling(qrId, onPaymentSuccess);
    }

    // Timeout de seguridad
    Timer(timeout, () {
      if (_isMonitoring) {
        stopMonitoring();
        onTimeout?.call();
        _showTimeoutMessage();
      }
    });
  }

  /// Inicia conexión SSE
  Future<bool> _startSSE(String qrId, Function(Map<String, dynamic>) onPaymentSuccess) async {
    try {
      final url = '${AppConfig.baseUrl}/api/payment-stream/$qrId';
      
      // Crear stream SSE
      final sseStream = SSEClient.subscribeToSSE(
        method: SSERequestType.GET,
        url: url,
        header: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      );

      // Escuchar eventos de pago exitoso
      _sseSubscription = sseStream.listen(
        (event) {
          try {
            if (event.event == 'payment_success' && event.data != null) {
              final paymentData = json.decode(event.data!);
              Logger.info('PaymentNotificationService: Pago recibido vía SSE: $paymentData');
              
              stopMonitoring();
              _showSuccessMessage(paymentData);
              onPaymentSuccess(paymentData);
            }
          } catch (e) {
            Logger.error('PaymentNotificationService: Error procesando evento SSE', e);
          }
        },
        onError: (error) {
          Logger.error('PaymentNotificationService: Error en SSE', error);
          _sseSubscription?.cancel();
          _sseSubscription = null;
          
          // Fallback a polling si SSE falla
          if (_isMonitoring) {
            _startPolling(qrId, onPaymentSuccess);
          }
        },
        onDone: () {
          Logger.info('PaymentNotificationService: SSE conexión cerrada');
        },
      );

      return true;
    } catch (e) {
      Logger.error('PaymentNotificationService: No se pudo iniciar SSE', e);
      return false;
    }
  }

  /// Inicia polling como fallback
  void _startPolling(String qrId, Function(Map<String, dynamic>) onPaymentSuccess) {
    int attempts = 0;
    const maxAttempts = 100; // 5 minutos (3s * 100)
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      
      try {
        final response = await http.get(
          Uri.parse('${AppConfig.baseUrl}/api/payment-events/$qrId'),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data != null && data['status'] == 'completed') {
            Logger.info('PaymentNotificationService: Pago recibido vía polling: $data');
            
            stopMonitoring();
            _showSuccessMessage(data);
            onPaymentSuccess(data);
            return;
          }
        }

        if (attempts >= maxAttempts) {
          Logger.warning('PaymentNotificationService: Polling timeout alcanzado');
          stopMonitoring();
        }
      } catch (e) {
        Logger.error('PaymentNotificationService: Error en polling', e);
      }
    });
  }

  /// Detiene el monitoreo
  void stopMonitoring() {
    if (!_isMonitoring) return;
    
    Logger.info('PaymentNotificationService: Deteniendo monitoreo');
    
    _isMonitoring = false;
    _sseSubscription?.cancel();
    _sseSubscription = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Muestra mensaje de éxito
  void _showSuccessMessage(Map<String, dynamic> paymentData) {
    final amount = paymentData['amount']?.toString() ?? '0.00';
    
    Fluttertoast.showToast(
      msg: '¡Pago Recibido! S/ $amount',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
      backgroundColor: Colors.green,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  /// Muestra mensaje de timeout
  void _showTimeoutMessage() {
    Fluttertoast.showToast(
      msg: 'Tiempo agotado. Verifica manualmente en el listado de pagos.',
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      backgroundColor: Colors.orange,
      textColor: Colors.white,
      fontSize: 14.0,
    );
  }

  /// Extrae el ID del QR desde diferentes formatos de respuesta
  static String? extractQrId(String qrResponse) {
    try {
      Logger.info('PaymentNotificationService: Iniciando extracción de QR ID...');
      
      // Si es JSON, primero intentar extraer del hash EMV
      if (qrResponse.trim().startsWith('{')) {
        final jsonData = json.decode(qrResponse);
        Logger.info('PaymentNotificationService: JSON parseado exitosamente');
        
        // Intentar extraer del hash EMV primero (más confiable)
        // El backend puede enviar qr_data de dos formas:
        // 1. Como string directo: {"qr_data": "EMV_STRING"}
        // 2. Como objeto: {"qr_data": {"hash": "EMV_STRING"}}
        if (jsonData.containsKey('qr_data') && jsonData['qr_data'] != null) {
          String? hashString;
          
          if (jsonData['qr_data'] is String) {
            // Caso 1: qr_data es string directo
            hashString = jsonData['qr_data'] as String;
            Logger.info('PaymentNotificationService: qr_data es string directo');
          } else if (jsonData['qr_data'] is Map) {
            // Caso 2: qr_data es objeto con campo hash
            final qrData = jsonData['qr_data'] as Map<String, dynamic>;
            if (qrData.containsKey('hash')) {
              hashString = qrData['hash'].toString();
              Logger.info('PaymentNotificationService: qr_data es objeto con hash');
            }
          }
          
          if (hashString != null) {
            Logger.info('PaymentNotificationService: hash encontrado: ${hashString.substring(0, 50)}...');
            
            // Buscar patrón EMV: 30 + longitud + 20 dígitos
            final emvMatch = RegExp(r'30(\d{2})(\d{20})').firstMatch(hashString);
            if (emvMatch != null) {
              final extractedId = emvMatch.group(2)!;
              Logger.info('PaymentNotificationService: ✅ QR ID extraído del hash EMV: $extractedId');
              return extractedId;
            } else {
              Logger.warning('PaymentNotificationService: No se encontró patrón EMV en hash');
            }
          } else {
            Logger.warning('PaymentNotificationService: qr_data no contiene string válido');
          }
        } else {
          Logger.warning('PaymentNotificationService: qr_data no encontrado');
        }
        
        // Fallback: usar order_id del JSON si existe
        if (jsonData.containsKey('order_id')) {
          final orderId = jsonData['order_id'].toString();
          Logger.info('PaymentNotificationService: ⚠️ Usando order_id como fallback: $orderId');
          return orderId;
        }
        
        Logger.warning('PaymentNotificationService: No se pudo extraer QR ID de ningún campo');
      }
      
      Logger.warning('PaymentNotificationService: No se pudo extraer QR ID');
      return null;
    } catch (e) {
      Logger.error('PaymentNotificationService: Error extrayendo QR ID', e);
      return null;
    }
  }

  /// Getter para verificar si está monitoreando
  bool get isMonitoring => _isMonitoring;
  
  /// Limpia recursos al destruir la instancia
  void dispose() {
    stopMonitoring();
  }
}