# Barra de navegación inferior de Rituo: guía para Android

Fuente: `HolaSwift/Views/Navigation/RituoTabBar.swift` y `RootTab.swift`.

## 1. Pestañas (4, en este orden)

| # | Título | Ícono normal | Ícono seleccionado | Equivalente Material Symbols |
|---|---|---|---|---|
| 1 | Inicio | Ícono propio (ver sección 2) | El mismo | `ic_tab_home` (archivo incluido) |
| 2 | Rituales | `calendar` | `calendar.badge.clock` | `calendar_month` → `event_repeat` |
| 3 | Foco | `chart.bar.xaxis` | `chart.bar.xaxis.ascending` | `bar_chart` |
| 4 | Perfil | `person` | `person.fill` | `person` (outlined → filled) |

Los nombres de la columna 3 son **SF Symbols de Apple**. Su licencia solo permite usarlos en plataformas Apple, así que **no se pueden copiar a Android**. Usar los equivalentes de Material Symbols (licencia abierta). El único ícono propio de la marca es "Inicio".

## 2. Ícono "Inicio" (la "ø" de rituo)

Es un círculo con una barra horizontal que lo atraviesa y sobresale por ambos lados. Archivos incluidos:

- `ic_tab_home.svg`: SVG en blanco.
- `ic_tab_home.xml`: VectorDrawable listo para `res/drawable/`.

Está dibujado en blanco y se tiñe por código según el estado (sección 4). Si hace falta cambiar el color, se edita `#FFFFFF`.

Geometría (tamaño base S = 20 en la app):

- Círculo: diámetro S, trazo 0,13·S (hacia adentro).
- Barra: ancho 1,18·S, alto 0,13·S, extremos redondeados, centrada. Sobresale del círculo por ambos lados.
- No cambia entre estado normal y seleccionado, solo el color y la opacidad.

## 3. Estructura de la barra

- **Forma:** cápsula flotante (esquinas completamente redondeadas), no pegada al borde de la pantalla.
- **Márgenes:** 20 dp a los costados, 22 dp abajo.
- **Alto de cada ítem:** 66 dp. Los 4 ítems se reparten el ancho en partes iguales.
- **Fondo:** `#1C243D`.
- **Borde:** 1 dp, blanco al 9 %.
- **Sombra:** negra al 48 %, desenfoque 24, desplazamiento vertical 8.

Cada ítem, de arriba hacia abajo, separados 5 dp:

1. Ícono de 20 dp, dentro de un contenedor de 28×28 dp.
2. Etiqueta (título de la pestaña), 10 sp.
3. Punto indicador de 3 dp.

## 4. Estados

| Elemento | Normal | Seleccionado |
|---|---|---|
| Color de ícono | Blanco al 30 % | Blanco (100 %) |
| Grosor del ícono (si es de línea) | Regular | Semibold |
| Escala del ícono | 1,0 | 1,08 |
| Etiqueta | Blanco al 30 %, regular | Blanco, semibold |
| Punto indicador | Invisible (opacidad 0, escala 0,3) | Blanco, visible (escala 1), con brillo blanco de radio 4 |
| Glow detrás del ícono | No | Círculo de 36 dp, blanco al 10 %, desenfocado radio 8 |

Los íconos de Material con variante outlined/filled: usar outlined en normal y filled en seleccionado. Para "Rituales" se usa `calendar_month` en normal y `event_repeat` en seleccionado, que imita el cambio `calendar` → `calendar.badge.clock`.

## 5. Animación

Resorte al cambiar de pestaña: respuesta 0,30 s, amortiguación 0,72. Anima escala, opacidad del punto y color. El glow se desliza de una pestaña a otra en lugar de desaparecer y reaparecer.

## 6. Accesibilidad

Cada ítem expone su título como descripción de contenido y marca el seleccionado como "seleccionado".

## 7. Colores de la marca (por si hacen falta)

| Nombre | Hex |
|---|---|
| Blanco | `#FFFFFF` |
| Light blue | `#9CB2C6` |
| Dark canteen | `#495C78` |
| Deep ocean blue | `#212749` |
