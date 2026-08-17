import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

PanelWindow {
  id: root
  //implicitWidth: 700
  //implicitHeight: 700
  implicitWidth: Screen.width * 0.4
  implicitHeight: Screen.width * 0.3
  color: Theme.bg0_h

  anchors { bottom: true }

  WlrLayershell.layer: WlrLayer.Overlay // Lo pone por encima de todo
  focusable: true
  exclusionMode: ExclusionMode.Ignore
  visible: false

  GlobalShortcut {
    name: "toggle-clipboard"
    onPressed: root.toggle()
  }

  function toggle() {
    root.visible = !root.visible
    if (root.visible) {
      clipModel.clear()
      readHistory.running = true
      column.forceActiveFocus()
    }
  }

  ColumnLayout {
    id: column
    spacing: 10

    anchors.fill: parent
    focus: true

    Keys.onEscapePressed: {
      root.visible = false;
    }

    ListModel {
      id: clipModel
    }

    ListView {

      id: appClipboardView


      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.margins: 10
      model: clipModel


      clip: true
      spacing: 5

      delegate: Rectangle {
        width: ListView.view.width
        height: 45
        color: mouseArea.containsMouse ? Theme.green2: Theme.bg0_h
        radius: 8

        Text {
          text: model.content
          color: Theme.fg
          font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 4; weight: Theme.weight }
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: 10
          elide: Text.ElideRight
          //width: parent.width - 20
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: {
            copyProcess.clipId = model.clipId;
            copyProcess.running = true;
          }
        }
      }
    }
  }

  // --- PROCESOS ---

  Process {
    id: copyProcess
    property string clipId: ""

    command: ["sh", "-c", "cliphist list | grep '^" + clipId + "\t' | cliphist decode | wl-copy"]

    onExited: {
      root.visible = false;
    }
  }

  Process {
    id: readHistory
    command: ["sh", "-c", "cliphist list | head -n 30"]

    stdout: SplitParser {
      onRead: (data) => {
        let partes = data.split("\t");
        if (partes.length > 1) {
          clipModel.append({ "clipId": partes[0], "content": partes[1] });
        }
      }
    }
    onExited: running = false
  }
}
