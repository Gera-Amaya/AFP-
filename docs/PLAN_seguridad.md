# Plan — Bloqueo de seguridad de la app (v1.2.0)

Fecha: 18-sep-2026 · Rama base: `dev` · Previo: 1.1.1 (por pagar + disponible real) publicado

## Objetivo

Evitar que otra persona abra la app y vea las finanzas personales sin permiso:
bloqueo con **PIN de la app** en todas las plataformas y **biometría acelerada**
(Face ID / huella / Windows Hello) donde exista.

## Limitación técnica (decisión de diseño)

- `local_auth` (plugin oficial de biometría) **no soporta web** (solo
  Android/iOS/macOS/Windows). La app principal es la PWA de Netlify, así que el
  desbloqueo en web es siempre con **PIN de la app**.
- Android/Windows: la biometría del dispositivo agiliza el desbloqueo, con el
  PIN como respaldo si no hay biómetro enrollado o el usuario lo cancela.
- Límite realista: esto es un **escudo de acceso**, no cifrado de datos. En una
  PWA el contenido sigue legible vía devtools; el PIN/hash nunca se guarda en
  claro en ningún medio.

## A) Dependencias

- `local_auth: ^2.3.0` (compatible con Flutter 3.29 / Dart 3.7; la 3.x pide
  Dart ≥3.9). Plugin federado; su uso se protege con `kIsWeb` para no afectar
  `flutter build web --release`.
- `crypto: ^3.0.6` (hash SHA-256 del PIN con salt, funciona en web).

## B) `lib/security/security_service.dart`

Singleton `SecurityService extends ChangeNotifier`.

- Persistencia: box Hive `security` (`initStorage` la registra) con
  `{ pinEnabled: bool, pinSalt: String, pinHash: String }` vía
  `FinanceRepository` o config propia. **No se exporta en el respaldo**
  (sigue siendo configuración del dispositivo).
- Estado en memoria: `bool _unlocked`.
- API:
  - `bool get enabled`, `bool get unlocked`
  - `Future<bool> enablePin(String pin)` / `disablePin()` / `changePin(old, new)`
  - `bool unlock(String pin)` (compara hash; constante de tiempo no crítica)
  - `void lock()` → notifica a la UI
  - `Future<bool> biometricsAvailable()` (`canCheckBiometrics` +
    `getAvailableBiometrics`, `false` en web)
  - `Future<bool> authenticateBiometrics()` → `authenticate(...)`; en Windows
    no usar `biometricOnly` (Windows Hello no lo soporta).

## C) `lib/screens/lock_screen.dart`

- Pantalla de bloqueo sin datos financieros: icono de candado, título, campo de
  PIN (oculto), botón "Desbloquear".
- Si hay biometría disponible, al abrir/regresar se lanza la autenticación
  automáticamente; en web o si falla/cancela, queda el campo PIN como respaldo.

## D) Integración en `home_screen.dart`

- `ListenableBuilder` sobre `SecurityService`: con `enabled && !unlocked`
  renderiza `LockScreen` en lugar de las tabs (mismo `Scaffold` y navbar).
- `AppLifecycleListener`: al volver de segundo plano (`onResume`) llamar
  `lock()` para pedir desbloqueo otra vez.
- Acción manual "Bloquear" disponible en el menú ⋮ del Dashboard.

## E) Menú "Seguridad" (Dashboard ⋮)

- Diálogo con: interruptor "Bloquear con PIN", campos para definir/cambiar PIN,
  indicador de biometría disponible (deshabilitado si no aplica).
- Compacto y consistente con el diálogo "Presupuesto y ahorro" actual.

## F) Configuración por plataforma

- Android `AndroidManifest.xml`: `<uses-permission
  android:name="android.permission.USE_BIOMETRIC"/>` (y
  `USE_FINGERPRINT` para API <28).
- iOS (futuro target): `Info.plist` con `NSFaceIDUsageDescription`.
- Web/Netlify: sin cambios; WebAuthn no se usa.

## Tests

- `test/security_service_test.dart`:
  - enable/disable/change PIN; `unlock` acepta el correcto y rechaza otros.
  - `lock()` actualiza estado y notifica.
  - el hash almacenado no contiene el PIN en claro.
  - `biometric` no disponible en `kIsWeb` (se mockea la plataforma si aplica).
- Regresión completa existente (32).

## Documentación

- `docs/CONTEXTO.md`: box `security`, flujo de bloqueo, límite PWA.
- `docs/PLAN.md`: esta sección v1.2.0.

## Validación final

- `flutter analyze` sin issues.
- `flutter test` en verde (32 + nuevos).
- `flutter build web --release` compila (requisito para merge a `main`).

## Pendiente

- Implementación tras aprobar este plan; commit + push a `dev`, bump a
  `1.2.0+4`, y abrir PR a `main`.