import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layout
import "../theme"

Scope {
  id: root

  PanelWindow {
    anchors { top: true; right: true }
    margins { top: 12; right: 12 }

    implicitWidth: 300
    implicitHeight: 800
    color: "transparent"

    exclusionMode: ExclusionMode.Ignore

    ColumnLayout {
      id: column
      width: parent.width
      spacing: 10
    }
  }
}
