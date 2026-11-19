# Íconos y estilo de las secciones del Perfil: guía para Android

Fuente: `ProfilePage.swift`, `ProfileSettingsView.swift`, `ProtectionSettingsView.swift`, `TagSettingsView.swift`, `AccountSettingsView.swift` y `SupportSettingsView.swift` (carpeta `HolaSwift/Views/Profile`).

## Importante sobre los íconos

**Todos los íconos del Perfil son SF Symbols de Apple.** No existe ningún SVG ni PNG propio de la marca en estas pantallas. La licencia de Apple no permite usarlos en Android, así que no se pueden exportar. Para Android hay que usar los equivalentes de **Material Symbols** (licencia abierta, estilo outlined). Las tablas de abajo indican cuál usar en cada fila.

Los equivalentes son una aproximación visual: algunos SF Symbols son compuestos (por ejemplo `lock.open.trianglebadge.exclamationmark`) y no tienen un calco exacto en Material. En esos casos se propone el más cercano; conviene que diseño confirme.

## 1. Pantalla Perfil (pestaña "Perfil")

### Tarjeta "Configuración" (cada fila abre la pantalla de Configuración en esa sección)

| Fila | Detalle a la derecha | SF Symbol | Material Symbols |
|---|---|---|---|
| Protección | Estado de la protección | `lock.shield` | `shield_lock` |
| Emergencias | Disponibilidad del desbloqueo | `lock.open.trianglebadge.exclamationmark` | `lock_open_right` (aprox.) o `emergency` |
| Tag NFC | "Vinculado" / "Sin vincular" | `wave.3.right` | `nfc` |
| Cuenta | Nombre de pila | `person` | `person` |
| Soporte | "Contacto y redes" | `questionmark.circle` | `help` |

### Tarjeta "Estado" (filas con punto de estado)

| Fila | SF Symbol | Material Symbols |
|---|---|---|
| Cuenta | `person.crop.circle` | `account_circle` |
| Email | `envelope` | `mail` |
| Screen Time | `shield` | `shield` |
| Notificaciones | `bell` | `notifications` |
| Tag NFC | `tag` | `sell` |
| Sincronización (normal) | `arrow.triangle.2.circlepath` | `sync` |
| Sincronización (con error, fila tocable) | `arrow.clockwise` | `refresh` |

Nota de plataforma: "Screen Time" es una función de iOS. Si Android usa otro mecanismo (por ejemplo permiso de accesibilidad o de uso de apps), el título y el ícono pueden cambiar; el ícono de escudo sigue siendo válido.

### Tarjeta "Legal"

| Fila | SF Symbol | Material Symbols |
|---|---|---|
| Términos | `doc.text` | `description` |
| Privacidad | `lock.shield` | `shield_lock` |
| Licencias open source | `text.justify.left` | `notes` |

### Tarjeta "Demo"

| Fila | SF Symbol | Material Symbols |
|---|---|---|
| Cómo funciona Rituo | `play.circle` | `play_circle` |

### Tarjeta "Acerca de"

| Fila | SF Symbol | Material Symbols |
|---|---|---|
| Versión | `info.circle` | `info` |
| Build | `applescript` (símbolo de scripts) | `build` o `tag` |
| Compartir Rituo | `square.and.arrow.up` | `share` |

### Botón "Cerrar sesión"

`rectangle.portrait.and.arrow.right` → `logout`. Color de peligro (ver colores).

### Insignia "Cuenta de demostración" (solo en cuentas de revisión)

`checkmark.seal.fill` → `verified` (relleno). Texto y fondo en light blue.

## 2. Pantalla "Configuración" (abre como hoja desde el Perfil)

Barra superior: botón de cierre `xmark` → `close` (en círculo de 32 dp, blanco al 7 %), título "Configuración". Contenido, en este orden: Protección, Tag NFC, Cuenta, Soporte.

### Sección "Protección"

| Fila | Subtítulo | SF Symbol | Material Symbols |
|---|---|---|---|
| Proteger el permiso de Rituo | Guía para configurar un código en Ajustes | `key.fill` | `key` (filled) |
| Modo estricto | Estado actual | `lock.shield` | `shield_lock` |
| Bloquear descargas de apps | Estado actual | `arrow.down.app.fill` | `download` (o `block`) |
| Bloquear contenido sensible | Estado actual | `shield.lefthalf.filled` | `shield` (relleno) |

Estas filas llevan además un chevron `chevron.right` → `chevron_right`.

### Sección "Emergencias"

| Fila | Subtítulo | SF Symbol | Material Symbols |
|---|---|---|---|
| Desbloqueo de emergencia | Disponibilidad | `lock.open.trianglebadge.exclamationmark` | `lock_open_right` (aprox.) o `emergency` |

### Sección "Tag NFC"

| Elemento | SF Symbol | Material Symbols |
|---|---|---|
| Sin tarjeta vinculada | `wave.3.right` | `nfc` |
| Vincular tarjeta (botón) | `wave.3.right` | `nfc` |
| Renombrar tag | `pencil` | `edit` |
| Volver a vincular | `arrow.triangle.2.circlepath` | `sync` |
| Desvincular tag (rojo) | `trash` | `delete` |

### Sección "Cuenta" ("Usuario")

| Fila | SF Symbol | Material Symbols |
|---|---|---|
| Nombre | `person.text.rectangle` | `badge` |
| Apellido | `person.crop.square` | `person` (o `badge`) |
| Email | `envelope` | `mail` |
| Inicio de sesión | `key` | `key` |
| Eliminar cuenta (rojo) | `person.crop.circle.badge.minus` | `person_remove` |

### Sección "Soporte"

| Fila | Detalle | SF Symbol | Material Symbols |
|---|---|---|---|
| Email | hello@rituo.io | `envelope` | `mail` |
| WhatsApp | +54 9 11 5847-9025 | `phone` | `call` |
| Instagram | @rituo.io | `camera` | `photo_camera` |
| LinkedIn | rituo.io | `briefcase` | `work` |

Instagram y LinkedIn en iOS usan íconos genéricos (cámara y maletín), no los logos de las redes. Android puede mantener ese criterio o usar los logos oficiales de cada red si prefiere; es una decisión de diseño.

## 3. Estilo de las filas

Todas las filas comparten la misma estructura: ícono · título · (detalle) · chevron o punto de estado.

| Elemento | Valor |
|---|---|
| Padding de la fila | 18 dp horizontal, 14 dp vertical |
| Separación ícono ↔ texto | 14 dp |
| Ancho reservado del ícono | 22 dp |
| Tamaño del ícono | 13 pt, peso medium (en "Protección" 14 pt) |
| Título | 15 sp, blanco al 80 % |
| Detalle (filas con chevron) | 13 sp, blanco al 30 % |
| Valor (filas informativas) | 14 sp, blanco al 35 % |
| Valor (filas de estado) | 13 sp, blanco al 35 %, una línea |
| Chevron | 11 dp, blanco al 18 % |
| Divisor entre filas | 1 dp, blanco al 5 %, empieza a 54 dp del borde izquierdo (alineado con el texto, no con el ícono) |
| Etiqueta de sección | MAYÚSCULAS, 10 sp, semibold, espaciado de letras 1,5, blanco al 28 %, 4 dp de margen izquierdo |

### Color del ícono según tipo de fila

| Tipo de fila | Color del ícono |
|---|---|
| Normal / informativa | Blanco al 35 % |
| Estado activo (`isOn`) | Light blue `#9CB2C6` |
| Estado inactivo | Blanco al 28 % |
| Destructiva (Eliminar cuenta, Desvincular tag) | Rojo `#C71F21` (el texto también) |
| "Protección" (filas con subtítulo) | Light blue `#9CB2C6` |

### Punto de estado (filas de la tarjeta "Estado")

Círculo de 6 dp a la derecha del valor.

- Activo: verde `#4DE685` con un brillo verde de radio 4.
- Inactivo: blanco al 18 %, sin brillo.

### Tarjeta contenedora

- Fondo `#1F2942` (rgb 0,12 / 0,16 / 0,26 → `#1F2942`), esquinas de 20 dp.
- Borde de 1 dp, blanco al 6 %.
- Sombra negra al 18 %, radio 12, desplazamiento vertical 4.

## 4. Colores de la marca

| Nombre | Hex |
|---|---|
| Blanco | `#FFFFFF` |
| Light blue | `#9CB2C6` |
| Dark canteen | `#495C78` |
| Deep ocean blue | `#212749` |
| Peligro | `#C71F21` |
| Éxito (verde de estado) | `#4DE685` |

## 5. Hojas de confirmación (bottom sheets)

Varias acciones abren una hoja inferior con un ícono grande, título, mensaje y botones. Íconos usados en cada una:

| Acción | SF Symbol del encabezado | Material Symbols | Botones |
|---|---|---|---|
| Cerrar sesión (peligro) | `rectangle.portrait.and.arrow.right` | `logout` | Cerrar sesión / Cancelar |
| Eliminar cuenta (peligro) | `person.crop.circle.badge.minus` | `person_remove` | Continuar (`exclamationmark.triangle` → `warning`) |
| Desvincular tag (peligro) | `wave.3.right.circle` | `nfc` | Confirmar con tag (`wave.3.right` → `nfc`) |
| Volver a vincular | `arrow.triangle.2.circlepath` | `sync` | Escanear nueva tarjeta (`wave.3.right` → `nfc`) |
| Modo estricto (activar) | `lock.shield` | `shield_lock` | Activar (`checkmark` → `check`) |
| Modo estricto (desactivar) | `lock.open` | `lock_open` | Desactivar (`lock.open` → `lock_open`, peligro) |
| Emergencia | `lock.open.trianglebadge.exclamationmark` | `lock_open_right` (aprox.) | Lo olvidé (`hand.raised` → `front_hand`), Lo perdí (`exclamationmark.triangle` → `warning`) |
| Tag perdido / sin tag | `tag.slash` | `sell` con tachado (aprox.) | Desbloquear (`lock.open` → `lock_open`) |
| Bloquear descargas | `arrow.down.app.fill` / `arrow.down.app` | `download` | Bloquear (`checkmark` → `check`), Permitir descargas (`lock.open` → `lock_open`) |
| Contenido sensible | `shield.lefthalf.filled` / `shield.slash` | `shield` / `remove_moderator` | Bloquear / Activar filtro (`checkmark` → `check`) |
| Guía del permiso de Screen Time | `key.shield` | `key` | — |

Todas las hojas usan el mismo patrón: ícono del encabezado teñido con el color de la acción (peligro en rojo, normal en light blue), título, mensaje, y botones apilados con "Cancelar" como botón secundario.

## 6. Pendientes de diseño

- Los íconos "aprox." no tienen equivalente exacto en Material Symbols.
- Revisar si en Android se conserva "Screen Time" o se renombra según el permiso que use.
- Decidir si Instagram y LinkedIn usan íconos genéricos o logos oficiales.
