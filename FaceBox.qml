import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// One side of the card in the builder, with the shape of the place the card
// will take. Its windows are laid out as Hyprflip will lay them out (a row
// or a column); a window dropped here joins it where it lands.
Item {
  id: box
  required property var host
  required property int face
  property Item dragLayer: null
  property real aspect: 16 / 9
  readonly property var service: host.service
  readonly property var draft: service.draft
  readonly property var members: draft ? draft.faces[face] : []
  readonly property string axis: draft ? draft.axes[face] : "row"
  implicitHeight: header.implicitHeight + Style.space(6) + area.height

  RowLayout {
    id: header
    width: parent.width
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: box.face === 0 ? host.t("Front") : host.t("Back")
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: box.draft && box.draft.visible === box.face ? host.t("Showing") : ""
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
    }

    ButtonGroup {
      options: [{ value: "row", label: host.t("Row") }, { value: "column", label: host.t("Column") }]
      value: box.axis
      foreground: host.foreground
      fontFamily: host.fontFamily
      fontSize: Style.font.caption
      onChanged: function(value) { box.service.setAxis(box.face, value) }
    }
  }

  Rectangle {
    id: area
    y: header.implicitHeight + Style.space(6)
    width: parent.width
    height: Math.min(width / box.aspect, Style.space(240))
    radius: Math.min(Style.cornerRadius, Style.space(8))
    color: drop.containsDrag ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.12) : "transparent"
    border.width: 1
    border.color: drop.containsDrag ? host.accent : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.35)

    Grid {
      id: tiles
      anchors.fill: parent
      anchors.margins: Style.space(6)
      spacing: Style.space(6)
      columns: box.axis === "row" ? Math.max(1, box.members.length) : 1
      rows: box.axis === "column" ? Math.max(1, box.members.length) : 1

      Repeater {
        model: box.members

        WindowTile {
          required property var modelData
          host: box.host
          win: box.service.byAddress[modelData] || ({ address: modelData, "class": "", at: [0, 0], size: [1, 1] })
          face: box.face
          large: true
          current: box.draft !== null && box.draft.cursor === modelData
          dragLayer: box.dragLayer
          width: (tiles.width - tiles.spacing * (tiles.columns - 1)) / tiles.columns
          height: (tiles.height - tiles.spacing * (tiles.rows - 1)) / tiles.rows
        }
      }
    }

    Text {
      anchors.centerIn: parent
      visible: box.members.length === 0
      textFormat: Text.PlainText
      text: host.t("＋ drop here")
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    DropArea {
      id: drop
      anchors.fill: parent
      keys: ["save-them-all-window"]
      onDropped: function(event) {
        var n = box.members.length
        var along = box.axis === "row" ? event.x / width : event.y / height
        var index = Math.max(0, Math.min(n, Math.floor(along * (n + 1))))
        box.service.place(event.source.address, box.face, index)
        event.accept(Qt.MoveAction)
      }
    }
  }
}
