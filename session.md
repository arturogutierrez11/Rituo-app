# Sesión de trabajo — Rituo iOS

Exportación resumida de la conversación hasta el 16 de noviembre de 2026.
Este documento es un resumen de contexto, no una transcripción literal ni una verificación actual de producción. No incluye contraseñas de la cuenta de revisión.

## Proyecto

- Workspace: `/Users/arturogutierrez/Documents/rituo/apis/HolaSwift`.
- Aplicación SwiftUI con FamilyControls, ManagedSettings y DeviceActivity.
- Backend y frontend relacionados: `../core.api`, `../auth.api`, `../web-rituo-front`.
- Existían numerosos cambios locales previos. Conservarlos; no asumir que todo el diff corresponde a esta sesión.

## App Store y revisión

1. Apple rechazó la versión 1.4 (54), motivo 2.1 — Information Needed: las credenciales de prueba no permitían iniciar sesión.
2. El usuario corrigió la contraseña, pero el envío quedó en «Listo para revisión». Se identificó el botón habilitado «Volver a enviar a revisión de apps» como paso pendiente.
3. El usuario confirmó posteriormente que 1.4 fue aprobada y publicada.
4. Al intentar distribuir otro archivo con versión 1.4, Apple rechazó el train cerrado y exigió una versión superior.
5. Se actualizó el proyecto a 1.4.1 (55). Luego se prepararon cambios con builds 56 y 57.
6. La última captura de App Store Connect, enviada el 2/11/2026, mostraba **1.4.1 — Pendiente de revisión**, desde el 30/10/2026 a las 11:15. Esto confirmó que el envío entró en la cola. La captura no permitía verificar el número de build enviado.
7. No se recibió después una confirmación de aprobación/publicación de 1.4.1. No asumir que sigue pendiente ni que fue aprobada: el estado actual no se consultó.

## Backend y aviso de actualización obligatoria

- Las notas locales indicaban que el cambio de recreos a 1–15 minutos y las restricciones SQL correspondientes se habían aplicado en producción el 24/9/2026. Esa información se leyó de documentación; no se volvió a verificar producción durante esta consulta.
- Existe una pantalla del frontend en `/rituo-admin/app-update`, titulada «Versión de la app».
- Permite configurar `latestVersion`, `latestBuild`, `minimumBuild`, título, mensaje, URL de App Store e `isActive` para iOS.
- El backend calcula actualización disponible si `currentBuild < latestBuild`; obligatoria si `currentBuild < minimumBuild`, con configuración activa.
- El usuario quiso obligar a actualizar a 1.4 (54). Se indicó usar última versión 1.4, última build 54, mínima 54 y estado activo, siempre que 54 fuera la build publicada.
- No se modificó esa configuración remotamente ni se verificó que el usuario la hubiera guardado.

## Selector de aplicaciones de Apple vacío

- El usuario informó que FamilyActivityPicker mostraba categorías pero ninguna app dentro.
- Se leyó `/Users/arturogutierrez/Desktop/rituo-diagnostics.txt`: versión 1.4 (54), lentitud y timeouts HTTP; sin información suficiente del selector o de la autorización para confirmar causa.
- El código solicitaba autorización individual; la lista del selector proviene del sistema, no del backend.
- Se encontraron reportes de terceros en los foros de Apple sobre categorías que no se expanden correctamente. Fueron hipótesis, no demostración de la causa.
- Se propuso probar desplazamiento, búsqueda, reapertura y reinicio, y solicitar video y contexto (modo o ritual). No quedó confirmada la causa ni una corrección específica de este problema.

## Ritual que no iniciaba con la app cerrada después de NFC

### Evidencia

- Diagnósticos: `/Users/arturogutierrez/Downloads/rituo-diagnostics 2.txt` y `rituo-diagnostics 3.txt`.
- Ritual «Mañanero», previsto a las 10:36.
- El 23/10, lanzamiento de Rituo a las 11:47:01 y aplicación del ritual por la extensión a las 11:47:05.
- El usuario confirmó que había detenido el ritual con NFC dos días antes y que los días siguientes no se activaron automáticamente.
- El diagnóstico posterior mostró fin del monitor y liberación a las 12:03:54, coincidiendo con otra detención por NFC. No mostraba el inventario de monitores futuros.

### Defecto y corrección local

- Detener una ocurrencia con NFC eliminaba los monitores semanales de ese ritual; la reprogramación excluía rituales temporalmente suprimidos.
- Recuperar la programación dependía de una ejecución posterior de la app.
- Se conservaron los monitores durante la supresión y se quitó su detención al restaurar una supresión guardada.
- La extensión ya compara el vencimiento de la supresión, permitiendo la siguiente ocurrencia sin que la app borre la marca.
- Se adelantó la comprobación de supresión para evitar que una ocurrencia suprimida interrumpiera un modo activo.
- Se conservó el filtro previo de notificaciones separado de la programación de DeviceActivity.
- El defecto identificado correspondía a la detención anticipada con NFC. No se demostró que el fin natural borrara la programación ni que afectara a todos los rituales.

### Validación y pendientes

- Pasaron `Tests/run_ritual_recurrence_regressions.py`, `Tests/run_monitor_regressions.py`, compilación Release para simulador y `git diff --check`.
- Documento: `Docs/Correccion-rituales-cerrada-20261023.md`.
- El usuario indicó que instaló una nueva versión en TestFlight e hizo pasos de prueba, pero no aportó todavía evidencia de la siguiente ocurrencia automática.
- Validar en iPhone tanto después de NFC como después del fin natural: no abrir Rituo antes del próximo inicio y probar una app bloqueada. Exportar diagnóstico después de observar el resultado, anotando horarios y build.

## Protección del permiso de Tiempo en pantalla

- El usuario preguntó cómo impedir apagar el interruptor de autorización de Rituo en Ajustes y comparó con Opal.
- La respuesta inicial de que no había protección fue demasiado categórica; se corrigió tras consultar la guía de Opal.
- Opal documentaba que desde iOS 26.4 un código de Tiempo en pantalla puede proteger la retirada del acceso.
- No se comprobó en dispositivo que Rituo recibiera esa protección ni que pudiera deshabilitar dinámicamente el interruptor durante una sesión.
- Se agregó una guía en `HolaSwift/Views/Profile/ProtectionSettingsView.swift`: Perfil → Protección → Proteger el permiso de Rituo.
- Explica configurar el código en Ajustes y comprobar que lo solicite intentando retirar el permiso y cancelando. Avisa para versiones anteriores a iOS 26.4.
- No consulta ni cambia el código, no marca protección como verificada y no bloquea programáticamente el interruptor.
- La compilación Release pasó. Sigue pendiente validación en iPhone de la protección del sistema.

## Notificaciones y aclaración de formato

- Primero se interpretó la solicitud como una notificación expandida al mantener presionado el aviso.
- Se prepararon textos, subtítulos, agrupación, acción «Abrir Rituo», helper `Shared/RituoNotificationStyle.swift` y una extensión `RituoNotificationContent` con tarjeta personalizada. Se informó compilación Release y pruebas de callbacks aprobadas para build 56.
- Más adelante, al trabajar en Live Activities, el proyecto encontrado ya no incluía el target de notificación expandida y seguía en build 55, aunque existían archivos locales. No se restauró automáticamente ese target: revisar el proyecto actual antes de asumir que la tarjeta expandida está embebida.
- El usuario compartió una imagen de Uber con progreso en pantalla bloqueada: el formato que quería era **Live Activity**, no el banner compacto ni la notificación expandida.

## Actividades en vivo — implementación local de 1.4.1 (57)

### Archivos principales

- `Shared/RituoFocusActivityAttributes.swift`.
- `HolaSwift/Services/FocusLiveActivityService.swift`.
- `HolaSwift/Services/LiveActivitySchedulePlanner.swift`.
- `RituoLiveActivity/RituoLiveActivityWidget.swift` e `Info.plist`.
- Integración en `ContentView.swift`, `BlockSetupViewModel.swift`, `Config/HolaSwiftInfo.plist` y proyecto Xcode.
- Documento: `Docs/Live-Activities.md`.

### Comportamiento

- Tarjeta en pantalla bloqueada y presentaciones compacta, mínima y expandida de Dynamic Island.
- Nombre de sesión, contador nativo por fechas y progreso; contador específico durante recreos.
- ActivityKit no modifica ni sustituye DeviceActivity ni el bloqueo real.
- La app coordina una tarjeta actual y, desde iOS 26, programa la ocurrencia futura más próxima con inicio diferido y alerta del sistema.
- No programa toda la semana. Se vuelve a elegir la próxima ocurrencia al ejecutar la app; no se garantiza una tarjeta nueva cada día sin volver a abrir Rituo.
- En versiones anteriores a iOS 26, inicia la tarjeta con la app activa.
- Al llegar al fin previsto, al fin de recreo o al límite de ocho horas, el contenido vence y muestra «Por actualizar»; pide abrir Rituo.
- No se implementaron APNs ni actualizaciones desde la extensión DeviceActivity. No se garantiza transición automática recreo → foco ni retirada inmediata al fin del horario con la app terminada.
- Al procesar una detención/NFC, cambio de cuenta o pérdida de permiso, la app retira tarjetas que ya no corresponden.
- Respeta la desestimación durante la ejecución del proceso actual, no persistentemente entre reinicios.
- Los errores de ActivityKit no deben impedir el bloqueo.

### Verificación realizada

- `Tests/run_live_activity_timing.py`: próxima ocurrencia, medianoche, siguiente semana, ambos cambios DST, horarios vacíos o de duración cero.
- `Tests/run_live_activity_lifecycle.py`: coordinador real con adaptador simulado; reutilización, recreo, desestimación, cambio de cuenta, cierre en background y permiso denegado.
- Compilación Release de simulador: correcta.
- Se comprobó que `RituoLiveActivity.appex` estaba embebida y declaraba 1.4.1 (57).
- `git diff --check`: correcto.
- No se verificó la presentación real en iPhone. No se subió la build a TestFlight desde esta sesión.

## Textos redactados para App Store

### Español — Texto promocional

Recuperá tu tiempo con Rituo. Bloqueá distracciones, organizá tus rituales y hacé espacio para lo que importa con ayuda de tu tarjeta NFC.

### Español — Novedades

- Incorporamos Actividades en vivo para consultar el tiempo de foco y los recreos desde la pantalla bloqueada.
- Corregimos un problema que impedía activar automáticamente los próximos rituales después de detener uno con NFC.
- Agregamos una guía para proteger el permiso de Tiempo en pantalla con un código.
- Mejoramos la estabilidad y la sincronización.

### English — Promotional Text

Take back your time with Rituo. Block distractions, build focus rituals, and make room for what matters with the help of your NFC card.

### English — What’s New

- Added Live Activities to view focus and break timers from your Lock Screen.
- Fixed an issue that could prevent future rituals from starting automatically after stopping one with NFC.
- Added a guide to protect Screen Time access with a passcode.
- Improved stability and syncing.

Estos textos fueron propuestas; comprobar que correspondan a la build efectivamente enviada.

## Referencias consultadas

- Estados de App Store Connect: https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses
- Reenvío tras problemas: https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/manage-a-submission-with-unresolved-issues
- FamilyActivityPicker: https://developer.apple.com/documentation/familycontrols/familyactivitypicker
- DeviceActivityCenter: https://developer.apple.com/documentation/deviceactivity/deviceactivitycenter
- Protección documentada por Opal: https://opalapp.com/help/how-to-lock-opals-screen-time-access
- Notificaciones personalizadas: https://developer.apple.com/documentation/usernotificationsui/customizing-the-appearance-of-notifications
- ActivityKit: https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
