import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import qs.theme

Item {
  id: root
  property bool calendarOpen: false

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  Text {
    id: label
    anchors.fill: parent
    color: Theme.green2
    text: Qt.formatDateTime(clock.date, "ddd, MMM dd - HH:mm")

    font {
      family: Theme.fontFamily
      pixelSize: Theme.fontSize
      letterSpacing: 0
      weight: Theme.weight
    }

    SystemClock {
      id: clock
      precision: SystemClock.Minutes
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.calendarOpen = !root.calendarOpen
  }

  // Cierra el calendario si cambias de workspace mientras está abierto
  Connections {
    target: Hyprland

    function onRawEvent(event) {
      if (root.calendarOpen && event.name === "workspace")
        root.calendarOpen = false;
    }
  }

  // PanelWindow no hereda de Item -> LazyLoader (no Loader normal)
  LazyLoader {
    active: root.calendarOpen

    PanelWindow {
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "quickshell:calendar"
      exclusionMode: ExclusionMode.Ignore
      focusable: true

      color: "transparent"

      // Overlay fullscreen transparente: atrapa el click de "afuera" y el foco
      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      MouseArea {
        anchors.fill: parent
        focus: true
        Component.onCompleted: forceActiveFocus()
        onClicked: root.calendarOpen = false
        Keys.onEscapePressed: root.calendarOpen = false
      }

      // Tarjeta top-centro, justo debajo de la barra (40px + aire)
      CalendarGrid {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 48
      }
    }
  }
}
