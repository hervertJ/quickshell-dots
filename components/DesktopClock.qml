import QtQuick
import Quickshell
import "../theme"

Item {
  id: root

  property int shadowOffset: 15
  // property real shadowOpacity: 0.65
  property real shadowOpacity: 1

  implicitWidth: clockText.implicitWidth
  implicitHeight: clockText.implicitHeight

  readonly property string time: Qt.formatDateTime(clock.date, "HH:mm")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  Text {
    id: shadowText
    anchors.centerIn: parent
    anchors.horizontalCenterOffset: root.shadowOffset
    anchors.verticalCenterOffset: root.shadowOffset
    color: Theme.bg0_h
    opacity: root.shadowOpacity
    text: root.time
    font: clockText.font
    z: 0
  }

  Text {
    id: clockText
    anchors.centerIn: parent
    color: Theme.fg
    text: root.time

    font {
      family: "Noto Serif CJK JP"
      pixelSize: 500
      weight: 800
      letterSpacing: 30
    }
    z: 1
  }
}
