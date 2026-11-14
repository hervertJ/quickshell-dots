import QtQuick
import QtQuick.Layouts
import qs.theme

Rectangle {
  id: root

  // 0 = domingo, 1 = lunes (inicio de semana)
  property int firstDayOfWeek: 1
  property int viewYear: new Date().getFullYear()
  property int viewMonth: new Date().getMonth()

  readonly property date today: new Date()
  readonly property string monthLabel: Qt.formatDateTime(new Date(viewYear, viewMonth, 1), "MMMM yyyy")

  readonly property int firstWeekday: (new Date(viewYear, viewMonth, 1).getDay() - firstDayOfWeek + 7) % 7
  readonly property int daysInMonth: new Date(viewYear, viewMonth + 1, 0).getDate()

  readonly property var dayNames: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
  readonly property var weekdayLabels: {
    const out = [];
    for (let i = 0; i < 7; i++)
      out.push(dayNames[(firstDayOfWeek + i) % 7]);
    return out;
  }

  // 42 celdas (6 semanas) para el mes visible
  readonly property var cells: {
    const out = [];
    for (let i = 0; i < 42; i++) {
      const d = new Date(viewYear, viewMonth, i - firstWeekday + 1);
      const inMonth = d.getMonth() === viewMonth && d.getFullYear() === viewYear;
      out.push({
        day: d.getDate(),
        inMonth: inMonth,
        isToday: d.getFullYear() === today.getFullYear()
          && d.getMonth() === today.getMonth()
          && d.getDate() === today.getDate()
      });
    }
    return out;
  }

  function prevMonth() {
    if (viewMonth === 0) {
      viewMonth = 11;
      viewYear -= 1;
    } else {
      viewMonth -= 1;
    }
  }

  function nextMonth() {
    if (viewMonth === 11) {
      viewMonth = 0;
      viewYear += 1;
    } else {
      viewMonth += 1;
    }
  }

  implicitWidth: 320
  implicitHeight: layout.implicitHeight + 24
  radius: Theme.radius
  color: Theme.bg0_h

  // Traga el click sobre la tarjeta para que el overlay de fondo no la cierre
  MouseArea {
    anchors.fill: parent
  }

  ColumnLayout {
    id: layout
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
      margins: 12
    }
    spacing: 6

    RowLayout {
      Layout.fillWidth: true
      spacing: 0

      Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Text {
          anchors.centerIn: parent
          text: "‹"
          color: Theme.green2
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize + 4
          font.weight: Theme.weight
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.prevMonth()
        }
      }

      Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: root.monthLabel
        horizontalAlignment: Text.AlignHCenter
        color: Theme.green2
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 2
        font.weight: Theme.weight
      }

      Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: 28
        Text {
          anchors.centerIn: parent
          text: "›"
          color: Theme.green2
          font.family: Theme.fontFamily
          font.pixelSize: Theme.fontSize + 4
          font.weight: Theme.weight
        }
        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.nextMonth()
        }
      }
    }

    Grid {
      Layout.alignment: Qt.AlignHCenter
      columns: 7

      Repeater {
        model: root.weekdayLabels

        delegate: Item {
          required property var modelData
          width: 42
          height: 22
          Text {
            anchors.centerIn: parent
            text: modelData
            color: Theme.fg4
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 5
            font.weight: Theme.weight
          }
        }
      }
    }

    Grid {
      Layout.alignment: Qt.AlignHCenter
      columns: 7

      Repeater {
        model: root.cells

        delegate: Rectangle {
          required property var modelData

          width: 42
          height: 32
          radius: 8
          color: modelData.isToday ? Theme.green2 : (hover.hovered ? Theme.bg1 : "transparent")

          Text {
            anchors.centerIn: parent
            text: modelData.day
            color: modelData.isToday ? Theme.bg0_h : (modelData.inMonth ? Theme.fg : Theme.bg4)
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 4
            font.weight: Theme.weight
          }

          HoverHandler {
            id: hover
          }
        }
      }
    }
  }
}
