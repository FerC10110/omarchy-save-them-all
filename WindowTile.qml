import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Builder.js" as Builder

// One window in the card builder: a thumbnail (or its icon), its readable
// name and, when it cannot join a card, why. Drag it onto a side of the
// card; drag a placed one off the card to take it out.
Item {
  id: tile
  required property var host
  required property var win
  property string reason: ""
  property int face: -1            // the side it is on, or -1
  property bool current: false     // the keyboard cursor is here
  property bool large: false       // drawn inside a side of the card
  property Item dragLayer: null
  property bool dragged: false
  readonly property var service: host.service
  readonly property string address: win ? win.address : ""
  readonly property bool usable: reason === ""
  readonly property bool hot: mouse.containsMouse || current
  implicitWidth: Style.space(220)
  implicitHeight: large ? Style.space(90) : Style.space(46)

  Item {
    id: body
    property string address: tile.address
    width: tile.width
    height: tile.height
    opacity: tile.usable ? 1 : 0.45
    Drag.active: mouse.drag.active
    Drag.keys: ["save-them-all-window"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2
    Drag.onActiveChanged: if (Drag.active) tile.dragged = true

    Rectangle {
      anchors.fill: parent
      radius: Math.min(Style.cornerRadius, Style.space(6))
      color: tile.hot ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.14) : "transparent"
      border.width: tile.current ? 2 : 1
      border.color: tile.current ? host.accent : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.25)
    }

    Item {
      id: picture
      x: Style.space(4)
      y: Style.space(4)
      width: tile.large ? parent.width - Style.space(8) : (parent.height - Style.space(8)) * 16 / 9
      height: tile.large ? parent.height - names.height - Style.space(10) : parent.height - Style.space(8)
      clip: true

      Loader {
        id: thumb
        anchors.fill: parent
        active: tile.service.thumbnails === true
        source: "Thumb.qml"
        onLoaded: {
          item.toplevel = Qt.binding(function() { return tile.service.toplevelFor(tile.address) })
          item.live = Qt.binding(function() { return tile.hot })
        }
      }

      Image {
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.6
        height: width
        visible: !(thumb.item && thumb.item.hasContent)
        source: {
          var icon = tile.service.appIcon(tile.win)
          return icon.indexOf("/") === 0 ? "file://" + icon : Quickshell.iconPath(icon || "application-x-executable", true)
        }
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }
    }

    Column {
      id: names
      x: tile.large ? Style.space(6) : picture.x + picture.width + Style.space(8)
      y: tile.large ? parent.height - height - Style.space(4) : (parent.height - height) / 2
      width: parent.width - x - Style.space(6)
      spacing: Style.space(1)

      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: Builder.label(tile.win, tile.service.clients, tile.service.appName, host.t)
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.bodySmall
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        textFormat: Text.PlainText
        text: tile.reason
        color: host.dim
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      enabled: tile.usable
      drag.target: body
      onPressed: tile.dragged = false
      onClicked: tile.service.moveCursor(tile.address)
      onReleased: {
        if (!tile.dragged) return
        var action = body.Drag.drop()
        if (action === Qt.IgnoreAction && tile.face >= 0) tile.service.removeFromDraft(tile.address)
      }
    }

    // While dragged, the tile leaves its list (which clips) for the page.
    states: State {
      when: mouse.drag.active && tile.dragLayer !== null
      ParentChange { target: body; parent: tile.dragLayer }
    }
  }
}
