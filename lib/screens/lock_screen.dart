import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/security_service.dart';
import '../theme.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _tryBiometrics();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _tryBiometrics() async {
    if (!mounted) return;
    if (!await SecurityService.instance.biometricsAvailable()) return;
    if (SecurityService.instance.unlocked) return;
    await SecurityService.instance.authenticateBiometrics();
  }

  Future<void> _unlock() async {
    final pin = _controller.text;
    if (pin.isEmpty) return;
    final ok = SecurityService.instance.unlock(pin);
    if (!ok && mounted) {
      setState(() => _error = 'PIN incorrecto. Intenta de nuevo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 64,
                  color: seedColor.withValues(alpha: 0.85),
                ),
                const SizedBox(height: 16),
                const Text(
                  'AFP está bloqueada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa tu PIN para ver tus finanzas.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _unlock(),
                  decoration: InputDecoration(
                    labelText: 'PIN',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    errorText: _error,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Colors.black12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: seedColor, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _unlock,
                    icon: const Icon(Icons.lock_open_outlined),
                    label: const Text('Desbloquear'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}