import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

import '../data/finance_repository.dart' show boxNameSecurity;

/// Bloqueo de la app con PIN (todas las plataformas) y desbloqueo biométrico
/// acelerado en Android/Windows (el plugin `local_auth` no soporta web).
class SecurityService extends ChangeNotifier {
  SecurityService._internal();

  static final SecurityService instance = SecurityService._internal();

  bool _unlocked = false;
  bool _biometricsChecked = false;
  bool _biometricsAvailable = false;

  bool get unlocked => _unlocked;

  bool get enabled =>
      Hive.box(boxNameSecurity).get('pinHash') is String;

  Box get _box => Hive.box(boxNameSecurity);

  static String _hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin')).toString();

  String _newSalt() {
    final rng = Random.secure();
    return List.generate(
      16,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> enablePin(String pin) async {
    final salt = _newSalt();
    final hash = _hashPin(pin, salt);
    await _box.put('pinSalt', salt);
    await _box.put('pinHash', hash);
    _unlocked = true;
    notifyListeners();
  }

  Future<void> disablePin() async {
    await _box.delete('pinSalt');
    await _box.delete('pinHash');
    _unlocked = true;
    notifyListeners();
  }

  bool unlock(String pin) {
    final salt = _box.get('pinSalt') as String?;
    final hash = _box.get('pinHash') as String?;
    if (salt == null || hash == null) return false;
    if (_hashPin(pin, salt) != hash) return false;
    _unlocked = true;
    notifyListeners();
    return true;
  }

  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    notifyListeners();
  }

  Future<bool> biometricsAvailable() async {
    if (kIsWeb) return false;
    if (_biometricsChecked) return _biometricsAvailable;
    try {
      final auth = LocalAuthentication();
      final can = await auth.canCheckBiometrics;
      _biometricsAvailable =
          can && (await auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      _biometricsAvailable = false;
    }
    _biometricsChecked = true;
    return _biometricsAvailable;
  }

  Future<bool> authenticateBiometrics() async {
    if (kIsWeb) return false;
    final auth = LocalAuthentication();
    final ok = await auth.authenticate(
      localizedReason: 'Desbloquea tus finanzas',
    );
    if (ok) {
      _unlocked = true;
      notifyListeners();
    }
    return ok;
  }

  @visibleForTesting
  void resetState() {
    _unlocked = false;
    _biometricsChecked = false;
    _biometricsAvailable = false;
  }
}