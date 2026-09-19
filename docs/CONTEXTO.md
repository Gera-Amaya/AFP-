# Contexto del proyecto — AFP (App de Finanzas Personales)

## Qué es

Aplicación Flutter de control de finanzas personales. Registra ingresos y
gastos organizados por categorías y etiquetas, con reportes gráficos y una
pestaña de "Plan" para compromisos (gastos fijos), deudas y ahorro planeado.
Todos los datos se guardan **localmente** con Hive; es 100% offline.

Nombre clave: **AFP**.

## Plataformas objetivo

- **Web** (PWA instalable; deploy en Netlify)
- **Android**
- **Windows** (desktop)

## Stack y dependencias

- Flutter (Dart SDK ^3.7.2), Material 3
- `hive` + `hive_flutter` — almacenamiento local
- `fl_chart` — gráficas (pastel y barras)
- `intl` — formato de moneda y fechas en `es_MX`
- `uuid` — IDs
- `file_saver` + `file_selector` — exportar/importar respaldo JSON (web/Android/Windows)
- `package_info_plus` — versión/build real del paquete para el footer y "Acerca de"
- `flutter_lints` — lints recomendados

## Arquitectura

- **Singleton de datos:** `lib/data/finance_repository.dart`
  - Boxes Hive: `categories`, `transactions`, `planned_expenses`, `debts`,
    `plan_config`, `savings_goals`.
  - Expone `ValueListenable` por box para que las pantallas se actualicen solas.
- **Modelos** (`lib/models/`): `Category`, `Transaction`, `PlannedExpense`,
  `Debt`, `PlanConfig`, `SavingsGoal`. Todos con `toMap`/`fromMap`.
- **Pantallas** (`lib/screens/`), organizadas en `HomeScreen` con
  `NavigationBar` + `IndexedStack` (se conserva el estado por pestaña):
  1. `DashboardTab` — balance total, ingresos/gastos del mes, movimientos recientes.
  2. `TransactionsScreen` — movimientos por mes con filtro de tipo.
  3. `PlanTab` — compromisos, deudas, metas de ahorro y ahorro planeado
     (con selector de mes).
  4. `ReportsScreen` — gastos por categoría (pastel) e ingresos vs gastos (barras).
  5. `CategoriesScreen` — CRUD de categorías con ícono y color.
- **Widgets/helpers:** `TransactionTile`/`CategoryAvatar`, `theme.dart`,
  `utils/format.dart` (formato de moneda, fechas, íconos y colores de categoría).

## Reglas de negocio relevantes

- Cada transacción tiene `type` (income/expense), `amount`, `categoryId`,
  `tags`, `description` y `date`.
- Las categorías no se pueden borrar si tienen movimientos, compromisos o deudas asociados.
- Un **compromiso** es un gasto fijo mensual con `dayOfMonth`; se puede marcar
  como pagado una vez por mes (`lastPaidKey = "yyyy-MM"`). Al marcarlo se crea
  una transacción de gasto automáticamente.
- Una **deuda** tiene un total, pago acumulado y un calendario de cuotas
  (`computeInstallments`) por semana, quincena, mes o pago único. Abonar crea
  transacciones de gasto automáticamente.
- Una **meta de ahorro** tiene un monto objetivo y un ahorrado acumulado.
  "Aportar" crea una transacción de gasto real (tag `meta`) y actualiza el
  ahorrado; la aportación se limita a lo que falta. Si tiene fecha límite se
  muestra cuánto se necesita ahorrar por mes.
- `PlanConfig` guarda `monthlyIncome` y `savingsGoal`.
  "Disponible para ahorro" (`availableForSavings`) = `getBalance()` (dinero
  real acumulado) − `plannedExpensesPendingTotal(month)` − `debtsDueTotal(month)`.
  Las "deudas pendientes" incluyen cuotas vencidas no pagadas. La tarjeta
  "Ahorro planeado" muestra "Compromisos mensuales" (total, presupuesto) y
  "Por pagar en {mes}" (`plannedExpensesPendingTotal`: solo los no pagados del
  mes visible); pagar un compromiso baja el balance tanto como lo pendiente,
  así que el disponible real no cambia. Además muestra lo ahorrado en metas del
  mes (`getMonthSavingsContributions`, gastos con tag `meta`).
- Respaldo: el menú "⋮" del Dashboard permite exportar/importar toda la base en
  un archivo JSON (`exportAll`/`importAll`). El import reemplaza los datos
  actuales tras confirmación. La clave `savings_goals` es opcional (respaldos
  viejos cargan igual).

## Datos por defecto

`FinanceRepository.defaultCategories()` crea 11 categorías (sueldo, otros
ingresos, comida, super, renta, servicios, transporte, salud, entretenimiento,
compras, otros). Se siembran al arrancar si la box está vacía.

## Despliegue

- Netlify: `netlify.toml` + `netlify-build.sh` (instala Flutter y compila la web).
- `tool/serve.js`: servidor local estático para probar `build/web`.
- `finanzas-web.zip` se genera para publicar la PWA manualmente; está ignorado en git.

## Tests

- `test/widget_test.dart` — formato de moneda.
- `test/debt_schedule_test.dart` — calendario de cuotas y pagos de deudas.
- `test/finance_repository_test.dart` — límites de fin de mes y round-trip
  export/import (Hive en directorio temporal).
- `test/savings_goal_test.dart` — cálculos del modelo y aportaciones a metas.

## Comandos

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
flutter build web --release
```

## Estado del código

- `flutter analyze`: sin issues.
- Tests: 29/29 en verde.
- Versión: `1.1.0+2`. Footer con la versión visible en el Dashboard y diálogo
  "Acerca de" en el menú "⋮".
- Rama actual: `dev`. Tareas "Metas de ahorro", revisión de "Ahorro planeado" y
  versión visual terminadas y en validación (sept-2026).