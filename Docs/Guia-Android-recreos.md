# Recreos de Rituo: guía de integración para Android

Fecha: 27/09/2026. Contrato verificado contra core.api commit a7a0948302769cb5365f0f7ee80cd514477ac401 y código local iOS. No se ejecutaron escrituras productivas para elaborar esta guía. Las propuestas de arquitectura Android se distinguen del comportamiento existente; no se inspeccionó el repositorio Android.

## 1. Qué guarda cada parte

Hay tres conceptos diferentes:

| Concepto | Responsable | Persistencia |
|---|---|---|
| Configuración: cantidad disponible y minutos por recreo | Core API | PostgreSQL: mode_breaks o ritual_breaks |
| Sesión de enfoque: inicio y final del modo/ritual | API de sesiones + cliente | mode_sessions / ritual_sessions |
| Recreo en curso: consumo, inicio, vencimiento y desbloqueo temporal | App | Estado local persistente y mecanismo de ejecución del sistema operativo |

**POST /modes/{id}/breaks no inicia un recreo. Guarda la configuración.** Lo mismo aplica a rituales. Hoy no hay un endpoint de consumo/inicio/fin de recreos ni una tabla de eventos de recreos en este contrato. El servidor tampoco devuelve cuántos recreos se consumieron ni manda una orden al teléfono para volver a bloquear.

Android NO debe conectarse directamente a Neon/PostgreSQL ni incluir credenciales de base de datos. Al guardar mediante la API, el backend registra la configuración automáticamente.

## 2. Entorno y autenticación

Base URL productiva: `https://api.rituo.io` (sin prefijo /api ni /v1 en el código revisado).

Todas las rutas descritas de recreos requieren:

```http
Authorization: Bearer <ACCESS_TOKEN_DEL_USUARIO>
Accept: application/json
Content-Type: application/json
```

Content-Type es necesario para el POST JSON. Usar el access token del login existente, no un refresh token ni una API key interna. El backend obtiene el usuario autenticado y verifica que el modo/ritual sea suyo. No enviar email, userId ni contraseña en el body de recreos.

El ID de la URL es el ID remoto del modo/ritual, no el ID de sesión ni un identificador temporal generado por Android. Un recurso inexistente o de otro usuario produce 404. Usar UUID reales devueltos por la API; no depender del código de error de un UUID malformado.

## 3. Contrato HTTP exacto

| Operación | Método y ruta | Éxito |
|---|---|---|
| Leer configuración de modo | GET /modes/{modeId}/breaks | 200 |
| Guardar/reemplazar configuración de modo | POST /modes/{modeId}/breaks | 201 |
| Leer configuración de ritual | GET /rituals/{ritualId}/breaks | 200 |
| Guardar/reemplazar configuración de ritual | POST /rituals/{ritualId}/breaks | 201 |

No usar PATCH para estos subrecursos. El POST guarda tanto la primera vez como las siguientes. No necesita Idempotency-Key en el controlador de recreos revisado; no confundirlo con las operaciones de creación de recursos o sesiones.

### Guardar dos recreos de quince minutos

```http
POST /modes/<MODE_UUID>/breaks
Authorization: Bearer <ACCESS_TOKEN>
Content-Type: application/json

{
  "breakCount": 2,
  "breakDurationMinutes": 15
}
```

Respuesta 201, objeto directo sin wrapper `data`:

```json
{
  "modeId": "<MODE_UUID>",
  "breakCount": 2,
  "breakDurationMinutes": 15
}
```

Para rituales el body es idéntico, la ruta cambia y la respuesta usa `ritualId`:

```json
{
  "ritualId": "<RITUAL_UUID>",
  "breakCount": 2,
  "breakDurationMinutes": 15
}
```

GET devuelve el mismo formato con estado 200. No incluye createdAt, updatedAt, breakId, usados, restantes ni vencimiento.

### Desactivar recreos

Enviar preferentemente ambos campos:

```json
{
  "breakCount": 0,
  "breakDurationMinutes": 5
}
```

También se permite omitir la duración cuando breakCount es 0; el backend usa 5. Se puede conservar una duración válida entre 1 y 15 para futuras ediciones. **No enviar duración 0**, tampoco con cantidad 0.

### Valores admitidos

| Campo | Regla |
|---|---|
| breakCount | Número entero de 0 a 3; obligatorio |
| breakDurationMinutes con cantidad > 0 | Número entero de 1 a 15; obligatorio |
| breakDurationMinutes con cantidad = 0 | Puede omitirse; default 5. Si se envía, Android debe exigir entero 1–15 |

La duración es por recreo: 2 × 15 significa dos recreos independientes de 15 minutos, no dos partes de un total de 15. El contrato permite todos los enteros 1–15, no únicamente 5/10/15. No enviar cadenas como "15", decimales ni segundos.

Detalle de implementación actual: la validación de duración del servicio solo corre cuando breakCount > 0. Con cantidad 0 y duración inválida, el valor puede llegar a PostgreSQL y fallar allí, en lugar de producir el 400 normal. Es una limitación conocida del contrato actual; Android debe validar ambos campos y no asumir que 0/0 desactiva recreos correctamente.

### Recurso sin configuración guardada

Si existe el modo/ritual y pertenece al usuario, pero no existe fila de recreos, GET responde 200 con cantidad 0 y duración 5. Es un valor por defecto calculado; GET no inserta una fila. No tratarlo como fallo ni como autorización para borrar cambios locales pendientes.

## 4. Flujos de creación, edición y lectura

### Crear un modo o ritual

1. Crear el recurso con el endpoint de modos/rituales ya integrado por Android.
2. Guardar inmediatamente el ID remoto retornado.
3. Guardar la selección de apps/sitios con su operación correspondiente.
4. POST a /{modes|rituals}/{id}/breaks con la configuración elegida.
5. Aplicar la respuesta a la caché y marcar la configuración como sincronizada.

Estas son operaciones separadas: no hay una transacción HTTP que incluya recurso, selección y recreos. Si el recurso se creó pero falló guardar los recreos, reintentar el POST de recreos sobre el mismo ID; no crear otro modo/ritual. No mostrar todo como sincronizado mientras quede un paso pendiente.

### Editar

Leer la configuración, editar ambos valores, validar, hacer POST y conservar la respuesta confirmada. Esta operación reemplaza la configuración, no incrementa cantidad ni acumula filas. No descontar breakCount al consumir un recreo: ese campo es el cupo configurado.

### Cargar/listar

Obtener la configuración con su GET explícito. No asumir que listar modos o rituales ya trae este subrecurso. Limitar concurrencia y guardar caché por usuario + tipo + ID remoto; no recargar todos los recreos en cada render de pantalla.

### Fallas de red y cambios rápidos

Recomendación Android: outbox persistente por usuario/tipo/ID con payload completo, revisión local, estado pendiente y número de intentos. Serializar escrituras por recurso. Si se guarda A y luego B, una respuesta tardía de A no debe reemplazar B ni eliminar su pendiente. Reintentar un timeout puede volver a escribir el mismo valor; el upsert evita filas duplicadas, pero no evita que una petición antigua sobrescriba otra nueva. No hay ETag/versionado para resolver conflictos entre dispositivos: gana la última escritura procesada.

Un GET remoto antiguo no debe pisar una edición local pendiente. Aislar las operaciones por cuenta y descartar resultados tardíos tras logout/cambio de usuario. No enviar payloads de una cuenta con el token de otra.

## 5. Iniciar y terminar un recreo en Android

Referencia del código iOS: startModeBreak/startRitualBreak comprueban contexto activo, ausencia de otro recreo del mismo tipo y cupo; consumen uno, persisten el vencimiento, levantan el bloqueo correspondiente y programan su restauración. No llaman al endpoint de configuración para consumirlo.

Arquitectura propuesta para Android, no código existente:

```text
startBreak(context):
  serializar la operación
  verificar usuario, sesión vigente, cupo y ausencia de recreo activo
  crear breakId local único
  calcular inicio y vencimiento = inicio + minutos * 60
  persistir atómicamente consumo + estado del recreo
  preparar mecanismo de vencimiento fuera de la pantalla
  suspender los bloqueos correspondientes a este contexto
  mostrar cuenta regresiva a partir del vencimiento

reconcileBreak(event):
  leer estado persistente
  verificar usuario y generación de sesión
  si la sesión terminó: limpiar recreo; no reactivar una sesión vieja
  si todavía no venció: mantener recreo y calcular restante
  si venció: recomputar bloqueos vigentes y cerrar recreo de forma idempotente
```

Definir recuperación si no se puede programar el vencimiento o aplicar el desbloqueo. No dejar al usuario sin protección indefinidamente por una excepción entre pasos. Un doble toque debe consumir solo uno. Un callback repetido debe finalizar una sola vez.

### Persistencia local propuesta

Guardar al menos:

- userId, tipo (mode/ritual), resourceId remoto.
- Identificador/generación de sesión local y sessionId remoto si ya existe.
- Cupo/duración usados como referencia para esa sesión, contador usado y marcador de ciclo.
- breakId local, startedAt, endsAt, estado y revisión.
- Información necesaria para recomponer las restricciones de la sesión vigente.

Esto puede vivir en una base local transaccional. Es un modelo propuesto, no nombres de columnas existentes en PostgreSQL. El temporizador de UI es solamente una representación: cerrar la pantalla o matar el proceso no debe reiniciar el recreo ni devolver cupo.

Para medir intervalos durante el mismo arranque, considerar reloj monotónico; conservar además datos suficientes para recuperación después de reinicio. Definir y probar cambios manuales de fecha/zona horaria. No prometer resistencia absoluta a manipulación con control puramente local.

La selección del mecanismo Android de ejecución en segundo plano depende de la arquitectura actual, versión/target SDK y permisos. Esta guía no prescribe un servicio o alarma concreta sin revisar ese código. Debe probarse vencimiento con pantalla apagada, proceso terminado, restricciones de batería y reinicio. Forzar detención desde Ajustes tiene restricciones distintas de cerrar la UI y debe documentarse aparte.

### Reglas de consumo observadas en iOS

- El cupo se consume al iniciar el recreo, no al finalizarlo.
- Cerrar y reabrir conserva consumo y vencimiento.
- Modos: el código renueva cupo al cambiar de día calendario local; también contempla terminar/reiniciar el modo para obtener cupo nuevo. No son 24 horas desde el primer uso.
- Rituales: el consumo corresponde a la ejecución del ritual; no aplicar automáticamente la renovación diaria de modos a un ritual en curso.
- Android debe acordar qué ocurre al editar configuración durante una sesión. Se recomienda una configuración estable por ejecución; no se presenta esto como garantía del código iOS.
- Si el ritual termina antes que el recreo, prevalece el fin de la sesión: un callback viejo no puede volver a bloquearla.
- Si hay restricciones de otros contextos, recomponerlas. No hacer un desbloqueo global indiscriminado.
- El modo estricto es otra política. Un recreo no implica desactivar toda protección global. Su implementación iOS no se traslada directamente a Android.

## 6. Relación con las sesiones del backend

Las sesiones siguen usando sus rutas existentes:

| Contexto | Inicio de sesión | Fin de sesión |
|---|---|---|
| Modo | POST /mode-sessions/start | POST /mode-sessions/{sessionId}/finish |
| Ritual | POST /ritual-sessions/start | POST /ritual-sessions/{sessionId}/finish |

Estas rutas tienen sus propias validaciones y contratos de activación/NFC. No son rutas de recreos. No terminar una sesión con /finish al iniciar una pausa ni crear una nueva sesión al terminarla. Tampoco agregar un estado `paused` inventado: el contrato revisado usa active/completed/cancelled.

**Estadísticas:** no hay eventos de recreo enviados por este flujo. El cálculo actual de duración de sesión se basa en inicio/fin; no descuenta explícitamente los recreos. No interpretar automáticamente durationSeconds como foco neto sin pausas. Para auditar cada recreo, sincronizar cupo entre dispositivos o descontar pausas en servidor, hace falta diseñar una ampliación de backend; no está disponible hoy.

## 7. Registro real en PostgreSQL

| Tabla | Clave primaria/FK | Columnas de configuración |
|---|---|---|
| mode_breaks | mode_id UUID → modes.id, ON DELETE CASCADE | break_count, break_duration_minutes |
| ritual_breaks | ritual_id UUID → rituals.id, ON DELETE CASCADE | break_count, break_duration_minutes |

Ambas tienen created_at y updated_at timestamptz con default now(). Cantidad integer NOT NULL default 0; duración integer NOT NULL default 5. CHECK cantidad 0–3 y duración 1–15. Hay una fila por modo/ritual, no una por recreo usado. No hay columna user_id propia: la propiedad se verifica a través del recurso padre.

SQL conceptual que YA ejecuta el repositorio al recibir POST (no ejecutar desde Android):

```sql
INSERT INTO mode_breaks (mode_id, break_count, break_duration_minutes)
VALUES ($1, $2, $3)
ON CONFLICT (mode_id) DO UPDATE SET
  break_count = EXCLUDED.break_count,
  break_duration_minutes = EXCLUDED.break_duration_minutes,
  updated_at = now()
RETURNING mode_id, break_count, break_duration_minutes;
```

Rituales hace lo mismo usando ritual_breaks/ritual_id. created_at se conserva en una actualización; updated_at cambia. El borrado del padre elimina la configuración por cascada.

La expansión de duración 1–5 a 1–15 se aplicó y validó en producción el 24/09/2026 según evidencia de esta integración. No hace falta volver a migrar por incorporar Android. No estrechar otra vez la regla a 5: pueden existir configuraciones de 10 o 15 minutos.

Consultas de soporte de SOLO LECTURA, a ejecutar por alguien con acceso autorizado, reemplazando el UUID:

```sql
SELECT mode_id, break_count, break_duration_minutes, created_at, updated_at
FROM public.mode_breaks
WHERE mode_id = '<MODE_UUID>'::uuid;

SELECT ritual_id, break_count, break_duration_minutes, created_at, updated_at
FROM public.ritual_breaks
WHERE ritual_id = '<RITUAL_UUID>'::uuid;
```

Para comprobar las reglas:

```sql
SELECT conrelid::regclass AS tabla, conname AS restriccion,
       convalidated AS validada, pg_get_constraintdef(oid) AS regla
FROM pg_constraint
WHERE conrelid IN ('public.mode_breaks'::regclass,
                   'public.ritual_breaks'::regclass)
  AND contype = 'c'
ORDER BY tabla, restriccion;
```

Estas consultas no muestran recreos consumidos porque esa información no está registrada aquí.

## 8. Ejemplo Kotlin de cliente

Ejemplo orientativo con Retrofit; adaptar al serializador, autenticación y manejo de errores del proyecto. No es código compilado contra el repositorio Android.

```kotlin
data class SaveBreaksRequest(
    val breakCount: Int,
    val breakDurationMinutes: Int
)
data class ModeBreaksResponse(
    val modeId: String,
    val breakCount: Int,
    val breakDurationMinutes: Int
)
data class RitualBreaksResponse(
    val ritualId: String,
    val breakCount: Int,
    val breakDurationMinutes: Int
)

interface BreaksApi {
    @GET("modes/{id}/breaks")
    suspend fun getModeBreaks(@Path("id") id: String): ModeBreaksResponse

    @POST("modes/{id}/breaks")
    suspend fun saveModeBreaks(
        @Path("id") id: String,
        @Body body: SaveBreaksRequest
    ): ModeBreaksResponse

    @GET("rituals/{id}/breaks")
    suspend fun getRitualBreaks(@Path("id") id: String): RitualBreaksResponse

    @POST("rituals/{id}/breaks")
    suspend fun saveRitualBreaks(
        @Path("id") id: String,
        @Body body: SaveBreaksRequest
    ): RitualBreaksResponse
}

fun validateBreaks(body: SaveBreaksRequest) {
    require(body.breakCount in 0..3)
    require(body.breakDurationMinutes in 1..15)
}
```

Configurar base URL con barra final: https://api.rituo.io/. Agregar Authorization mediante el mecanismo existente. Si se usa kotlinx.serialization, agregar sus anotaciones/configuración; si se usa Moshi/Gson, usar el adaptador correspondiente. No incrustar tokens en el código ni logs.

## 9. Errores y reintentos

| Situación | Tratamiento recomendado |
|---|---|
| 400 | Corregir payload; no reintentar idéntico indefinidamente |
| 401 | Renovar sesión con el flujo de auth existente, una renovación coordinada; si falla, pedir login |
| 404 | Recurso inexistente o ajeno; revisar ID/cuenta y reconciliar |
| Timeout / sin conexión / 5xx | Conservar pendiente; reintentos limitados con backoff y jitter |
| Respuesta de cuenta o revisión anterior | No aplicar al estado actual |

El handler de recreos no tiene un 409 de concurrencia de negocio propio. No trasladar automáticamente al guardado de recreos las reglas de conflicto de inicio de sesiones.

Ejemplos de mensajes 400 del servicio:

- `breakCount must be an integer between 0 and 3`
- `breakDurationMinutes must be an integer between 1 and 15 when breakCount is greater than 0`

No acoplar la lógica de Android al texto en inglés: usar status HTTP y validación local. No convertir cualquier error de GET en configuración 0/5; eso ocultaría fallas y podría pisar datos válidos.

## 10. Validación antes de publicar Android

1. Guardar y releer cantidades 0, 1, 2, 3 y duraciones 1, 2, 3, 5, 10, 15 en ambos tipos.
2. Desactivar con 0/5 y verificar que no se ofrece iniciar recreo.
3. Rechazar localmente cantidades fuera de rango, decimales y duración 0 o 16.
4. Crear padre, fallar guardado de recreos y reintentar sin duplicar padre.
5. Guardar cambios rápidos y simular respuestas desordenadas.
6. Reiniciar app y comprobar configuración persistida por GET.
7. Iniciar recreo con doble toque: consume uno solo.
8. Comprobar acceso temporal a app bloqueada y rebloqueo antes de abrir Rituo.
9. Cerrar proceso durante recreo y restaurar tiempo restante real, sin reinicio.
10. Finalizar sesión antes del vencimiento: callback tardío no la reactiva.
11. Agotar cupo; verificar nuevo ciclo de modo a medianoche y nuevas ejecuciones de ritual.
12. Cambiar cuenta con requests pendientes y comprobar aislamiento.
13. Probar offline, pantalla apagada, ahorro de batería, reinicio y cambio de hora; documentar límites del sistema.
14. Comprobar interacción con bloqueos simultáneos y políticas globales.

Usar recursos de una cuenta de prueba autorizada. El entorno productivo contiene datos reales: no insertar filas arbitrarias ni ejecutar migraciones para una prueba de UI.

## 11. Archivos fuente para verificar el contrato

En repositorio core.api, commit a7a0948:

- src/app/controllers/modes/ModesController.ts
- src/app/controllers/rituals/RitualsController.ts
- src/app/services/modes/ModesService.ts
- src/app/services/rituals/RitualsService.ts
- src/app/dtos/modeBreaks/{SaveModeBreaksDto,ModeBreaksResponseDto}.ts
- src/app/dtos/ritualBreaks/{SaveRitualBreaksDto,RitualBreaksResponseDto}.ts
- src/app/drivers/repositories/modeBreaks/SQLModeBreaksRepository.ts
- src/app/drivers/repositories/ritualBreaks/SQLRitualBreaksRepository.ts
- src/app/controllers/{modeSessions,ritualSessions}/
- migrations/manual/20260923-break-duration/

En iOS: HolaSwift/Models/ViewModels/BlockSetupViewModel.swift, funciones startModeBreak, startRitualBreak, finishModeBreak, finishRitualBreak y renewModeBreakUsageIfNeeded. Hay comentarios antiguos en los modelos que todavía dicen 1–5; el código ejecutable limita a 1–15 y coincide con el backend actual.
