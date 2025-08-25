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

  SSEClient? _sseClient;
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
      
      _sseClient = SSEClient.subscribeToSSE(
        method: SSERequestType.GET,
        url: url,
        header: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
        },
      );

      // Escuchar eventos de pago exitoso
      _sseClient!.stream!.listen(
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
          _sseClient?.unsubscribe();
          _sseClient = null;
          
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
    _sseClient?.unsubscribe();
    _sseClient = null;
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
      // Si es JSON
      if (qrResponse.trim().startsWith('{')) {
        final jsonData = json.decode(qrResponse);
        if (jsonData.containsKey('id_qr')) {
          return jsonData['id_qr'].toString();
        }
      }
      
      // Si es EMV string
      final match = RegExp(r'3022(\d{20})').firstMatch(qrResponse);
      if (match != null) {
        return match.group(1);
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