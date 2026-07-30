# Configuración de Crashlytics

El proyecto ya contiene el SDK, la inicialización y la carga automática de
símbolos de depuración.

Para vincular la app con Firebase:

1. Crear o abrir el proyecto de Rituo en Firebase.
2. Registrar una app iOS con el bundle ID `io.rituo.app`.
3. Descargar `GoogleService-Info.plist`.
4. Guardarlo como `HolaSwift/GoogleService-Info.plist`.
5. Confirmar que Xcode lo muestra dentro del target `HolaSwift`.

Si el archivo no está presente, la aplicación continúa funcionando pero
Crashlytics queda desactivado.

## Validación

El primer crash de prueba debe ejecutarse sin el debugger conectado:

1. Instalar y abrir la app desde Xcode.
2. Detener la ejecución desde Xcode.
3. Abrir la app manualmente desde el dispositivo.
4. Ejecutar temporalmente un `fatalError("Crashlytics test")`.
5. Volver a abrir la app para enviar el reporte.
6. Confirmar su llegada en Firebase > Crashlytics y retirar el `fatalError`.

No se debe dejar un botón de crash ni un `fatalError` de prueba en builds
distribuidos.
