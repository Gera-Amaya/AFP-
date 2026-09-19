import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:finanzas_personales/data/finance_repository.dart';
import 'package:finanzas_personales/security/security_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('afp_sec_test');
    Hive.init(tempDir.path);
    await Hive.openBox<Map>(boxNameCategories);
    await Hive.openBox<Map>(boxNameTransactions);
    await Hive.openBox<Map>(boxNamePlannedExpenses);
    await Hive.openBox<Map>(boxNameDebts);
    await Hive.openBox<Map>(boxNamePlanConfig);
    await Hive.openBox<Map>(boxNameSavingsGoals);
    await Hive.openBox(boxNameSecurity);
    SecurityService.instance.resetState();
  });

  tearDown(() async {
    SecurityService.instance.resetState();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('bloqueo con PIN', () {
    test('enablePin activa el bloqueo y no guarda el PIN en claro', () async {
      final service = SecurityService.instance;
      expect(service.enabled, isFalse);

      await service.enablePin('1234');

      expect(service.enabled, isTrue);
      expect(service.unlocked, isTrue);

      final box = Hive.box(boxNameSecurity);
      final hash = box.get('pinHash') as String;
      expect(hash, isNot(contains('1234')));
      expect(hash.length, 64); // sha256 hex
      expect(box.get('pinSalt') as String, isNotEmpty);
    });

    test('unlock acepta el PIN correcto y rechaza otros', () async {
      final service = SecurityService.instance;
      await service.enablePin('2580');
      service.lock();

      expect(service.unlocked, isFalse);
      expect(service.unlock('0000'), isFalse);
      expect(service.unlocked, isFalse);

      expect(service.unlock('2580'), isTrue);
      expect(service.unlocked, isTrue);
    });

    test('unlock no abre si el bloqueo no está activo', () async {
      final service = SecurityService.instance;
      expect(service.unlock('1234'), isFalse);
      expect(service.unlocked, isFalse);
    });

    test('lock bloquea y notifica a los listeners', () async {
      final service = SecurityService.instance;
      await service.enablePin('1234');
      var notified = 0;
      service.addListener(() => notified++);

      service.lock();

      expect(service.unlocked, isFalse);
      expect(notified, 1);
    });

    test('cambiar el PIN invalida el anterior', () async {
      final service = SecurityService.instance;
      await service.enablePin('1111');
      await service.enablePin('9999');
      service.lock();

      expect(service.unlock('1111'), isFalse);
      expect(service.unlock('9999'), isTrue);
    });

    test('disablePin desactiva el bloqueo', () async {
      final service = SecurityService.instance;
      await service.enablePin('1234');
      await service.disablePin();

      expect(service.enabled, isFalse);
      final box = Hive.box(boxNameSecurity);
      expect(box.get('pinHash'), isNull);
    });
  });
}
