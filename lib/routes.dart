import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/otp_verification_screen.dart';
// Importaciones con nomenclatura "invoice"
import 'screens/invoice_list_screen.dart';
import 'screens/invoice_map_screen.dart';
import 'screens/invoice_detail_screen.dart';
import 'screens/register_payment_screen.dart';
// Importaciones para las nuevas pantallas de cuotas
import 'screens/instalment_list_screen.dart';
import 'screens/instalment_payment_screen.dart';
import 'screens/instalment_detail_screen.dart';
import 'screens/instalment_map_screen.dart';
import 'screens/payment_receipt_screen.dart';

class AppRouter {
  static GoRouter getRouter(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authProvider, // Actualizar rutas cuando cambie el estado de autenticación
      redirect: (context, state) {
        final isLoggedIn = authProvider.isAuthenticated;
        final isLoginRoute = state.matchedLocation == '/login';
        final isOtpRoute = state.matchedLocation.startsWith('/verify-otp');
        final isSplashRoute = state.matchedLocation == '/';
        
        // No redirigir si estamos en la pantalla de splash
        if (isSplashRoute) {
          return null;
        }
        
        // Si no está autenticado y no está en la ruta de login o verificación OTP, redirigir a login
        if (!isLoggedIn && !isLoginRoute && !isOtpRoute) {
          return '/login';
        }
        
        // Si está autenticado y está en la ruta de login o verificación OTP, redirigir a la lista de cuotas
        if (isLoggedIn && (isLoginRoute || isOtpRoute)) {
          return '/instalments';
        }
        
        // Redirecciones para rutas antiguas
        if (state.matchedLocation == '/accounts') {
          return '/instalments';
        }
        if (state.matchedLocation == '/map') {
          return '/invoice-map';
        }
        if (state.matchedLocation.startsWith('/account-detail/')) {
          final accountId = state.pathParameters['id']!;
          return '/invoice-detail/$accountId';
        }
        
        // No hay redirección
        return null;
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/verify-otp/:email',
          builder: (context, state) {
            final email = state.pathParameters['email'] ?? '';
            final method = state.uri.queryParameters['method'] ?? 'email';
            return OtpVerificationScreen(email: email, method: method);
          },
        ),
        // Rutas para cuotas (instalments)
        GoRoute(
          path: '/instalments',
          builder: (context, state) => const InstalmentListScreen(),
        ),
        GoRoute(
          path: '/instalments/:id',
          builder: (context, state) {
            final instalmentId = int.parse(state.pathParameters['id']!);
            return InstalmentDetailScreen(instalmentId: instalmentId);
          },
        ),
        GoRoute(
          path: '/instalments/:id/pay',
          builder: (context, state) {
            final instalmentId = int.parse(state.pathParameters['id']!);
            return InstalmentPaymentScreen(instalmentId: instalmentId);
          },
        ),
        GoRoute(
          path: '/instalment-map',
          builder: (context, state) => const InstalmentMapScreen(),
        ),
        // Ruta para el comprobante de pago
        GoRoute(
          path: '/payment-receipt',
          builder: (context, state) {
            final Map<String, dynamic> args = state.extra as Map<String, dynamic>;
            return PaymentReceiptScreen(
              paymentData: args['paymentData'],
              instalment: args['instalment'],
              amount: args['amount'],
              paymentMethod: args['paymentMethod'],
              reconciliationCode: args['reconciliationCode'],
              cashReceived: args['cashReceived'],
              cashChange: args['cashChange'],
            );
          },
        ),
        // Rutas con nomenclatura "invoice"
        GoRoute(
          path: '/invoices',
          builder: (context, state) => const InvoiceListScreen(),
        ),
        GoRoute(
          path: '/invoice-map',
          builder: (context, state) => const InvoiceMapScreen(),
        ),
        GoRoute(
          path: '/invoice-detail/:id',
          builder: (context, state) {
            final invoiceAccountId = state.pathParameters['id']!;
            return InvoiceDetailScreen(invoiceAccountId: invoiceAccountId);
          },
        ),
        GoRoute(
          path: '/register-payment/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return RegisterPaymentScreen(invoiceAccountId: id);
          },
        ),
      ],
    );
  }
}
