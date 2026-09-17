# AFP — App de Finanzas Personales

Aplicación para el control de finanzas personales. Registra ingresos y gastos,
organízalos por categorías y etiquetas, consulta reportes con gráficos y guarda
todo **localmente**, sin necesidad de internet.

## Funcionalidades

- Registro de ingresos y gastos con monto, fecha y descripción
- Categorías personalizables (ícono y color) y etiquetas
- Balance total y resumen mensual (ingresos vs. gastos)
- Reportes: gastos por categoría (pastel) y evolución por mes (barras)
- Almacenamiento local con Hive (SQLite/IndexedDB), 100% offline

## Plataformas

- Android
- Web (PWA instalable en iPhone/Android)
- Windows

## Ejecutar en desarrollo

```bash
flutter pub get
flutter run -d chrome
```

## Despliegue (Netlify)

El repositorio incluye `netlify.toml` y `netlify-build.sh`, que instalan Flutter
y compilan la versión web automáticamente. Conecta el repo a Netlify y listo.
