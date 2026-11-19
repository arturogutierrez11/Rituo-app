# Conservación de rituales recurrentes — 19/11/2026

## Problema y alcance

El reporte describe rituales 05–20 y 07–13 que no arrancan al día siguiente de detener una ocurrencia por NFC, y posiblemente un tercer ritual diario. Sin un diagnóstico nuevo no se puede atribuir el incidente del teléfono a una única causa ni identificar el código incluido en su build.

La corrección previa conserva todos los rituales al reprogramar y registra una supresión con vencimiento para la ocurrencia detenida. La extensión comprueba el vencimiento sin necesitar que la app vuelva a abrirse. Esta corrección se mantiene.

## Cambios adicionales

- Un ritual de los siete días usa un solo monitor diario, con horas de inicio/fin y sin weekday. Tres rituales diarios pasan de 21 registros a 3. Los días parciales siguen usando registros semanales independientes. Los nocturnos conservan el fin al día siguiente.
- El nombre del antiguo registro del domingo se reutiliza como ancla diaria para permitir la migración sin agregar un registro por ritual antes de retirar los antiguos. El nombre es una clave opaca; el calendario efectivo está en DeviceActivitySchedule.
- Se comprueba el presupuesto final de 20 monitores, contando los auxiliares existentes y reservando al menos tres posiciones para temporizadores y recreos. También se comprueba la capacidad transitoria necesaria para mantener los registros anteriores hasta completar los nuevos. Una configuración que no cabe se rechaza antes de cambiar los monitores; puede ser necesario reducir rituales/días.
- Se prepara y serializa el plan completo antes de modificarlo. Se conservan las selecciones, metadatos y horarios nativos anteriores para recuperar los registros afectados si falla una escritura o un registro.
- Los registros obsoletos se retiran después de comprobar que todos los deseados existen. Una reprogramación normal no borra globalmente el estado de los rituales activos.
- Si falla la recuperación, se informa explícitamente y no se confirma la huella de programación. La recuperación es de mejor esfuerzo: las operaciones de iOS y del almacén compartido no forman una transacción atómica.
- Se evita llamar a stopMonitoring con una lista vacía: Apple interpreta esa lista como detener todos los monitores. La defensa está tanto en la limpieza de obsoletos como en el ejecutor compartido.
- El atajo de configuración sin cambios exige que los nombres también existan en iOS y que haya selección y metadatos. Un monitor perdido se vuelve a registrar.
- App y extensión guardan hasta 256 eventos con fecha completa e identificador de proceso también en Release/TestFlight. Es un registro acotado para soporte; las escrituras simultáneas entre procesos pueden competir y no garantiza conservar cada evento.

## Validación automatizada

`Tests/run_schedule_safety_regressions.py` ejecuta el scheduler de producción con un adaptador en memoria que reproduce el límite de 20, la eliminación global con lista vacía y errores inyectados incluso después de modificar el registro. Comprueba migración, tres rituales diarios, ausencia de cambios, recuperación parcial, alta fallida, pérdida de un monitor nativo, presupuesto final y transitorio, error de metadatos, recuperación fallida y calendarios nocturnos/semanales.

`Tests/run_ritual_recurrence_regressions.py` ejecuta el método real de reprogramación del modelo y el almacén real de supresión con dependencias simuladas. Comprueba dos rituales superpuestos, conservación de ambos y vencimiento de la supresión sin reabrir la app. Las pruebas de callbacks y de renovación de recreos complementan estos casos.

Estas pruebas y la compilación Release para Simulator no certifican el comportamiento de callbacks en un iPhone ni el contenido de un archivo previamente subido a TestFlight.

## Prueba pendiente en dispositivo

1. Distribuir e instalar un build nuevo que incluya estos cambios. Abrir una vez para migrar la programación. Guardar el número de build y un diagnóstico inicial.
2. Mantener dos rituales diarios superpuestos; detener por NFC uno durante la superposición. El otro debe conservar su bloqueo según la prioridad de Rituo.
3. Dejar pasar el fin de ambos y el siguiente inicio sin abrir Rituo. Comprobar el bloqueo desde una app seleccionada antes de abrir Rituo; después exportar el diagnóstico.
4. Repetir dejando Rituo en segundo plano y, por separado, cerrándolo desde el selector. Repetir con finalización natural sin NFC y comprobar la renovación de recreos.
5. Buscar `Programación confirmada`, `startMonitoring OK`, supresión, `intervalDidStart` y cualquier error de capacidad/recuperación. Con tres rituales diarios la programación confirmada debe indicar tres monitores de ritual; los auxiliares se cuentan aparte.

No se subió un build ni se modificó el backend como parte de esta corrección.

Referencias: [límite de veinte actividades](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/excessiveactivities), [stopMonitoring y lista vacía](https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter/stopmonitoring(_:)).
