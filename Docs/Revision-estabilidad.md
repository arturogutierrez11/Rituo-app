# Revisión consolidada de estabilidad — Rituo 1.2 (51)

Base: commit local 6452fa8, rama codex/ios-production-fixes. main local sigue en build 35. No se conectó a MCP ni a servidores; backend revisado únicamente en archivos locales de core.api. No hay cambios publicados.

## Estado de implementación — continuación

Se cambió esta misma copia a codex/ios-production-fixes (6452fa8, build 51) y se integró el parche conservado. Hay cambios locales sin commit. Se eliminó el parche después de integrarlo; no debe aplicarse nuevamente.

Implementado ahora: consumidor compartido por cuenta para las etapas de configuración; captura de clave de revisión y protección contra respuestas/errores obsoletos al actualizar modos y rituales; espera del fin de restauración antes de la consulta legal, coalescing de consultas concurrentes y rechazo de resultados de otra cuenta/token; navbar con botones; exportación local de los últimos 24 eventos de DeviceActivity. Esos eventos existentes pueden contener nombres de rituales y no se envían a Crashlytics mediante esta exportación.

La protección de revisiones cubre actualización de modos y rituales, no todas las operaciones: creación de rituales y configuración de recreos todavía requieren una revisión específica. No se modificó la programación DeviceActivity ni se confirmó la causa de los rituales que arrancan al abrir. Los siguientes hallazgos conservan el diagnóstico inicial y sus pendientes generales.

Verificación: compilación Debug para simulador y prueba ejecutable con SwiftData en memoria (edición durante envío, conservación de nueva revisión, coalescing, cancelación y siguiente ejecución). Falta reproducción en iPhone, especialmente tareas en segundo plano.


## Hallazgos por prioridad

### 1. Carrera en operaciones de sincronización (alta)

En BlockSetupViewModel, syncPendingSchedulersToCore y syncPendingModesToCore llaman al mismo procesador syncPendingConfigurationOperations, que no tiene exclusión propia. SyncOutboxStore.isDue(id:) acepta estado syncing: marcar una operación no evita que otro consumidor la procese.

Además, queueModeConfiguration usa un ID estable por cuenta/modo. upsertScoped cambia payload, estado e idempotencyKey sobre el mismo objeto SwiftData. El consumidor decodifica pending una vez, pero lee operation.idempotencyKey de nuevo tras cada await. Si otro proceso actualiza la operación, puede enviarse contenido anterior con la clave nueva o eliminarse una revisión nueva cuando termina una vieja. No basta con agregar un booleano de loading ni solo excluir syncing: hace falta preservar revisiones y recuperar operaciones interrumpidas al relanzar.

El backend local IdempotencyService calcula SHA256(JSON.stringify(request)), toma un advisory lock y responde 409 si la misma clave tiene otra operación o hash. Dos peticiones iguales se reproducen desde el resultado; concurrencia por sí sola no demuestra el 409. El endpoint de blocked-items incluye el array items en el hash, por lo que su orden importa. El log recibido tiene un 409, pero no incluye el código del servidor ni IDs de operación que permitan demostrar cuál carrera ocurrió.

Corrección propuesta: un único consumidor de cola por cuenta, snapshot inmutable de payload/clave/revisión, confirmación que no borre una revisión posterior, orden determinista de items y registro del código de error seguro. Probar edición durante envío, dos entradas concurrentes, reintento y relanzamiento con syncing persistido. Pendiente de implementar; el parche preservado NO corrige esta carrera.

### 2. Reinicio de la vista por consulta legal repetida (alta)

ContentView dispara loadLegalRequirements desde una task cuyo ID incluye accessToken e isRestoringSession. Al terminar la restauración, repite la consulta aunque el token no cambie. loadLegalRequirements pone hasCheckedLegalRequirements=false. Los dos arranques recibidos muestran tabs → legal_loading → tabs, retirando la UI y reiniciando el trabajo dependiente.

Corrección propuesta: disparar verificación cuando la restauración haya terminado, coordinar por cuenta/token y descartar resultados obsoletos. Conservar las reglas de aceptación legal, sin permitir acceso ante requisitos pendientes. Pendiente; el parche previo no corrige este disparador.

### 3. Navbar (alta para interacción)

El build 51 usa gesto en contenido interior con padding exterior y withAnimation al seleccionar toda la página. El switch de selectedPage recrea estado y tareas. El log System gesture gate timed out señala demora de gesto, sin stack que determine su origen.

El ajuste de botones con área táctil completa y selección sin animación global fue probado por separado en simulador, pero NO estaba incluido en la copia diagnóstica que ejecutó el usuario. El parche consolidado ahora lo preserva junto a los otros cambios; el conjunto resultante con navbar requiere nueva validación visual y de dispositivo. No se afirma que el parche resuelva el timeout.

### 4. Rituales que empiezan solo al abrir (alta)

DeviceActivityScheduler omite explícitamente rituales de duración menor a 15 minutos. Esos casos dependen del fallback local. Para rituales más largos: confirmar autorización, monitores registrados y callback intervalDidStart, carga de metadata/selection, supresiones y aplicación de shield en la extensión.

reschedule detiene los monitores anteriores antes de crear todos los nuevos; si un startMonitoring intermedio falla, el registro completo de nombres no se guarda. También confía en fingerprint/nombres persistidos sin consultar si el sistema conserva las actividades. Son riesgos comprobables por código, no la causa confirmada de la prueba. No modificar esta lógica sin pruebas de fallos parciales y preservación de bloqueos.

Los logs nuevos registran la app principal, no los callbacks de la extensión. La extensión ya tiene un registro de UserDefaults limitado a 24 eventos compartidos; hace falta recuperarlo o instrumentarlo de forma acotada y con origen. El video mostraba un ritual largo, por lo que la regla de 15 minutos no explica por sí sola ese caso.

### 5. Safari (separado de DeviceActivity)

Se repite WKErrorDomain 6, error de compilación de reglas. El código recarga en cada llamada, usa el mismo archivo compartido y cuando está desactivado produce un array vacío. Hay que capturar la salida de la extensión y validar ambas configuraciones, antes de atribuir el fallo a una regla particular. No es evidencia de que la base remota falle.

## Qué demostraron los logs del iPhone

Dos ejecuciones con versión declarada 1.2 (51), iOS declarado 26.6.1. Todas las fases registradas cierran; ninguna señal main_unresponsive. Pestañas aparecen aproximadamente a 7 s y 1,6 s desde el evento launch. Modos tardan 6,2 s y 4,2 s en sincronizar, sin implicar bloqueo síncrono. Outbox abre en 59/27 ms y reprogramación es rápida en esa captura. El usuario confirmó arranque normal, navbar trabado e inicio de ritual al abrir: no se reprodujo la pantalla azul original en estos logs.

No usar ausencia de señales de cinco segundos para descartar tirones más cortos. signal 9 sin motivo de terminación no identifica crash/watchdog. empty dSYM no explica el funcionamiento. Neon compartido no muestra saturación en las capturas; no se inspeccionaron métricas remotas ni consultas.

## Limpieza y prueba en teléfono

Se mantiene este informe y el código integrado en la rama del build 51. Se retiraron el parche ya aplicado y los ejecutables/scripts temporales de prueba. CONTEXTO_RITUO.txt y Docs/CrashlyticsSetup.md siguen intactos. No hay copia build/diagnostics51 ni cambios publicados.

Abrir HolaSwift.xcodeproj de esta carpeta, seleccionar HolaSwift y el iPhone, y ejecutar. Probar cambios de pestaña, luego un ritual de al menos 15 minutos dejando la app en segundo plano (sin forzar cierre). Después abrir Perfil → soporte y preparar/compartir el diagnóstico. Comparar la hora del inicio esperado con los eventos DeviceActivity incluidos. Ese buffer es limitado y no garantiza retener toda la ejecución.

## Seguimiento de navegación — 10 de septiembre

Nueva consola D5C626DF: GET de rituales 200 en 415/780 ms, cargas completas 1546/1873 ms, modos 11642 ms y un timeout de gesto. No hay evidencia de error HTTP del GET en esa ejecución. El diagnóstico de extensión reenviado era la ruta anterior, ya no disponible.

Se separó el navbar del overlay de la página reemplazable, montándolo como hermano en un ZStack estable. Es un ajuste de estructura, no una confirmación de que resolvió el congelamiento. Se registran navigation.tap, navigation.selection y page.appeared; latencia de la cola principal desde 500 ms cuando responde, conservando la alerta existente a 5 segundos. Estos eventos no capturan la pila bloqueada ni garantizan detectar todas las pausas.

La carga de rituales registra conteos recibidos/publicados y duración de merge, outbox, recreos e historiales. Los timestamps de event se toman al emitir para evitar atribuir a la app retrasos de escritura. El historial local compartido de DeviceActivity pasa de 24 a 256 entradas con fecha y bundle de origen; sigue siendo un buffer UserDefaults de mejor esfuerzo, sin garantía frente a escrituras concurrentes. Se exporta solo al pedir el archivo. No se modificaron reglas de bloqueo ni límites de duración en esta continuación.

## Corrección de reprogramación — 10 de septiembre

Sesión 9FDA027F: tres spans device_activity.reschedule de 31209/31230/31199 ms; main_queue_delay de 31139/30958 ms y ráfagas de toques al recuperar respuesta. GET de rituales de 212/213 ms seguido de merge de ~31 s. Esto localiza la demora en la reprogramación, aunque no identifica todavía la llamada IPC interna.

DeviceActivityScheduler conserva preparación y acceso a stores en MainActor, pero startMonitoring, stopMonitoring y activities se ejecutan en un executor serial de fondo. Todos los comandos de reprogramar, detener y limpiar esperan al comando anterior, evitando intercalar limpieza con un registro suspendido. Las respuestas de error al view model se descartan si cambió la cuenta. La función reschedule del view model ahora encola trabajo y no espera a que el sistema termine.

La huella de selección ordena tokens codificados por tipo; comprueba monitores presentes antes de reutilizar una programación. El fingerprint se invalida antes de reemplazar monitores. Se persisten nombres intentados individualmente para permitir limpieza tras un fallo parcial. Esto no es una transacción: si el sistema rechaza registros puede quedar cobertura parcial hasta un reintento. No se añadieron reintentos infinitos ni se interpretó un timeout como éxito.

Compilación Debug de simulador completada y git diff --check limpio. Falta prueba de DeviceActivity en iPhone: verificar ausencia de bloqueo de UI, tiempos de start/stop y activación fuera de la app. No se publicó ni se cambió la numeración local 1.0 (35), modificada previamente fuera de esta corrección. No se crearon copias del proyecto ni scripts de validación en el repo.

## Orden estable de blocked-items — continuación

Se completó el ajuste recibido del backend en FocusMode y RitualScheduler: codificar tokens con sortedKeys, ordenar identificadores ANTES de enumerar y asignar displayName, y mantener el orden final por tipo/identificador. Ordenar solo el array final dejaba App 1/App 2 asociados a distintos tokens según el recorrido del Set.

Verificación: BUILD SUCCEEDED (Debug simulador), git diff --check y prueba temporal de los getters/helper reales extraídos con tokens String sustitutos: 100 permutaciones por modelo generan el mismo request Codable completo, incluidos nombres. No valida la implementación interna de tokens Apple ni la respuesta de producción. Los archivos temporales de prueba se eliminaron.

Recuperación: retryFailed conserva payload e idempotencyKey y solo restablece intentos/estado. No se migraron cuerpos antiguos ni se rotaron claves. El botón Sincronización → con error permite reintentar tras la corrección del servidor. Una operación histórica que siga devolviendo 409 requiere reconciliación basada en el error del servidor; este cambio no garantiza reparar esas operaciones. Los arreglos backend están desplegados según el informe del equipo, sin verificación remota por esta tarea.
