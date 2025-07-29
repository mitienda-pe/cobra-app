import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String method;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    this.method = 'sms',
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  int _remainingTime = 60; // 60 segundos para el contador
  Timer? _timer;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    // Verificar si el widget está montado y el controlador no ha sido dispuesto
    if (!mounted) return;
    
    if (_otpController.text.length != 6) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Por favor ingresa el código completo de 6 dígitos';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      // Guardar el código OTP en una variable local para evitar acceder al controlador después
      final String otpCode = _otpController.text;
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Pasar el email/phone almacenado en el widget, el código OTP y el contexto
      final success = await authProvider.verifyOTP(widget.email, otpCode, context: context);

      // Verificar si el widget todavía está montado antes de continuar
      if (!mounted) return;

      if (success) {
        // Navegar a la pantalla principal y eliminar todas las rutas anteriores
        // para evitar que el usuario pueda volver a la pantalla de verificación
        GoRouter.of(context).go('/instalments');
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Código incorrecto. Inténtalo de nuevo.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Verificar si el widget todavía está montado antes de actualizar el estado
      if (!mounted) return;
      
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al verificar el código. Inténtalo de nuevo.';
          _isLoading = false;
        });
      }
      
      if (kDebugMode) {
        print('Error en verificación OTP: $e');
      }
    }
  }

  Future<void> _resendOtp() async {
    if (_remainingTime > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.requestOTP(widget.email, method: widget.method);

      // Verificar si el widget todavía está montado antes de actualizar el estado
      if (!mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código reenviado con éxito'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _remainingTime = 60;
          _isResending = false;
        });

        _startTimer();
      } else {
        setState(() {
          _errorMessage = 'Error al reenviar el código. Inténtalo de nuevo.';
          _isResending = false;
        });
      }
    } catch (e) {
      // Verificar si el widget todavía está montado antes de actualizar el estado
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Error al reenviar el código. Inténtalo de nuevo.';
        _isResending = false;
      });
      
      if (kDebugMode) {
        print('Error al reenviar OTP: $e');
      }
    }
  }

  String _formatPhoneNumber(String phone) {
    // Asumiendo que el teléfono viene en formato +51XXXXXXXXX
    if (phone.startsWith('+51') && phone.length == 12) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 5)} ${phone.substring(5, 8)} ${phone.substring(8)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final bool isPhone = widget.method == 'sms';
    final String destination = isPhone 
        ? _formatPhoneNumber(widget.email)
        : widget.email;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            GoRouter.of(context).go('/login');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.sms_outlined,
                size: 70,
                color: Colors.blue,
              ),
              const SizedBox(height: 24),
              Text(
                'Verificación de código',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Hemos enviado un código de verificación a:',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                destination,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: PinCodeTextField(
                  appContext: context,
                  length: 6,
                  obscureText: false,
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(8),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: Colors.white,
                    activeColor: Theme.of(context).primaryColor,
                    selectedColor: Theme.of(context).primaryColor,
                    inactiveColor: Colors.grey.shade300,
                  ),
                  cursorColor: Theme.of(context).primaryColor,
                  animationDuration: const Duration(milliseconds: 300),
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  onCompleted: (v) {
                    // No llamar a _verifyOtp automáticamente para evitar problemas
                    // con el controlador después de la navegación
                    if (mounted && !_isLoading) {
                      // Verificar si el widget está montado y no está procesando antes de proceder
                      _verifyOtp();
                    }
                  },
                  onChanged: (value) {
                    if (mounted) {
                      setState(() {
                        _errorMessage = '';
                      });
                    }
                  },
                  beforeTextPaste: (text) {
                    // Si deseas validar el texto pegado
                    return true;
                  },
                ),
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
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
                        'Verificar',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿No recibiste el código? ',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  TextButton(
                    onPressed: _remainingTime == 0 && !_isResending ? _resendOtp : null,
                    child: _isResending
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _remainingTime > 0
                                ? 'Reenviar en $_remainingTime s'
                                : 'Reenviar código',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _remainingTime > 0
                                  ? Colors.grey
                                  : Theme.of(context).primaryColor,
                            ),
                          ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Ingresa el código de 6 dígitos enviado a tu teléfono para verificar tu identidad.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
