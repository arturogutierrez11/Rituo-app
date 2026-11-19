# Entorno local de prueba de recreos

No es una réplica completa de producción. Usa Core API real con un esquema mínimo
ficticio y un servicio de autenticación de prueba. No prueba Apple/Google, entrega
de emails, NFC físico ni la ejecución real de Screen Time en segundo plano.

## Arranque

Desde la raíz de HolaSwift:

```sh
python3 Tests/local-stack/run.py
```

Requiere Node, las dependencias ya instaladas de `../core.api` y PostgreSQL 17 de
Homebrew. No ejecutar `npm start` con el `.env` habitual para esta prueba.

El script crea un clúster nuevo en `/tmp`, con socket privado y TCP desactivado.
Compila el backend en el directorio temporal, excluye variables de conexión
heredadas y dirige dotenv a un archivo inexistente. Core API escucha únicamente
en `127.0.0.1:3000` y la autenticación ficticia en `127.0.0.1:3001`. Si los puertos
están ocupados, aborta; no reemplaza servicios existentes. La clave JWT se genera
para cada ejecución; no es una clave productiva.

Antes de anunciar `LOCAL READY`, verifica por HTTP que ambos tipos de recreos
guardan y recuperan 1, 2, 3, 5, 10 y 15 minutos, y rechazan 0, 16 y 1.5.
`result.json` contiene el resultado de esa prueba, no una certificación del flujo UI.
Con `--check` termina y elimina el clúster al acabar las pruebas. En modo servidor,
Ctrl-C detiene API/DB y elimina únicamente su directorio temporal.

Cuenta ficticia local: `local-test@example.invalid` / `Solo-local-2026!`.
No usar cuentas reales. La sesión y la contraseña no funcionan en producción.

Para probar el flujo demo existente, iniciar con `--demo-account`. La fixture
usa el correo `hello@rituo.io` y conserva la contraseña ficticia
`Solo-local-2026!`; no usa la contraseña real. El backend local prepara la
tarjeta virtual mediante el endpoint real `POST /nfc-tags/review-demo/prepare`.
Cada arranque crea datos nuevos; detenerlo elimina ese clúster temporal.

## Simulador

Compilar la configuración **Debug** con el argumento de Xcode:

```text
-xcconfig /Users/arturogutierrez/Documents/rituo/apis/HolaSwift/Config/LocalSimulator.xcconfig
```

Esta configuración es optativa: no está incluida por Debug ni por Release.
Verificar en el Info.plist compilado `AppEnvironment=local-simulator`,
`CoreAPIBaseURL=http://127.0.0.1:3000`, `AuthAPIBaseURL=http://127.0.0.1:3001`.
En este modo no se configura Firebase. El modo local solo admite Debug/simulador
y rechaza endpoints que no sean loopback.

El simulador puede pedir autorización de Screen Time y autenticación del sistema.
No se ha agregado un bypass de permisos. Que la API guarde el recreo no prueba
que iOS aplique y quite el bloqueo correctamente: eso requiere un iPhone físico.

## Observación para el despliegue futuro

Actualización: tras confirmar el catálogo de producción proporcionado por el
usuario, se retiraron localmente los dos bloques ALTER mencionados debajo. Son
dos cambios adicionales de backend. Pasaron TypeScript y 105 pruebas. No están
desplegados. La descripción siguiente corresponde al backend anterior; volver a
ese commit también restaura sus operaciones DDL de arranque.

El arranque del backend contiene modificaciones de restricciones preexistentes
en `SQLModeSessionsRepository.ensureSchema` y
`SQLAppUpdatesRepository.ensureSchema`. No fueron agregadas por el cambio de
recreos y no se modificaron aquí. La migración nueva de duración de recreos es
manual, pero eso no significa que el resto del arranque esté libre de DDL.
Revisar estas operaciones antes de afirmar que un redeploy no toma bloqueos.
