// ClipboardLauncher.qml
//
// Launcher de historial de portapapeles para Quickshell 0.3 + Hyprland.
// - Backend: cliphist (SQLite). El daemon `wl-paste --watch cliphist store`
//   debe estar corriendo para poblar el historial.
// - Anclado abajo-centro, pegado al borde (600x400, sin margen)
// - Se abre/cierra con GlobalShortcut (bind real en hyprland.conf, ver abajo)
// - Persiste al cambiar de workspace (no se cierra solo)
// - Barra de búsqueda que filtra por preview + lista scrolleable
// - Ctrl+N / Ctrl+P / flechas para moverse, Enter para copiar, Esc para cerrar
// - Sin bordes. Colores y tipografía desde Theme (Theme.bg0_h, Theme.bg1,
//   Theme.green2, Theme.fg, Theme.fontFamily, Theme.fontSize, Theme.weight)
//
// Uso: inclúyelo en tu shell.qml dentro del ShellRoot:
//
//   ShellRoot {
//       ClipboardLauncher {}
//       // ...tus otros módulos
//   }
//
// Atajo real en Hyprland (el GlobalShortcut solo registra el nombre;
// la tecla se bindea en hyprland.conf):
//
//   bind = SUPER, V, global, quickshell:clipboard-toggle
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

  // Estado global de visibilidad del launcher
  property bool launcherOpen: false
  // Historial completo parseado de `cliphist list` -> [{ id, text }]
  property var history: []
  // Filtro de búsqueda
  property string searchText: ""

  // --- Abrir/cerrar con atajo global (bindealo en hyprland.conf, ver arriba) ---
  GlobalShortcut {
    id: toggleShortcut
    name: "toggle-clipboard"
    description: "Abre o cierra el launcher de portapapeles"
    onPressed: root.toggle()
  }

  function toggle() {
    root.launcherOpen = !root.launcherOpen;
    if (root.launcherOpen)
      root.refresh();
  }

  // Vuelve a consultar el historial de cliphist
  function refresh() {
    listProc.running = true;
  }

  // Copia el ítem con `id` al portapapeles y cierra el launcher (después de copiar)
  function copyItem(id) {
    Quickshell.execDetached(["sh", "-c", "cliphist decode " + id + " | wl-copy"]);
    root.launcherOpen = false;
  }

  // --- Carga del historial vía cliphist ---
  Process {
    id: listProc
    command: ["cliphist", "list"]
    stdout: StdioCollector {}

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0)
        return;

      const out = String(listProc.stdout.text);
      const items = [];

      for (const line of out.split("\n")) {
        if (!line)
          continue;
        // Formato de cliphist list: "<id>\t<preview>"
        const sep = line.indexOf("\t");
        if (sep < 0)
          continue;
        items.push({ id: line.slice(0, sep), text: line.slice(sep + 1) });
      }

      root.history = items;
    }
  }

  // PanelWindow no hereda de Item -> hay que usar LazyLoader (no Loader normal)
  LazyLoader {
    id: launcherLoader
    active: root.launcherOpen

    PanelWindow {
      id: win

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell:clipboard"
      // No reserva espacio en la pantalla, es un popup flotante
      exclusionMode: ExclusionMode.Ignore
      // Toma foco de teclado mientras está abierto
      focusable: true

      color: "transparent"

      // Un solo anchor (bottom) => Hyprland centra el panel horizontalmente solo,
      // y sin margin queda completamente pegado al borde inferior.
      anchors.bottom: true
      margins.bottom: 0

      implicitWidth: 800
      implicitHeight: 600

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
            placeholderText: "Search clipboard"
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
                if (list.currentItem && list.currentItem.modelData) {
                  root.copyItem(list.currentItem.modelData.id);
                }
              }
            }
          }

          // --- Modelo filtrado (se filtra sobre el preview devuelto por cliphist) ---
          ScriptModel {
            id: filtered
            values: {
              const q = root.searchText.trim().toLowerCase();
              return q === ""
              ? root.history
              : root.history.filter(item => item.text.toLowerCase().includes(q));
            }
          }

          // --- Lista de resultados ---
          ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: filtered.values
            currentIndex: filtered.values.length > 0 ? 0 : -1
            keyNavigationWraps: true

            // Autoscroll: mantiene la selección visible al moverse
            onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

            delegate: Rectangle {
              id: entry
              required property var modelData
              required property int index

              width: ListView.view.width
              height: 44
              radius: 10
              color: ListView.isCurrentItem ? Theme.green2 : "transparent"

              Text {
                anchors.fill: parent
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                verticalAlignment: Text.AlignVCenter
                text: entry.modelData.text
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 2
                font.weight: Theme.weight
                color: entry.ListView.isCurrentItem ? Theme.bg0_h : Theme.fg
              }

              MouseArea {
                anchors.fill: parent
                onClicked: list.currentIndex = entry.index
                onDoubleClicked: root.copyItem(entry.modelData.id)
              }
            }
          }
        }
      }
    }
  }
}
