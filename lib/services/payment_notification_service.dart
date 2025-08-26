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
      // Si es JSON, primero intentar extraer del hash EMV
      if (qrResponse.trim().startsWith('{')) {
        final jsonData = json.decode(qrResponse);
        
        // Intentar extraer del hash EMV primero (más confiable)
        // Formato esperado: {"qr_data": {"hash": "EMV_STRING..."}}
        if (jsonData.containsKey('qr_data') && jsonData['qr_data'] is Map) {
          final qrData = jsonData['qr_data'] as Map<String, dynamic>;
          if (qrData.containsKey('hash') && qrData['hash'] != null) {
            final emvMatch = RegExp(r'30(\d{2})(\d{20})').firstMatch(qrData['hash'].toString());
            if (emvMatch != null) {
              Logger.info('PaymentNotificationService: QR ID extraído del hash EMV: ${emvMatch.group(2)}');
              return emvMatch.group(2);
            }
          }
        }
        
        // También intentar con qr_string si existe
        if (jsonData.containsKey('qr_string') && jsonData['qr_string'] != null) {
          final emvMatch = RegExp(r'30(\d{2})(\d{20})').firstMatch(jsonData['qr_string']);
          if (emvMatch != null) {
            Logger.info('PaymentNotificationService: QR ID extraído del qr_string EMV: ${emvMatch.group(2)}');
            return emvMatch.group(2);
          }
        }
        
        // Fallback: usar order_id del JSON si existe
        if (jsonData.containsKey('order_id')) {
          Logger.info('PaymentNotificationService: QR ID extraído de order_id JSON: ${jsonData['order_id']}');
          return jsonData['order_id'].toString();
        }
        
        // Fallback final: usar id_qr del JSON
        if (jsonData.containsKey('id_qr')) {
          Logger.info('PaymentNotificationService: QR ID extraído de id_qr JSON: ${jsonData['id_qr']}');
          return jsonData['id_qr'].toString();
        }
      }
      
      // Si es EMV string directo
      final match = RegExp(r'30(\d{2})(\d{20})').firstMatch(qrResponse);
      if (match != null) {
        Logger.info('PaymentNotificationService: QR ID extraído del EMV directo: ${match.group(2)}');
        return match.group(2);
      }
      
      Logger.warning('PaymentNotificationService: No se pudo extraer QR ID de: ${qrResponse.substring(0, 50)}...');
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