# Implementación de Notificaciones QR - Instrucciones

## Archivos Modificados/Creados

1. **pubspec.yaml**: Agregadas dependencias para SSE y toast notifications
2. **lib/services/payment_notification_service.dart**: Servicio principal para manejar notificaciones
3. **lib/screens/register_payment_screen.dart**: Integración con notificaciones en UI

## Pasos para Completar la Implementación

### 1. Instalar Dependencias
```bash
cd ~/Developer/cobra-app
flutter pub get
```

### 2. Configurar la URL Base
En `lib/config/app_config.dart`, asegúrate de tener:
```dart
class AppConfig {
  static const String baseUrl = 'https://tu-backend-url.com'; // Reemplaza con tu URL
}
```

### 3. Implementar la Llamada Real a la API
En `register_payment_screen.dart`, reemplaza el método `_generateQRFromAPI`:

```dart
Future<String> _generateQRFromAPI(InvoiceAccount invoiceAccount, double amount) async {
  final response = await http.post(
    Uri.parse('${AppConfig.baseUrl}/api/qr/generate'), // Tu endpoint real
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${await AuthService.getToken()}', // Si requiere auth
    },
    body: json.encode({
      'invoice_id': invoiceAccount.invoiceId,
      'instalment_id': invoiceAccount.instalmentId, // Si aplica
      'amount': amount,
      'currency': 'PEN', // o la moneda correcta
    }),
  );
  
  if (response.statusCode == 200) {
    return response.body; // Retorna el string completo de la respuesta
  } else {
    throw Exception('Error generando QR: ${response.statusCode}');
  }
}
```

### 4. Mejorar el Dialog del QR
Reemplaza `_showQRCodeDialog` con una implementación que muestre la imagen real:

```dart
void _showQRCodeDialog(String qrResponse) {
  final qrData = json.decode(qrResponse);
  final qrImageUrl = qrData['qr_image_url'];
  
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      title: const Text('Escanea para Pagar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (qrImageUrl != null) 
            Image.network(qrImageUrl, height: 200, width: 200)
          else 
            const Icon(Icons.qr_code, size: 100),
          const SizedBox(height: 16),
          Text('Monto: S/ ${_amountController.text}'),
          const SizedBox(height: 8),
          const Text('El pago se detectará automáticamente'),
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
```

### 5. Configurar Navegación
Asegúrate de que tu `routes.dart` incluya la ruta para el recibo:

```dart
GoRoute(
  path: '/payment-receipt/:paymentId',
  builder: (context, state) => PaymentReceiptScreen(
    paymentId: state.pathParameters['paymentId']!,
  ),
),
```

## Flujo de Uso

1. **Usuario selecciona método "QR"** en la pantalla de registro de pago
2. **Usuario ajusta el monto** si necesario
3. **Usuario presiona "Generar QR para Pago"**
4. **Sistema genera QR** y muestra dialog con código
5. **Sistema inicia monitoreo** usando SSE + polling fallback
6. **Cliente escanea QR** y paga con Yape/Plin
7. **Backend recibe webhook** de Ligo y almacena evento en cache
8. **App móvil recibe notificación** automáticamente
9. **Sistema muestra toast** de éxito y redirige a recibo

## Personalización

### Timeout del Monitoreo
```dart
await _notificationService.startMonitoring(
  qrId: qrId,
  timeout: Duration(minutes: 10), // Cambia según necesites
  onPaymentSuccess: _onQRPaymentSuccess,
  onTimeout: _onQRPaymentTimeout,
);
```

### Mensajes de Toast
Modifica en `PaymentNotificationService` los métodos `_showSuccessMessage` y `_showTimeoutMessage`.

### Estilo del UI
Los widgets QR están estilizados con el tema de tu app. Personaliza colores y tamaños según tu diseño.

## Testing

1. **Modo Mock**: El código incluye un QR simulado para testing
2. **Logs**: Usa `Logger.info()` para debug del flujo
3. **Timeout Testing**: Reduce timeout a 30 segundos para pruebas rápidas

## Notas Importantes

- **Limpieza**: El servicio automáticamente limpia recursos al salir de pantalla
- **Reconexión**: Si SSE falla, automáticamente cambia a polling
- **Thread Safety**: Todas las operaciones verifican `mounted` antes de actualizar UI
- **Error Handling**: Manejo completo de errores de red y parsing

## Endpoints del Backend Utilizados

- `GET /api/payment-stream/{qr_id}` - Server-Sent Events
- `GET /api/payment-events/{qr_id}` - Polling fallback  
- `POST /api/qr/generate` - Generación de QR (implementar)