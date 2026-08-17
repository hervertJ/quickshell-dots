import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../theme"

PanelWindow {
  id: root
  anchors { bottom: true }
  implicitWidth: Screen.width * 0.4
  implicitHeight: Screen.width * 0.3
  color: Theme.bg0_h
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  focusable: true
  visible: false

  GlobalShortcut {
    name: "toggle-clipboard"
    onPressed: root.toggle()
  }

  function toggle() {
    root.visible = !root.visible
    if (root.visible) {
      clipModel.clear()
      appClipboardView.currentIndex = 0
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

    Keys.onPressed: (event) => {
      if (event.modifiers & Qt.ControlModifier) {
        if (event.key === Qt.Key_N) {
          appClipboardView.currentIndex = Math.min(appClipboardView.currentIndex + 1, appClipboardView.count - 1)
          appClipboardView.positionViewAtIndex(appClipboardView.currentIndex, ListView.Center)
          event.accepted = true
        } else if (event.key === Qt.Key_P) {
          appClipboardView.currentIndex = Math.max(appClipboardView.currentIndex - 1, 0)
          appClipboardView.positionViewAtIndex(appClipboardView.currentIndex, ListView.Center)
          event.accepted = true
        }
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        if (appClipboardView.currentIndex >= 0 && appClipboardView.currentIndex < appClipboardView.count) {
          copyProcess.clipId = clipModel.get(appClipboardView.currentIndex).clipId
          copyProcess.running = true
        }
        event.accepted = true
      }
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
      currentIndex: 0

      delegate: Rectangle {
        width: ListView.view.width
        height: 45
        color: ListView.isCurrentItem ? Theme.green2 : (mouseArea.containsMouse ? Theme.bg : Theme.bg0_h)
        radius: 8

        Text {
          text: model.content
          //color: Theme.fg
          color: ListView.isCurrentItem? Theme.red1 : Theme.fg
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
