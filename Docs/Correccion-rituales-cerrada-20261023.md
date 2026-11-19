# Ritual recurrente después de detener una ocurrencia — 23/10/2026

Reporte: versión 1.4 (54), ritual Mañanero previsto a las 10:36. El diagnóstico registra un lanzamiento el 23/10 a las 11:47:01 (Argentina) y la extensión aplica el ritual a las 11:47:05. Hay una activación anterior a las 10:36:15. Los eventos de la extensión sólo conservan 24 entradas y no incluyen fecha completa; la fecha de la última activación se puede correlacionar con el heartbeat adjunto. No demuestra que el usuario haya detenido previamente el ritual con NFC ni el estado de uso del teléfono a las 10:36.

Defecto encontrado en el código local: detener una ocurrencia elimina todos sus monitores semanales y la reprogramación excluye rituales suprimidos. Su recuperación depende del temporizador o de una nueva ejecución de la app. Una pausa temporal puede por ello impedir la siguiente ocurrencia con la app cerrada.

Corrección:
- Conservar los monitores recurrentes durante la supresión temporal.
- No detenerlos al restaurar una supresión guardada.
- Mantener el filtro previo de notificaciones independiente de los monitores.
- Comprobar supresión en la extensión antes de interrumpir un modo activo.
- La extensión ya compara la fecha de vencimiento de la supresión: no necesita que la app borre la marca para permitir la siguiente ocurrencia.

Validación: `python3 Tests/run_ritual_recurrence_regressions.py` ejecuta el método real de reprogramación con un monitor simulado y el almacén real de supresión en una suite aislada. Verifica conservación del registro durante la pausa y vencimiento sin volver a ejecutar la app. `python3 Tests/run_monitor_regressions.py` verifica callbacks de recreos y heartbeat; ambas pruebas pasaron.

Pendiente: comprobar en iPhone una detención por NFC seguida de otra ocurrencia sin abrir Rituo, incluyendo segundo plano y cierre desde el selector de apps. Las pruebas simuladas no certifican la entrega de callbacks de Screen Time por iOS. No se desplegó backend ni se subió una nueva versión a Apple.

Compilación Release para iOS Simulator: BUILD SUCCEEDED (sin firma, SDK de Xcode local). `git diff --check` pasó. Esto no valida el comportamiento en dispositivo ni certifica que el código local sea idéntico al archivo distribuido como build 54.

## Renovación de recreos con el mismo ritual activo — 16/11/2026

El código ya almacenaba la fecha del último recreo y descartaba el consumo anterior al inicio de la ocurrencia actual. Sin embargo, `refreshScheduledRitualState` retornaba antes de esa comprobación si conservaba `isBlocking` y el mismo ID de ritual programado. Se agregó `restoreRitualBreakUsage(for:)` dentro de esa rama, antes de actualizar el contador de tiempo y retornar. La renovación sigue siendo por ocurrencia, no por medianoche.

`python3 Tests/run_ritual_break_renewal.py` extrae la rama real y las funciones reales de restauración y calendario, con reloj determinista y UserDefaults aislado. Antes del cambio falló al conservar el consumo agotado del día anterior. Después pasó: día siguiente con el mismo modelo/ID, eliminación persistida del consumo vencido, refrescos repetidos sin conceder recreos nuevos, reapertura en la misma ocurrencia, restauración en frío al día siguiente, continuidad tras medianoche, próxima ocurrencia nocturna y registros antiguos sin fecha. Las pruebas de conservación de programación después de NFC también pasaron.

La prueba simula las dependencias de la app; no equivale a comprobar una noche real en un iPhone. Queda validar en dispositivo agotando los recreos de una ocurrencia y comprobando que la siguiente recupere el cupo sin editar el ritual.
