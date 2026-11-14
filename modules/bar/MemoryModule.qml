import QtQuick
import qs.theme
import qs.services

Item {
  implicitWidth: memoryText.implicitWidth
  implicitHeight: memoryText.implicitHeight

  Text {
    id: memoryText
    text: "mem: " + Services.memory.memUsage + "%"
    color: Theme.blue2

    font {
      family: Theme.fontFamily
      pixelSize: Theme.fontSize
      weight: Theme.weight
    }
  }
}
