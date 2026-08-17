// AppLauncher.qml
//
// Applauncher minimalista para Quickshell 0.3 + Hyprland.
// - Anclado completamente abajo, pegado al borde (800x600, sin margen)
// - Se abre/cierra con GlobalShortcut (bind el atajo real en hyprland.conf, ver abajo)
// - Se cierra automáticamente si cambias de workspace mientras está abierto
// - Barra de búsqueda + lista scrolleable con TODAS las apps (se ven ~10 a la vez)
// - Ctrl+N / Ctrl+P para moverse (autoscroll), Enter para lanzar, Esc para cerrar
// - Sin bordes. Colores desde Theme (Theme.bg, Theme.bg3, Theme.fg, Theme.green2)
// - Tipografía desde Theme (Theme.fontFamily, Theme.fontSize)
//
// Uso: guarda este archivo en tu carpeta de quickshell (p.ej. modules/AppLauncher/AppLauncher.qml)
// e inclúyelo en tu shell.qml como un componente más dentro del ShellRoot:
//
//   ShellRoot {
//       AppLauncher {}
//       // ...tus otros módulos (barra, etc)
//   }
//
// Atajo real en Hyprland (GlobalShortcut de Quickshell.Hyprland no define la tecla,
// solo el "nombre" del shortcut; el bind se hace en hyprland.conf):
//
//   bind = SUPER, D, global, quickshell:applauncher-toggle
//
// (el nombre después de "quickshell:" debe coincidir con el `name` del GlobalShortcut,
// y "quickshell" debe coincidir con el `appid`, que por defecto ya es "quickshell").

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Hyprland
import "../theme"

Scope {
  id: root

  property list<string> terminalCommand: ["ghostty", "-e"]

  // Estado global de visibilidad del launcher
  property bool launcherOpen: false
  // Filas visibles antes de necesitar scroll (la lista completa sigue siendo navegable)
  readonly property int visibleRows: 10

  // --- Abrir/cerrar con atajo global (bindealo en hyprland.conf, ver arriba) ---
  GlobalShortcut {
    id: toggleShortcut
    name: "applauncher-toggle"
    description: "Abre o cierra el applauncher"
    onPressed: root.launcherOpen = !root.launcherOpen
  }

  // --- Cierra el launcher si cambia el workspace activo mientras está abierto ---
  // Así solo "vive" en el workspace donde lo abriste.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.launcherOpen && event.name === "workspace") {
        root.launcherOpen = false;
      }
    }
  }

  // PanelWindow no hereda de Item -> hay que usar LazyLoader (no Loader normal)
  LazyLoader {
    id: launcherLoader
    active: root.launcherOpen

    PanelWindow {
      id: win

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell:applauncher"
      // No reserva espacio en la pantalla, es un popup flotante
      exclusionMode: ExclusionMode.Ignore
      // Toma foco de teclado mientras está abierto
      focusable: true

      color: "transparent"

      // Un solo anchor (bottom) => Hyprland centra el panel horizontalmente solo,
      // y sin margin queda completamente pegado/anclado al borde inferior.
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
            placeholderText: "Search App"
            placeholderTextColor: Theme.fg
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 2
            font.weight: 750
            selectByMouse: true
            focus: true
            padding: 15

            background: Rectangle {
              radius: 10
              color: Theme.bg1
            }

            Component.onCompleted: forceActiveFocus()

            onTextChanged: list.currentIndex = filtered.values.length > 0 ? 0 : -1

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
              } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                launch();
              }
            }

            //function launch() {
              //  if (list.currentItem && list.currentItem.modelData) {
              //    list.currentItem.modelData.execute();
              //    root.launcherOpen = false;
              //  }
              //}

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
            }

            // --- Modelo filtrado (todas las coincidencias, sin recorte) ---
            ScriptModel {
              id: filtered
              values: {
                const q = search.text.trim().toLowerCase();
                const all = [...DesktopEntries.applications.values]
                .filter(d => d.name)
                .sort((a, b) => a.name.localeCompare(b.name));

                return q === ""
                ? all
                : all.filter(d => d.name.toLowerCase().includes(q));
              }
            }

            // --- Lista de resultados: se ven ~10 filas, el resto con scroll ---
            ListView {
              id: list
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              model: filtered.values
              currentIndex: filtered.values.length > 0 ? 0 : -1
              keyNavigationWraps: true

              // Autoscroll: mantiene la selección visible al moverse con Ctrl+N/P
              onCurrentIndexChanged: list.positionViewAtIndex(list.currentIndex, ListView.Contain)

              delegate: Rectangle {
                id: entry
                required property var modelData
                required property int index

                width: ListView.view.width
                height: 52
                radius: 10
                color: ListView.isCurrentItem ? Theme.green2 : "transparent"

                RowLayout {
                  anchors.fill: parent
                  //anchors.margins: 10
                  anchors.leftMargin: 15
                  spacing: 10

                  //IconImage {
                    //  source: Quickshell.iconPath(entry.modelData.icon, true)
                    //  Layout.preferredWidth: 22
                    //  Layout.preferredHeight: 22
                    //}

                    Text {
                      Layout.fillWidth: true
                      text: entry.modelData.name
                      elide: Text.ElideRight
                      font.family: Theme.fontFamily
                      font.pixelSize: Theme.fontSize - 2
                      font.weight: 750
                      color: entry.ListView.isCurrentItem ? Theme.bg0_h : Theme.fg
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: list.currentIndex = entry.index
                    onDoubleClicked: search.launch()
                  }
                }
              }
            }
          }
        }
      }
    }
