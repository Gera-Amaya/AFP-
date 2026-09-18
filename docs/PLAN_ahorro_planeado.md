# Plan — Revisión de la sección "Ahorro planeado"

Fecha: 17-sep-2026 · Rama base: `dev` · Previo: Metas de ahorro (sin commitear)

## Objetivo

Alinear la tarjeta "Ahorro planeado" con la nueva sección "Metas de ahorro":
mes coherente en el editor, deudas pendientes completas, terminología clara y
visibilidad del dinero realmente ahorrado en metas.

## A) Mes coherente en el hint del editor

- Archivos: `lib/screens/goal_editor.dart`, `lib/screens/plan_tab.dart`
- `GoalEditorScreen({SavingsGoal? goal, DateTime? planMonth})`.
- `_openGoalEditor` pasa `_month` desde PlanTab.
- `goal_editor.dart` usa `planMonth ?? DateTime.now()` para `availableForSavings`
  y aclara el mes en el texto cuando difiere del actual.

## B) Deudas por vencer incluye vencidas

- Archivo: `lib/data/finance_repository.dart`
- `debtsDueTotal(month)`: sumar cuotas no pagadas cuya fecha ≤ fin del mes
  (función auxiliar `isAfterMonth(date, month)`), en lugar de solo el mes exacto.
- PlanTab: etiqueta "Deudas por vencer" → "Deudas pendientes".

## C) Terminología de la tarjeta

- Archivo: `lib/screens/plan_tab.dart`
- En `_SavingsCard`, "Meta: $X" → "Meta mensual: $X".

## D) "Ahorrado en metas del mes"

- Archivo: `lib/data/finance_repository.dart`, `lib/screens/plan_tab.dart`
- Nuevo `double getMonthSavingsContributions(DateTime month)`: suma de gastos
  con tag `meta` dentro del mes (usa `getTransactionsBetween`).
- `_PlanTabState.build` calcula el total y lo pasa a `_SavingsCard`.
- `_SavingsCard` agrega renglón "Ahorrado en metas" (color de ingreso) después
  de "Deudas pendientes". `availableForSavings` se mantiene sin cambios.

## Tests

- `test/finance_repository_test.dart` o `test/savings_goal_test.dart`:
  - `debtsDueTotal` cuenta cuotas vencidas no pagadas del mes pasado.
  - `getMonthSavingsContributions` filtra por mes y tag `meta`.

## Documentación

- `docs/CONTEXTO.md`: renglón "Ahorrado en metas", nota de deudas pendientes.
- `docs/PLAN.md`: sección de esta revisión.

## Validación final

- `flutter analyze` sin issues.
- `flutter test` en verde (26 + nuevos).

## Pendiente

- Commit + push a `dev` y abrir PR a `main` (se consulta al usuario).