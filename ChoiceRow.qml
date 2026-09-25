import QtQuick
import qs.Commons
import qs.Ui as Ui

// One choice in a list: a title, a line of detail, marked when chosen and
// when the keyboard cursor is on it. After OmaCards' ChoiceRow.qml (MIT,
// see NOTICE).
Ui.CursorSurface {
  id: row
  property string title: ""
  property string detail: ""
  property bool selected: false
  property bool cursorHere: false
  property color textColor: Color.foreground
  property string fontFamily: Style.font.family
  signal activated()
  implicitHeight: labels.implicitHeight + Style.space(14)
  current: selected
  hasCursor: mouse.containsMouse || cursorHere
  opacity: enabled ? 1 : 0.55

  Column {
    id: labels
    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Style.space(10) }
    spacing: Style.space(2)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: row.title
      color: row.textColor
      font.family: row.fontFamily
      font.pixelSize: Style.font.body
      font.bold: row.selected
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      textFormat: Text.PlainText
      text: row.detail
      color: Qt.darker(row.textColor, 1.55)
      font.family: row.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    onClicked: if (row.enabled) row.activated()
  }
}
