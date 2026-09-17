# Plan de trabajo — AFP (App de Finanzas Personales)

Fecha: 16-sep-2026
Rama base: `dev`

## Objetivo

Aplicar las correcciones y mejoras acordadas tras la auditoría de la app.
El plan se ejecuta en orden; al final se valida con `flutter analyze` y `flutter test`.

## 1. Bug de fin de mes (datos)

**Archivo:** `lib/data/finance_repository.dart`, `lib/screens/reports_screen.dart`

Problema: `getTransactionsBetween` usa `!d.isAfter(end)` con `end` a la medianoche
del último día del mes. Toda transacción del último día con hora > 00:00 queda
excluida del mes (afecta a las que se generan con `DateTime.now()`:
`markPlannedExpensePaid` y `payDebt`, p. ej. el pago de la renta el día 31).

Cambios:
- `getTransactionsBetween`: rango inclusivo del día completo de `end`
  (`d.isBefore(end.add(1 día))`).
- `debtsDueTotal`: comparar por `year/month` en lugar de ventana de medianoche.
- `pendingInstallmentsForMonth`: comparar por `year/month` (mantiene la lógica
  de incluir cuotas vencidas).
- `_ExpensePieCard` (reportes): filtrar por `year/month`.

## 2. Balance "del mes" independiente del filtro

**Archivo:** `lib/screens/transactions_screen.dart`

El total mostrado en el encabezado debe ser el balance del mes completo, sin
importar el filtro de tipo (Todos/Gastos/Ingresos) activo.

## 3. Bloqueo de borrado de categoría

**Archivo:** `lib/data/finance_repository.dart`

`deleteCategory` solo verificaba transacciones. Ahora también verificará:
- compromisos (`planned_expenses`)
- deudas (`debts`)

Si hay referencias, lanza excepción con mensaje específico (la pantalla de
Categorías ya muestra el SnackBar).

## 4. Sin mutación de estado en `build()`

**Archivos:** `add_transaction_screen.dart`, `planned_expense_editor.dart`,
`debt_editor.dart`

Se elimina la asignación directa de `_categoryId` durante el build cuando la
categoría seleccionada ya no existe. Se introduce una selección derivada
(`_resolveCategoryId`) usada tanto en el build como en el guardado / dropdown.

## 5. Endurecer `Transaction.fromMap`

**Archivo:** `lib/models/transaction.dart`

`tags: ((map['tags'] as List?) ?? const []).cast<String>()` para resistir datos
viejos sin el campo.

## 6. Arreglos menores

**Archivos:** `lib/screens/plan_tab.dart`, `web/index.html`

- Eliminar `initState` vacío e innecesario.
- Liberar los `TextEditingController` de los diálogos `_pay` y `_openConfig`
  (`.whenComplete(dispose)`).
- `web/index.html`: quitar `user-scalable=no, maximum-scale=1.0` del viewport
  (accesibilidad móvil).

## 7. Perf en reportes

**Archivo:** `lib/screens/reports_screen.dart`

Construir `Map<String, Category>` una sola vez en `_ExpensePieCard.build` y
pasarlo a `_pieSection` (hoy llama `getCategories()` por cada rebanada).

## 8. Export/Import JSON (respaldo)

**Archivos:** `lib/data/finance_repository.dart`, `lib/screens/dashboard_tab.dart`,
`pubspec.yaml`

- Repository: `exportAll()` (todas las boxes) e `importAll()` (limpia y
  restaura, con validación mínima de claves).
- UI: menú "⋮" en el AppBar del Dashboard con "Exportar respaldo" / "Importar
  respaldo". El import pide confirmación antes de reemplazar y muestra
  SnackBar de éxito/error.
- Dependencias nuevas (oficiales, soportan web/Android/Windows): `file_saver`
  (guardar) y `file_selector` (abrir). Se ejecuta `flutter pub get`.

## 9. Filtro por etiquetas

**Archivo:** `lib/screens/transactions_screen.dart`

- Chips con todas las etiquetas distintas (ordenadas) + "Todas".
- Combinable con el filtro de tipo. El total mensual sigue siendo del mes completo.

## 10. Tests

**Archivo nuevo:** `test/finance_repository_test.dart`

- Transacciones del último día del mes (con hora) sí cuentan en el mes.
- Round-trip de export/import de todas las entidades.

Se usa Hive en directorio temporal dentro de setUp/tearDown.

## Validación final

- `flutter analyze` sin issues.
- `flutter test` en verde (10 existentes + nuevos).

## No incluido (fuera de alcance)

- Cálculo de interés real en deudas.
- Modo oscuro.
- Comparación con el mes anterior en el Dashboard.