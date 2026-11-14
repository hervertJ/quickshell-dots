// WallpaperPicker.qml
//
// Launcher de wallpapers para Quickshell 0.3 + Hyprland.
// - Backend: awww daemon (awww img <ruta> aplica el wallpaper)
// - Dir: /home/hervert/Pictures/Wallpapers/ (solo nivel raíz)
// - Anclado a la izquierda, pegado al borde, ocupando todo el alto de la pantalla
// - Lista con thumbnail 16:9 + nombre debajo, scrolleable
// - Se abre/cierra con GlobalShortcut (bind real en hyprland.conf, ver abajo)
// - Se cierra automáticamente si cambias de workspace mientras está abierto
// - Barra de búsqueda que filtra por nombre + Ctrl+N/P / Up/Down, Enter aplica, Esc cierra
// - Sin bordes. Colores y tipografía desde Theme (no hardcodeados)
//
// Uso: incluí el archivo en tu shell.qml dentro del ShellRoot:
//
//   ShellRoot {
//       WallpaperPicker {}
//       // ...tus otros módulos (barra, etc)
//   }
//
// Atajo real en Hyprland (el GlobalShortcut solo registra el nombre;
// la tecla se bindea en hyprland.conf):
//
//   bind = SUPER, W, global, quickshell:wallpaper-toggle
//
// (el nombre después de "quickshell:" debe coincidir con el `name` del
// GlobalShortcut, y "quickshell" con el `appid`, que por defecto ya es ese).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../theme"

Scope {
  id: root

  // Directorio a resolver con find (nivel raíz, sin subdirectorios)
  readonly property string wallDir: "/home/hervert/Pictures/Wallpapers"
  // Transición de awww al aplicar (flag --transition-type)
  readonly property string transitionType: "wipe"

  // Estado global de visibilidad del launcher
  property bool launcherOpen: false
  // Listado completo de wallpapers -> [{ path, name }]
  property var wallpapers: []
  // Filtro de búsqueda
  property string searchText: ""

  // --- Abrir/cerrar con atajo global (bindealo en hyprland.conf, ver arriba) ---
  GlobalShortcut {
    id: toggleShortcut
    name: "wallpaper-toggle"
    description: "Abre o cierra el launcher de wallpapers"
    onPressed: root.toggle()
  }

  // --- Cerrar si cambias de workspace mientras está abierto ---
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (root.launcherOpen && event.name === "workspace")
        root.launcherOpen = false;
    }
  }

  function toggle() {
    root.launcherOpen = !root.launcherOpen;
    if (root.launcherOpen) {
      // El TextField se recrea vacío al reabrir; hay que resetear el filtro
      // porque searchText persiste en el Scope (si no, queda la búsqueda anterior)
      root.searchText = "";
      root.refresh();
    }
  }

  // Vuelve a listar los wallpapers del directorio
  function refresh() {
    listProc.running = true;
  }

  // Aplica el wallpaper con awww y cierra el launcher (después de lanzar)
  function apply(path) {
    Quickshell.execDetached(["awww", "img", path, "--transition-type", root.transitionType]);
    root.launcherOpen = false;
  }

  // --- Listado del directorio vía fd (maneja nombres con espacios) ---
  Process {
    id: listProc
    command: [
      "fd", "-e", "png", "-e", "jpg", "-e", "jpeg", "-e", "webp", "-e", "gif", "-e", "bmp",
      ".", root.wallDir, "--max-depth", "1"
    ]
    stdout: StdioCollector {}

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0)
        return;

      const out = String(listProc.stdout.text);
      const items = [];

      for (const line of out.split("\n")) {
        if (!line)
          continue;
        const name = line.substring(line.lastIndexOf("/") + 1);
        items.push({ path: line, name: name });
      }

      items.sort((a, b) => a.name.localeCompare(b.name));
      root.wallpapers = items;
    }
  }

  // PanelWindow no hereda de Item -> hay que usar LazyLoader (no Loader normal)
  LazyLoader {
    id: launcherLoader
    active: root.launcherOpen

    PanelWindow {
      id: win

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell:wallpaper"
      // No reserva espacio en la pantalla, es un popup flotante
      exclusionMode: ExclusionMode.Ignore
      // Toma foco de teclado mientras está abierto
      focusable: true

      color: "transparent"

      // Anclado a la izquierda y a ambos bordes verticales => ocupa todo el alto,
      // con el ancho fijo pegado al borde izquierdo.
      anchors.left: true
      anchors.top: true
      anchors.bottom: true
      margins.left: 0
      margins.top: 0
      margins.bottom: 0

      implicitWidth: 500

      Rectangle {
        id: card
        anchors.fill: parent
        radius: 0
        color: Theme.bg0_h

        ColumnLayout {
          id: layout
          anchors.fill: parent
          anchors.margins: 12
          spacing: 8

          // --- Barra de búsqueda ---
          TextField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search wallpaper"
            placeholderTextColor: Theme.fg
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            font.weight: Theme.weight
            selectByMouse: true
            focus: true
            padding: 15

            background: Rectangle {
              radius: 10
              color: Theme.bg1
            }

            Component.onCompleted: {
              forceActiveFocus()
              root.refresh()
            }

            onTextChanged: {
              root.searchText = text
              list.currentIndex = filtered.values.length > 0 ? 0 : -1
            }

            Keys.onEscapePressed: root.launcherOpen = false

            Keys.onPressed: event => {
              const ctrl = event.modifiers & Qt.ControlModifier;

              if (ctrl && event.key === Qt.Key_N) {
                event.accepted = true;
                if (list.currentIndex < list.count - 1)
                  list.currentIndex++;
                else
                  list.currentIndex = 0;
              } else if (ctrl && event.key === Qt.Key_P) {
                event.accepted = true;
                if (list.currentIndex > 0)
                  list.currentIndex--;
                else
                  list.currentIndex = list.count - 1;
              } else if (event.key === Qt.Key_Down) {
                event.accepted = true;
                if (list.currentIndex < list.count - 1)
                  list.currentIndex++;
                else
                  list.currentIndex = 0;
              } else if (event.key === Qt.Key_Up) {
                event.accepted = true;
                if (list.currentIndex > 0)
                  list.currentIndex--;
                else
                  list.currentIndex = list.count - 1;
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                if (list.currentItem && list.currentItem.modelData)
                  root.apply(list.currentItem.modelData.path);
              }
            }
          }

          // --- Modelo filtrado (filtra por nombre de archivo) ---
          ScriptModel {
            id: filtered
            values: {
              const q = root.searchText.trim().toLowerCase();
              return q === ""
                ? root.wallpapers
                : root.wallpapers.filter(item => item.name.toLowerCase().includes(q));
            }
          }

          // --- Lista de resultados: se ven ~5 filas, el resto con scroll ---
          ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filtered.values
            currentIndex: filtered.values.length > 0 ? 0 : -1
            keyNavigationWraps: true
            // Pre-instantia delegates vecinos para precargar sus thumbnails
            // antes de scrollear (reduce el "pop-in" al pasar rápido)
            cacheBuffer: 600

            // Autoscroll: mantiene la selección visible al moverse con Ctrl+N/P
            onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

            delegate: Rectangle {
              id: entry
              required property var modelData
              required property int index

              width: ListView.view.width
              height: 273
              radius: 10
              color: ListView.isCurrentItem ? Theme.green2 : "transparent"

              ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Thumbnail del wallpaper (16:9 aprox), llena el ancho del delegado
                Image {
                  Layout.preferredWidth: 400
                  Layout.preferredHeight: 225
                  Layout.alignment: Qt.AlignHCenter

                  // Placeholder mientras decodifica (evita el hueco/parpadeo al cargar)
                  Rectangle {
                    id: thumbPlaceholder
                    anchors.fill: parent
                    radius: 8
                    color: Theme.bg1
                    visible: parent.status !== Image.Ready
                  }

                  source: "file://" + entry.modelData.path
                  // Decodifica a resolución de display (escala 1:1) para acelerar
                  // la carga de thumbnails; es 4x menos trabajo que 800x450
                  sourceSize.width: 400
                  sourceSize.height: 225
                  cache: true
                  smooth: true
                  fillMode: Image.PreserveAspectCrop
                  clip: true
                  asynchronous: true

                  Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: "transparent"
                    border.width: 1
                    border.color: entry.ListView.isCurrentItem ? Theme.bg0_h : Theme.bg2
                  }
                }

                // Nombre de la imagen, debajo del thumbnail (se corta al ancho del preview)
                Text {
                  Layout.preferredWidth: 400
                  Layout.maximumWidth: 400
                  Layout.alignment: Qt.AlignHCenter
                  horizontalAlignment: Text.AlignHCenter
                  text: entry.modelData.name
                  elide: Text.ElideRight
                  font.family: Theme.fontFamily
                  font.pixelSize: Theme.fontSize - 2
                  font.weight: Theme.weight
                  color: entry.ListView.isCurrentItem ? Theme.bg0_h : Theme.fg
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: list.currentIndex = entry.index
                onDoubleClicked: root.apply(entry.modelData.path)
              }
            }
          }
        }
      }
    }
  }
}
