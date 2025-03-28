import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  final String _countryCode = '+51'; // Código de país para Perú

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _requestOTP() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        // Concatenar el código de país con el número de teléfono
        final phoneNumber = _countryCode + _phoneController.text;
        final success = await authProvider.requestOTP(phoneNumber, method: 'sms');

        // Verificar si el widget todavía está montado antes de actualizar el estado
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });

        if (success) {
          // Navegar a la pantalla de verificación OTP usando GoRouter
          final encodedPhone = Uri.encodeComponent(phoneNumber);
          GoRouter.of(context).go('/verify-otp/$encodedPhone?method=sms');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al enviar el código. Inténtalo de nuevo.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        // Verificar si el widget todavía está montado antes de actualizar el estado
        if (!mounted) return;
        
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo o imagen de la aplicación
                  Icon(
                    Icons.account_balance_wallet,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),

                  // Título de la aplicación
                  const Text(
                    'COBRA APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtítulo
                  Text(
                    'Gestión de cobranzas',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 48),

                  // Formulario de ingreso de teléfono
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 9, // Limitar a 9 dígitos
                          inputFormatters: [
                            FilteringTextInputFormatter
                                .digitsOnly, // Solo permitir dígitos
                          ],
                          decoration: InputDecoration(
                            labelText: 'Número de teléfono',
                            hintText: 'Ingresa tu número de 9 dígitos',
                            prefixIcon: const Icon(Icons.phone_android),
                            prefixText: '$_countryCode ',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            counterText:
                                '', // Ocultar el contador de caracteres
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa tu número de teléfono';
                            }
                            if (value.length != 9) {
                              return 'El número debe tener 9 dígitos';
                            }
                            if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                              return 'Ingresa solo números';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _requestOTP,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Enviar código OTP',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mensaje informativo
                  Text(
                    'Recibirás un código SMS para iniciar sesión de forma segura.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
