---
name: quickshell-app-launcher
description: Build minimalist application-launcher widgets in Quickshell 0.3 for Hyprland/Wayland — a layer-shell popup with a search bar, filtered app list, and keyboard navigation that launches desktop entries. Use this skill whenever the user asks to create, modify, fix, or theme an "app launcher", "applauncher", "rofi/dmenu/wofi replacement", or "spotlight-style launcher" in Quickshell/QML, or mentions PanelWindow, GlobalShortcut, DesktopEntries, LazyLoader, or a Theme singleton for colors/fonts in that context. Also use it when troubleshooting Quickshell launcher issues like terminal apps not opening, the widget floating instead of anchoring, or apps not filtering/launching correctly.
---

# Quickshell 0.3 App Launcher (Hyprland / Wayland)

Guía práctica para construir launchers de aplicaciones minimalistas con Quickshell 0.3, pensada para Hyprland pero aplicable a otros compositors wlroots. Encapsula los patrones y errores comunes descubiertos construyendo uno real: anclaje correcto, ciclo de vida de la ventana, filtrado, navegación por teclado y el gotcha de las apps de terminal.

## 1. Antes de escribir código: preguntas a resolver

No asumas estos puntos — pregúntalos si el usuario no los dio ya (en el chat o en un `Theme.qml` que puedas leer):

1. **Cómo se abre/cierra**: ¿`GlobalShortcut` (atajo global vía XDG portal, se bindea aparte en `hyprland.lua`), o algún otro trigger (IPC, señal de otro widget)?
2. **Anclaje y tamaño**: ¿dónde va (abajo-centro, centro de pantalla, arriba), pegado al borde o flotando con margen, y qué tamaño (ancho x alto fijo, o basado en contenido)?
3. **Cuántos resultados visibles** y si la lista completa debe quedar navegable con scroll o cortarse duro en N.
4. **Íconos**: ¿ícono + texto, o solo texto?
5. **Comportamiento por workspace**: ¿debe cerrarse solo al cambiar de workspace (para no "viajar" contigo), o persistir?
6. **Terminal para apps TUI** (btop, htop, etc.): pedir qué terminal usar — no asumir una. Ver sección 7.
7. **Theme singleton**: ¿ya existe y es global en el árbol de imports, o hay que crearlo / importarlo explícitamente?

## 2. Estética: minimalista por defecto

Salvo que el usuario pida lo contrario:

- **Sin bordes** (`border.width`) en tarjetas, inputs y delegates.
- Esquinas con `radius` moderado (8–16px), o `radius: 0` si el widget queda anclado a un borde de pantalla (no tiene sentido redondear una esquina pegada al borde).
- Un solo color de fondo por superficie, sin gradientes ni sombras.
- Jerarquía visual solo por color (selección resaltada) y espaciado — no por decoración.
- Todo color y toda tipografía sale del singleton `Theme`, nunca hardcodeado.

## 3. El singleton Theme

Se asume un singleton global `Theme` (no requiere `import` explícito si vive en el árbol de config de Quickshell) con esta forma — paleta estilo Gruvbox:

```qml
// Theme.qml
pragma Singleton
import QtQuick

QtObject {
    // Fondos
    readonly property color bg0_h: "#1d2021"
    readonly property color bg0_s: "#32302f"
    readonly property color bg0:   "#282828"
    readonly property color bg:    "#282828"   // alias práctico de bg0
    readonly property color bg1:   "#3c3836"
    readonly property color bg2:   "#504945"
    readonly property color bg3:   "#665c54"
    readonly property color bg4:   "#7c6f64"

    // Texto / primer plano
    readonly property color fg:  "#ebdbb2"
    readonly property color fg0: "#fbf1c7"
    readonly property color fg1: "#ebdbb2"
    readonly property color fg2: "#d5c4a1"
    readonly property color fg3: "#bdae93"
    readonly property color fg4: "#a89984"

    // Grises
    readonly property color gray1: "#a89984"
    readonly property color gray2: "#928374"

    // Acentos, dos tonos cada uno (1 = apagado, 2 = vivo/neón)
    readonly property color red1:    "#cc241d"
    readonly property color red2:    "#fb4934"
    readonly property color green1:  "#98971a"
    readonly property color green2:  "#b8bb26"
    readonly property color yellow1: "#d79921"
    readonly property color yellow2: "#fabd2f"
    readonly property color blue1:   "#458588"
    readonly property color blue2:   "#83a598"
    readonly property color purple1: "#b16286"
    readonly property color purple2: "#d3869b"
    readonly property color aqua1:   "#689d6a"
    readonly property color aqua2:   "#8ec07c"
    readonly property color orange1: "#d65d0e"
    readonly property color orange2: "#fe8019"

    // Tipografía
    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property int fontSize: 14
    readonly property int weight: Font.Normal
}
```

**Uso**: siempre `Theme.bg`, `Theme.fg`, `Theme.green2`, `Theme.fontFamily`, `Theme.fontSize`, `Theme.weight`, etc. — nunca strings de color ni tamaños de fuente literales en el widget. Si el usuario ya tiene su propio `Theme.qml`, léelo primero (`view`) para confirmar que los nombres calzan antes de usarlos.

**Convención de color para el launcher**:
- Fondo de la tarjeta/panel: `Theme.bg` (o `Theme.bg0`).
- Fondo del input de búsqueda: `Theme.bg1` (un tono más claro que el fondo, sin borde, para diferenciarlo).
- Texto normal: `Theme.fg`.
- Ítem seleccionado en la lista: fondo `Theme.green2`, texto `Theme.bg` (invertido, para contraste — nunca dejar texto claro sobre `green2`, que es un verde vivo).

## 4. Arquitectura QML

`PanelWindow` **no hereda de `Item`**, así que no puede vivir dentro de un `Loader` de QtQuick normal — hay que usar `LazyLoader` de Quickshell, que sí soporta cargar/destruir tipos `Window`. Esto es la causa más común de errores confusos al hacer toggle de un launcher.

Estructura recomendada:

```
Scope (root del módulo)
├── GlobalShortcut          → toggle de una property bool `launcherOpen`
├── Connections { target: Hyprland }  → cierra el launcher si cambia el workspace
└── LazyLoader { active: launcherOpen }
    └── PanelWindow
        └── Rectangle (tarjeta, color: Theme.bg)
            └── ColumnLayout
                ├── TextField (búsqueda)
                └── ListView (resultados, filtrados con ScriptModel)
```

Puntos clave de cada pieza:

- **`GlobalShortcut`** (`import Quickshell.Hyprland` o el módulo core, según versión) solo registra un *nombre* dentro de Quickshell — la tecla física se bindea en `hyprland.conf`:
  ```
  bind = SUPER, D, global, quickshell:<nombre-del-shortcut>
  ```
  El `name` del `GlobalShortcut` debe coincidir exactamente con lo que va después de `quickshell:` en el bind.

- **`LazyLoader { active: root.launcherOpen }`**: crea la ventana solo cuando se necesita y la destruye al cerrar — evita que quede un layer-shell surface fantasma consumiendo foco/recursos cuando el launcher está "cerrado".

- **Cierre por cambio de workspace** (si el usuario lo pidió): escuchar eventos crudos de Hyprland y cerrar si cambia el workspace mientras está abierto —

  ```qml
  Connections {
      target: Hyprland
      function onRawEvent(event) {
          if (root.launcherOpen && event.name === "workspace")
              root.launcherOpen = false;
      }
  }
  ```

  Esto es necesario porque las superficies layer-shell son overlays globales del compositor, no pertenecen a un workspace — no hay forma nativa de "anclarlas" a uno, solo simularlo cerrándolas al cambiar.

## 5. Anclaje y tamaño (`PanelWindow`)

- **Centrado automático**: si solo defines `anchors.bottom: true` (o `top`/`left`/`right` solo) **sin** el par opuesto, el compositor centra esa ventana en el eje libre. No hace falta calcular márgenes a mano para centrar horizontalmente un panel anclado abajo.
- **"Flotando" vs "pegado"**: `margins.bottom` (o el margen del anchor que uses) es lo que separa el panel del borde. `margins.bottom: 0` = completamente pegado al borde. Un valor > 0 = flota a esa distancia.
- **Tamaño**: usa `implicitWidth` / `implicitHeight` para tamaño fijo. Si el usuario da medidas exactas (p. ej. 800×600), fíjalas ahí, no en el `Rectangle` interno.
- **No reservar espacio en pantalla**: un launcher es un popup, no una barra — pon `exclusionMode: ExclusionMode.Ignore` para que no empuje otras ventanas.
- **Foco de teclado**: `focusable: true` en el `PanelWindow`, y `focus: true` + `Component.onCompleted: forceActiveFocus()` en el `TextField` de búsqueda, para que se pueda escribir apenas se abre.
- **Capa**: `WlrLayershell.layer: WlrLayer.Overlay` para quedar por encima de todo; `WlrLayershell.namespace: "quickshell:<algo-único>"` ayuda a identificarlo en herramientas de debug de Hyprland.

## 6. Filtrado y lista de resultados

Usa `DesktopEntries.applications.values` (de `Quickshell.Services.Applications` o el import equivalente en tu versión) como fuente, envuelto en un `ScriptModel` que recalcula al tipear:

```qml
ScriptModel {
    id: filtered
    values: {
        const q = search.text.trim().toLowerCase();
        const all = [...DesktopEntries.applications.values]
            .filter(d => d.name)
            .sort((a, b) => a.name.localeCompare(b.name));
        return q === "" ? all : all.filter(d => d.name.toLowerCase().includes(q));
    }
}
```

**Decide con el usuario** si el número de resultados visibles (p. ej. 10) es un **tope duro** (`.slice(0, N)`, no se ve nada más) o solo el **alto visible** de una lista más larga y navegable con scroll (`Layout.fillHeight` en el `ListView`, sin `slice`, con autoscroll — ver sección 7). Son requisitos distintos aunque suenen parecido ("mostrar 10 apps").

Delegate típico: `Rectangle` con `color: ListView.isCurrentItem ? Theme.green2 : "transparent"`, `IconImage { source: Quickshell.iconPath(modelData.icon, true) }` si se pidieron íconos, y `Text` con `font.family: Theme.fontFamily`, `font.pixelSize: Theme.fontSize`.

## 7. Navegación por teclado

Patrón estándar: `Ctrl+N` / `Ctrl+P` para bajar/subir (estilo emacs/readline), `Enter` para lanzar, `Esc` para cerrar. Todo esto va en `Keys.onPressed` del `TextField` de búsqueda (no del `ListView`, para no perder el foco de escritura):

```qml
Keys.onPressed: event => {
    const ctrl = event.modifiers & Qt.ControlModifier;
    if (ctrl && event.key === Qt.Key_N) {
        event.accepted = true;
        list.currentIndex = list.currentIndex < list.count - 1 ? list.currentIndex + 1 : 0;
    } else if (ctrl && event.key === Qt.Key_P) {
        event.accepted = true;
        list.currentIndex = list.currentIndex > 0 ? list.currentIndex - 1 : list.count - 1;
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        event.accepted = true;
        launch();
    }
}
Keys.onEscapePressed: root.launcherOpen = false
```

Si la lista es más larga que el área visible, agrega autoscroll para que la selección nunca quede fuera de vista:

```qml
onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)
```

## 8. Lanzar aplicaciones — el gotcha de las apps de terminal

`DesktopEntry.execute()` **ignora `runInTerminal`** (y los field codes del `.desktop`). Si lanzas btop, htop, o cualquier app con `Terminal=true` usando `execute()` directamente, no pasa nada visible — se ejecuta sin terminal y muere o queda huérfana.

Solución: chequear `runInTerminal` y, si es verdadero, envolver el comando con una terminal — **configurable, sin asumir una por defecto** (pregúntale al usuario cuál usa: kitty, alacritty, foot, wezterm, etc.):

```qml
// Property configurable, a definir según lo que use el usuario
property list<string> terminalCommand: ["kitty", "-e"]  // ejemplo, no asumir

function launch() {
    if (list.currentItem && list.currentItem.modelData) {
        const entry = list.currentItem.modelData;
        if (entry.runInTerminal) {
            Quickshell.execDetached([...root.terminalCommand, ...entry.command]);
        } else {
            entry.execute();
        }
        root.launcherOpen = false;
    }
}
```

Cierra el launcher (`launcherOpen = false`) **después** de lanzar, no antes — si se cierra primero y `execute()`/`execDetached()` falla, no hay feedback de qué pasó.

## 9. Checklist de errores comunes

- ❌ Usar `Loader` en vez de `LazyLoader` para envolver un `PanelWindow` → falla porque `PanelWindow` no es `Item`.
- ❌ Anclar con `anchors.bottom` + `anchors.left` + `anchors.right` cuando se quiere *centrado* con ancho fijo → eso estira el panel a todo el ancho. Para centrar con ancho fijo, ancla **solo** el eje perpendicular (`bottom`, no `left`/`right`).
- ❌ Dejar `margins.bottom` con un valor cuando el usuario pidió "completamente anclado/pegado" → debe ser `0`.
- ❌ Poner colores o tamaños de fuente literales (`"#282828"`, `font.pixelSize: 14`) en vez de `Theme.*`.
- ❌ Usar `entry.execute()` para todo y asumir que las apps de terminal "simplemente van a andar".
- ❌ Olvidar `focusable: true` en el `PanelWindow` — sin esto no puedes escribir en la barra de búsqueda.
- ❌ Poner el color del placeholder igual al `color` del `TextField` — el placeholder usa su propia property, `placeholderTextColor`, no hereda de `color`.
- ❌ Cerrar el launcher (`launcherOpen = false`) *antes* de ejecutar el comando de lanzamiento.

## 10. Al terminar

Después de generar o modificar el widget, resume en una línea qué decisiones tomaste por el usuario (tamaño, terminal por defecto, comportamiento de la lista) para que las confirme o ajuste — no lo des por sentado en silencio, sobre todo el tema de la terminal (sección 7), que varía mucho entre usuarios.
