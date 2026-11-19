# Actividades en vivo — build 57

Se agregó RituoLiveActivity (WidgetKit + ActivityKit), con tarjeta en pantalla bloqueada y todas las presentaciones de Dynamic Island. Muestra nombre, contador nativo por fechas y progreso. El contador continúa sin timers de la app; no modifica DeviceActivity ni aplica restricciones.

La app coordina una tarjeta de sesión actual y, desde iOS 26, programa sólo la ocurrencia futura más próxima. La programación usa la API pública de inicio diferido y el sistema presenta una alerta al iniciarla. Al abrir nuevamente la app se elige la próxima ocurrencia; no se registra una semana completa ni se garantiza una nueva tarjeta cada día sin volver a abrir Rituo. En iOS 17–18, la tarjeta se inicia con la app activa.

La tarjeta distingue horario programado de sesión observada. No presenta un ritual agendado como prueba de bloqueo efectivo. El estado queda vencido al llegar el fin previsto, el fin del recreo o las ocho horas de ActivityKit, lo que ocurra primero. La interfaz vencida pide abrir Rituo para actualizar. No se implementaron APNs ni actualizaciones desde la extensión DeviceActivity: no se promete transición automática recreo→foco o retirada inmediata al fin del horario con la app terminada.

Al detener una sesión desde la app/NFC, cambiar de cuenta o perder autorización, la coordinación retira las tarjetas correspondientes cuando la app procesa el estado. Respeta la desestimación del usuario durante la ejecución actual. No se persiste esa desestimación entre reinicios del proceso. El usuario puede desactivar Live Activities desde iOS. Los errores al solicitar una tarjeta se registran sin identificadores de cuenta o nombres.

Pruebas locales:
- `python3 Tests/run_live_activity_timing.py`: método real de cálculo de próxima ocurrencia; medianoche, siguiente semana, ambos cambios DST y horarios vacíos/inválidos.
- `python3 Tests/run_live_activity_lifecycle.py`: coordinador real con adaptadores de ActivityKit; reutilización sin duplicados, actualización de recreo, desestimación, cambio de cuenta, cierre en background y autorización denegada.
- Compilación Release de simulador y revisión de inclusión del .appex.

Validación pendiente en iPhone/TestFlight:
1. Iniciar modo con hora de fin, bloquear pantalla y comprobar contador/progreso sin reabrir.
2. Iniciar recreo, comprobar su contador y el estado por actualizar al vencer con la app cerrada.
3. Detener por NFC; comprobar que desaparece la tarjeta actual y se conserva la programación del ritual siguiente.
4. En iOS 26, abrir Rituo antes del próximo ritual, cerrarla y comprobar que iOS muestra la tarjeta programada al horario.
5. Cambiar de cuenta/cerrar sesión: ninguna tarjeta de la cuenta anterior.
6. Desactivar Live Activities: el bloqueo de apps continúa funcionando.
7. Probar Dynamic Island en dispositivo compatible y tamaño de texto grande.

No se subió una build ni se modificó el backend.

## Corrección de reprogramación del inicio — 16/11/2026

Si una tarjeta sigue pendiente y cambia su fecha de inicio, el coordinador la cancela y permite solicitar una nueva con la fecha corregida. Actualizar sólo el contenido no reprograma el disparo nativo de ActivityKit. Si la app está en segundo plano, se retira la programación anterior y se difiere la nueva solicitud hasta volver al primer plano. Las tarjetas ya visibles se actualizan sin recrearlas.

La prueba de regresión se ejecutó antes del arreglo y falló porque no se cancelaba la fecha anterior. Tras el arreglo pasa: adelantar y atrasar el inicio manteniendo ID y fin, una sola tarjeta resultante, cambio de nombre sin recreación, solicitud diferida en background y reutilización de tarjeta visible. Esta prueba usa el coordinador real con un adaptador de ActivityKit; la entrega a la hora programada requiere validación en iPhone.

## Corrección de restauración de sesión — 16/11/2026

La raíz usa un único `.task(id:)`, ejecutado inicialmente y al cambiar la disponibilidad de la sesión, el contenido a mostrar o el estado de primer plano. La política de disponibilidad espera mientras se restaura la sesión, se carga la cuenta local o termina la comprobación legal. El paso a listo cambia la identidad de la tarea incluso si el ritual permanece idéntico.

Durante una espera no se envía un estado vacío al coordinador. Si se conoce la cuenta autenticada, se conservan sus tarjetas y se retiran las de otra cuenta; si todavía no se conoce, se conservan hasta resolver la restauración. Sólo un cierre de sesión confirmado envía un estado vacío. La cuenta local restaurada debe coincidir con la autenticada antes de publicar contenido.

La prueba de ciclo de vida ejecuta la política y el coordinador reales con un adaptador de ActivityKit. Cubre carga inicial, respuesta legal tardía con contenido de ritual idéntico, conservación durante recarga, ausencia de duplicados, cuenta local todavía anterior, cambio de cuenta y cierre de sesión confirmado. Los casos previos de reprogramación del inicio siguen pasando. La entrega y presentación reales requieren prueba en iPhone.
