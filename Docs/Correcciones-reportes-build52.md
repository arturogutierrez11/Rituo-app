# Revisión y correcciones de reportes del build 52 — 21 de septiembre

Se revisó el diff local existente sin reemplazarlo ni publicar cambios. Los archivos zxczx.txt y rituo-diagnostics.txt son idénticos; se contaron una sola vez. Los dos reportes distintos contienen 17 sesiones, 21 errores 400 al guardar recreos, callbacks repetidos de fin de recreo, errores 401/409 y fallas de servicio/transporte. No identifican la causa exacta de cada rechazo HTTP ni permiten asignar tiempos de CPU.

## Cambios locales conservados

- Coordinación de cargas y de operaciones de configuración; snapshots de revisión para actualizar modos y rituales.
- Reprogramación principal de DeviceActivity mediante executor serial de fondo.
- Navegación con botones y contenedor estable.
- Orden determinista de tokens en blocked-items.
- Expiración de ocurrencias y marcas de rituales eliminados para evitar reaplicar restricciones obsoletas.
- Ajustes legales, Safari y diagnóstico existentes.

## Correcciones agregadas

- Los recreos se persisten antes de enviarse, con su configuración exacta. Las operaciones antiguas sin el campo opcional siguen siendo decodificables.
- Los reintentos conservan la operación y su revisión: espera exponencial, máximo de ocho intentos automáticos y estado fallido inmediato ante 400/404/422. El reintento manual sigue disponible. No se cambian claves para intentar esconder conflictos 409.
- Un único consumidor por cuenta y tipo procesa recreos. Una respuesta vieja no elimina una revisión nueva ni confirma operaciones después de cambiar de cuenta/token.
- La lectura de recreos no pisa operaciones locales pendientes o fallidas. El estado activo, métricas e historiales descartan respuestas de otra cuenta/token.
- La cuenta y el token no disparan sincronización desde el estado cacheado durante la restauración inicial.
- Los callbacks de fin de recreo se serializan en la extensión y requieren metadata vigente; un callback repetido o reentrante tras la limpieza no vuelve a notificar ni a reconciliar. Esta protección es por proceso, no una transacción entre la app y todas las instancias posibles de la extensión.
- El heartbeat conserva una actividad todavía registrada y no vencida. El fin de un heartbeat antiguo se ignora y la cancelación borra su identidad antes de llamar al sistema.
- Si el servidor rechaza una eliminación y se restaura el ritual, se retira también su marca de eliminado. La respuesta de una eliminación de otra cuenta no restaura rituales en la cuenta actual.
- Release registra hasta 30 fases lentas (>=500 ms), 20 demoras de cola principal y hasta tres reportes de bloqueo por sesión. Las llamadas síncronas restantes de DeviceActivity tienen spans de diagnóstico. No se registran tokens ni cuerpos HTTP.

## Pruebas reproducibles

`python3 Tests/run_sync_regressions.py`: compila las funciones reales de sincronización con SwiftData en memoria y API simulada. Cubre espera, máximo de intentos, errores de validación, conservación de payload y ediciones pendientes, respuesta vieja tras edición, cambio de cuenta y compatibilidad de payload anterior.

`python3 Tests/run_monitor_regressions.py`: ejecuta los handlers reales con un DeviceActivity simulado. Cubre callback duplicado/reentrante para modo y ritual, reutilización del heartbeat, reemplazo por vencimiento y cancelación.

Estos ejecutables usan el SDK macOS de Xcode; no acceden a servicios de Rituo ni validan el comportamiento interno de Screen Time. La compilación de macros SwiftData puede requerir permiso fuera del sandbox.

## Resultado de validación local

- Compilación Debug para simulador: correcta.
- Compilación Release para simulador: correcta; incluye la instrumentación habilitada en producción.
- Pruebas ejecutables de sincronización: correctas, incluido máximo de ocho intentos y decodificación de payload anterior.
- Pruebas ejecutables de callbacks/heartbeat: correctas.
- `git diff --check`: sin errores.

## Validación pendiente en iPhone y servicio

- Iniciar sesión con token vencido y comprobar que el outbox empieza después de restaurar la sesión.
- Cambiar recreos sin conexión, recuperar conexión y comprobar persistencia y límites de reintento.
- Finalizar recreos con la app en segundo plano: una notificación, restricciones correctas y sin ráfaga de heartbeats.
- Eliminar un ritual, incluyendo rechazo del servidor, y verificar que el estado restaurado vuelve a programarse.
- Exportar diagnóstico Release ante tirones: las llamadas síncronas restantes a DeviceActivity están instrumentadas, todavía no se trasladaron todas a un executor de fondo.
- El origen de los 400/409 y la indisponibilidad 521 requieren correlación con respuestas/códigos y logs del servicio. No se modificó el backend ni se probó producción.

La creación de rituales durante una edición concurrente y la renovación de credenciales entre múltiples clientes aún merecen una revisión específica. No se afirma que estos cambios resuelvan todos los problemas de producción.

## Continuación de pendientes — 21 de septiembre

Se implementaron estos cambios adicionales:

- La creación conserva cuerpo, contraseña y clave de idempotencia del primer POST, incluso si se edita el ritual mientras se envía o si una carga vuelve a encolarlo. Se guarda el ID remoto antes de enviar los elementos bloqueados. Las ediciones posteriores se convierten en un PATCH pendiente y la respuesta de creación conserva la protección local editada.
- `SessionTokenCoordinator` comparte la renovación entre restauración de autenticación y core-api. Una renovación en curso se comparte, un 401 atrasado reutiliza el token ya renovado y el cambio de sesión/cierre de sesión invalida respuestas viejas. Se eliminó el token renovado global sin asociación a una sesión de CoreApiService.
- Las llamadas start/stop de recreos, fin de modo y heartbeat salen del hilo principal. La preparación de metadata queda en MainActor y las operaciones de cada programador mantienen orden a través de sus suspensiones; el IPC usa una cola serial de fondo compartida.
- El backend local `../core.api` validaba 1–5 minutos, mientras la app permitía 1/3/5/10/15. Se preparó y aplicó localmente el ajuste a 1–15, incluidos tests y reemplazo del CHECK SQL anterior en `ensureSchema`. Esto demuestra una incompatibilidad local capaz de producir 400; no demuestra que cada 400 recibido tenga ese motivo ni verifica qué commit está desplegado.

Validación de esta continuación:

- Release simulador compila sin errores ni warnings de aislamiento de actores en la última compilación.
- Debug para iPhone compila y firma correctamente. Se detectó el iPhone 13 de Arturo; la app todavía no se instaló ni se probó allí.
- `Tests/run_session_regressions.py`: pasó (diez renovaciones concurrentes comparten una petición, 401 atrasado, cambio de cuenta/cierre de sesión, cola FIFO fuera del hilo principal).
- Backend: dos suites y 38 tests aprobados para modos y rituales, incluidos 10/15 minutos y rechazo de límites inválidos.
- Se agregó `Tests/creation_harness.swift`, integrado en `run_sync_regressions.py`, para edición durante creación, snapshot de contraseña/clave/cuerpo y recuperación después de crear el recurso pero fallar los elementos bloqueados. La primera compilación del harness falló por un alias de tipo faltante; se corrigió el adaptador. La repetición solicitada quedó sin ejecutar porque se rechazó su permiso. Estos casos nuevos NO se declaran aprobados.
- `git diff --check` limpio en ambos repositorios.

Pendientes reales restantes:

1. Ejecutar el harness de creación corregido antes de instalar la app de prueba.
2. Validar en iPhone los recreos/background, inicio con token vencido y borrado rechazado, con los diagnósticos nuevos.
3. Probar la actualización del CHECK en una base PostgreSQL de prueba. Los tests de servicio usan repositorios simulados; no se ejecutó la migración SQL sobre una base real.
4. Desplegar coordinadamente el backend cuando corresponda. Nada fue desplegado ni se tocó la base de producción. Ese mecanismo automático fue retirado el 23 de septiembre: ahora la migración es exclusivamente manual.
5. Correlacionar los 409 con el código de error del servidor y revisar los 521 con logs del servicio. No se cambió la política de negocio para aceptar conflictos a ciegas.


## Validación PostgreSQL aislada — 23 de septiembre

Se retiró del `ensureSchema` del backend el ALTER automático sobre tablas existentes. Se mantienen únicamente los CREATE TABLE IF NOT EXISTS; los archivos de migración manual viven en `core.api/migrations/manual/20260923-break-duration/`. No se desplegó el backend, no se inició el backend local y no se abrió conexión a producción.

Se ejecutó `Tests/run_break_migration.py` con PostgreSQL 17 instalado en la Mac. El script creó un cluster nuevo dentro de /tmp, con usuario de prueba, socket Unix privado, TCP desactivado y ambiente sin variables de conexión productiva. Las tablas iniciales se construyeron a partir del SQL original del repositorio y se cargaron solamente datos inventados. Al terminar se detuvo y eliminó esa instancia temporal.

Resultados:

- Los datos preexistentes permanecieron idénticos después de ampliar y validar los CHECK.
- Duraciones 1/3/5 siguen siendo válidas; 10/15 también pasan. Se rechazan 0/16 y más de tres recreos.
- La migración usa NOT VALID para separar el cambio breve de reglas del escaneo de validación. Las nuevas escrituras quedan verificadas desde el primer paso.
- Al bloquear deliberadamente la segunda tabla, el primer paso falló por lock_timeout en 0,52 s y se revirtieron AMBAS tablas, incluida la primera ya alterada dentro de la transacción.
- Repetir la expansión ya aplicada falla sin modificar registros; no se ignoran nombres inesperados de restricciones.
- La validación final completó con otra transacción de escritura todavía abierta.
- Se repitieron las dos suites de servicios del backend: 38 pruebas aprobadas.
- `git diff --check` limpio en ambos repositorios.

Evidencia reproducible: `Tests/break_migration_result.json`. Estos resultados resuelven la prueba de PostgreSQL pendiente; no miden el volumen, carga ni tiempos de producción, y no garantizan un redeploy sin interrupciones. Los tiempos límite reducen la espera, no eliminan el bloqueo breve requerido por ALTER.

Antes de producción siguen pendientes revisar el mecanismo de disponibilidad/rollback del hosting, elegir una ventana de poco tráfico y ejecutar cada paso manualmente con observación del resultado. Luego se despliega por separado el backend compatible. No ejecutar los SQL antiguos de este documento/conversación: usar la migración manual revisada cuando se autorice ese paso. La prueba de creación de rituales y la prueba en iPhone siguen pendientes como se indicó anteriormente.

## Entorno local y simulador — 23 de septiembre

- Preparado `Tests/local-stack/run.py`: compila el Core API actual en un directorio temporal, crea un PostgreSQL nuevo con socket privado sin TCP y datos ficticios, y arranca la API solo en `127.0.0.1:3000`. No carga el `.env` productivo ni hereda variables de conexión. Autenticación de prueba en `127.0.0.1:3001`, con clave JWT aleatoria y sesión ficticia comprobada por el guard real de Core API.
- Prueba HTTP aprobada para rituales/modos: guardar y recuperar 1, 2, 3, 5, 10 y 15 minutos; rechazar 0, 16 y 1.5 sin sustituir el valor válido anterior. Ver `Tests/local-stack/result.json`.
- Compilación Debug del simulador aprobada sin warnings reportados por XcodeBuildMCP. Se verificaron los dos endpoints locales en el Info.plist compilado antes de instalar. Configuración optativa `Config/LocalSimulator.xcconfig`; Firebase no se configura en este modo.
- App instalada y abierta en iPhone 17 Pro simulado, sin instalar en el iPhone físico. Login ficticio y consultas de rituales/modos/recreos desde la app respondieron correctamente. El flujo visual quedó en la autorización del sistema de Screen Time, pantalla “Allow with Passcode”. No se completó la edición visual ni se validó el bloqueo en segundo plano.
- El esquema es una fixture mínima, no una copia de producción. Una consulta NFC inicial falló por faltar las tablas ficticias; se añadieron vacías al esquema y al clúster local. No se consultaron datos productivos.
- Hallazgo para revisar antes del redeploy: ya existen ALTER de restricciones al arrancar en `SQLModeSessionsRepository.ensureSchema` y `SQLAppUpdatesRepository.ensureSchema`. No forman parte del diff nuevo ni se cambiaron aquí. La migración de duración de recreos es manual; esa afirmación no se extiende a todo el backend.
- Este chequeo HTTP no reemplaza el harness Swift de creación previamente pendiente ni demuestra compatibilidad de todos los flujos de la versión iOS publicada.

Instrucciones de arranque, alcance y apagado: `Tests/local-stack/README.md`. No se hizo push, deploy ni migración en producción.

## Prueba visual local — 24 de septiembre

### Publicación autorizada — activa en DigitalOcean

- El usuario ejecutó en Neon producción la expansión y validación de las dos restricciones de recreos. Aportó las cuatro filas de pg_constraint: duración 1–15 validada en ambas tablas, cantidad 0–3 conservada.
- Con autorización explícita, se creó y publicó en `HUA-HUM/core.api` rama main el commit `a7a0948302769cb5365f0f7ee80cd514477ac401`. El remoto anterior era d3f8a5b7470de2cc3097b672119557a00fe76e57, igual al despliegue conocido. Push confirmado; repositorio backend limpio.
- Incluye 8 archivos de código/pruebas y 3 archivos de migración manual/documentación. No se publicaron los cambios iOS ni las fixtures locales. La migración no se ejecuta automáticamente.
- La captura aportada por el usuario del 24 de septiembre a las 12:50:48 muestra `a7a0948` como Live deployment, Healthy y activado a las 12:50:41. Después de esa confirmación se consultaron /health y /health/db: respondieron ok y connected. Sigue pendiente la prueba funcional productiva con la app publicada y la nueva compilación en iPhone; estos chequeos no la reemplazan.
- Este estado supersede las notas históricas de abajo que indican que no hubo push, despliegue o migración. La base productiva ya acepta 1–15 y el backend nuevo está activo.

### Revisión final del arranque con evidencia de producción

El usuario aportó el catálogo de restricciones de Neon: `mode_sessions_end_source_check`
incluye manual/nfc/emergency/schedule y `app_update_configurations_platform_check`
incluye ios/android; ambas están validadas. Los dos CHECK de duración de recreos
siguen validados en 1–5.

Se retiraron LOCALMENTE los bloques DROP/ADD de restricciones al arrancar en
SQLModeSessionsRepository y SQLAppUpdatesRepository. La inicialización de modos
no ejecuta DDL; las instalaciones antiguas deben migrar su esquema manualmente.
Para tablas nuevas, app_update_configurations declara el CHECK ios/android en
CREATE TABLE IF NOT EXISTS. Las tablas existentes no se alteran.

Este ajuste agrega dos archivos de backend al alcance inicial de recreos. TypeScript
sin emisión pasó, las 19 suites / 105 pruebas del backend pasaron y git diff --check
está limpio. No se hizo deploy ni se ejecutó la migración en producción. El backend
anterior, si se restaura, conserva sus antiguos bloques DDL de arranque; tenerlo en
cuenta en el rollback. Dejar la base con rango 1–15 al revertir la API evita tener
que eliminar o recortar datos nuevos. Pendiente ejecutar expansión, validación y
verificación manual de los CHECK antes del push que dispara el despliegue.

### Continuación con identidad demo local

- Se agregó `--demo-account` al entorno temporal: usa el correo que activa el modo demo con contraseña ficticia y JWT local. No se usó la contraseña productiva ni se inició sesión en producción.
- `POST /nfc-tags/review-demo/prepare` y la lectura de tags respondieron 200. El usuario completó la selección de apps y activación demo de Gimnasio.
- La pantalla mostró modo activo, 13 bloqueos y 2 recreos de 15 minutos. `POST /mode-sessions/start` respondió 201. PostgreSQL local confirmó Gimnasio, break_count=2, break_duration_minutes=15, status=active.
- Se inició un recreo desde la UI: “RECREO ACTIVO”, 14:59 y “acceso libre”. Tras detener y relanzar el proceso, se restauró con 14:50 restantes, sin reiniciar la cuenta regresiva.
- Se envió la app a segundo plano con Home. Al registrar esta evidencia, el vencimiento automático todavía no había ocurrido y NO se da por validado. Tampoco se comprobó acceso a una app bloqueada ni su rebloqueo efectivo. El simulador no sustituye la prueba física.

- Se reconstruyó Debug con LocalSimulator.xcconfig, se verificaron ambos endpoints loopback en el Info.plist y se reiniciaron los servicios ficticios. La prueba HTTP volvió a pasar.
- El usuario completó manualmente la autorización de Screen Time. La app entró al inicio y pudo listar los rituales locales.
- Se creó desde la interfaz un ritual de 17:00 a 18:00 con 2 recreos de 15 minutos. El selector de duración requirió interacción manual: la herramienta de accesibilidad no lo expone como elemento accionable y el control de escritorio no tenía permisos. El teclado corrigió el nombre de prueba a `Prunes UI rector 15`.
- POST /rituals, /blocked-items y /breaks respondieron 201. Consulta directa, exclusivamente por el socket del PostgreSQL temporal, confirmó el ritual `5feb0bb5-492e-42b7-953d-842c06f5831d` con break_count=2 y break_duration_minutes=15.
- Tras detener y relanzar la app, el ritual reapareció y GET de sus recreos respondió 200. No se verificó todavía el valor en la pantalla de edición tras relanzar.
- Iniciar un modo presentó el requisito de vincular un tag NFC a la cuenta ficticia. No se simuló un tag ni se completó la activación de modos. Los modos están probados por HTTP, no de extremo a extremo por UI.
- Sigue pendiente comprobar la ejecución real de recreos/bloqueos en segundo plano en un iPhone, la versión iOS publicada y el harness Swift de creación. Ningún resultado local garantiza disponibilidad del redeploy.
- No se hizo push, despliegue ni escritura en producción.
