import QtQuick
import qs.Commons
import "Builder.js" as Builder
import "Pick.js" as Pick

// "Pick on screen": a veil over the monitor with the workspace's shown
// windows outlined. A click adds a window to the active side, or takes a
// picked one out; Tab switches side; Enter goes back to the builder with the
// picks and Esc without them. Only what is on screen can be picked.
Item {
  id: view
  required property var host
  property var origin: ({ x: 0, y: 0 })
  readonly property var service: host.service
  // The workspace to draw: the overlay pins this to what open() recorded,
  // so a live workspace switch elsewhere does not swap the windows shown
  // mid-pick. Standalone (tests), it follows the service like before.
  property int workspace: service.focusedWorkspace
  readonly property var draft: service.pickDraft
  readonly property int face: service.pickFace
  readonly property var ctx: Builder.context(service.flip.snapshot.cards, draft, service.flip.snapshot.capabilities)
  // The outlines' model, replaced only when a rect really changes (like
  // CardBuilder's groups): service.clients is a new array on every refresh
  // (a title or focus change) and Pick.rects() always builds new objects,
  // so binding the Repeater to it straight would redraw every outline on
  // each refresh, hover state included.
  property var rects: []
  property string rectsKey: ""
  function refreshRects() {
    var next = Pick.rects(service.clients, workspace, origin)
    var key = JSON.stringify(next)
    if (key === rectsKey) return
    rectsKey = key
    rects = next
  }
  onWorkspaceChanged: refreshRects()
  onOriginChanged: refreshRects()
  Component.onCompleted: refreshRects()
  Connections {
    target: view.service
    function onClientsChanged() { view.refreshRects() }
  }
  readonly property int count: draft ? draft.faces[0].length + draft.faces[1].length : 0
  property string hovered: ""
  focus: true

  function sideName(f) { return f === 0 ? host.t("Front") : host.t("Back") }

  Keys.onPressed: function(event) {
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      service.pickFace = 1 - face
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      service.finishPick(true)
      event.accepted = true
    } else if (event.key === Qt.Key_Escape) {
      service.finishPick(false)
      event.accepted = true
    }
  }

  Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.35) }

  Repeater {
    model: view.rects

    Rectangle {
      id: outline
      required property var modelData
      readonly property var win: view.service.byAddress[modelData.address] || null
      readonly property string why: win ? Builder.reason(win, view.ctx, view.host.t) : ""
      readonly property int picked: Pick.faceOfPick(view.draft, modelData.address)
      readonly property bool under: view.hovered === modelData.address
      x: modelData.x
      y: modelData.y
      width: modelData.w
      height: modelData.h
      color: picked >= 0 ? Qt.rgba(view.host.accent.r, view.host.accent.g, view.host.accent.b, 0.28)
        : (under && why === "" ? Qt.rgba(1, 1, 1, 0.12) : "transparent")
      border.width: (under && why === "") || picked >= 0 ? 3 : 1
      border.color: why !== "" ? Qt.rgba(1, 1, 1, 0.25) : view.host.accent

      Column {
        anchors.centerIn: parent
        width: parent.width - Style.space(20)
        visible: outline.under || outline.picked >= 0
        spacing: Style.space(4)

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: outline.win ? Builder.label(outline.win, view.service.clients, view.service.appName, view.host.t) : ""
          color: "white"
          font.family: view.host.fontFamily
          font.pixelSize: Style.font.title
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: outline.why !== "" ? outline.why : (outline.picked >= 0 ? view.sideName(outline.picked) : "")
          color: "white"
          font.family: view.host.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onPositionChanged: function(mouse) { view.hovered = Pick.hit(view.rects, mouse.x, mouse.y) }
    onClicked: function(mouse) {
      var address = Pick.hit(view.rects, mouse.x, mouse.y)
      var win = view.service.byAddress[address]
      if (address && win && Builder.reason(win, view.ctx, view.host.t) === "") view.service.pickToggle(address)
    }
  }

  Rectangle {
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Style.space(24)
    anchors.horizontalCenter: parent.horizontalCenter
    width: Math.min(parent.width - Style.space(32), bar.implicitWidth + Style.space(32))
    height: bar.implicitHeight + Style.space(20)
    radius: Style.cornerRadius
    color: Color.popups.background
    border.width: 1
    border.color: view.host.accent

    // Otherwise a click here falls through to the fullscreen MouseArea
    // behind it and toggles whatever window rect happens to sit under
    // the bar.
    MouseArea { anchors.fill: parent }

    Column {
      id: bar
      anchors.centerIn: parent
      width: Math.min(implicitWidth, parent.width - Style.space(32))
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText
        text: view.host.t("Adding to: %1", [view.sideName(view.face)]) + " · " + view.host.t("%1 picked", [view.count])
        color: view.host.foreground
        font.family: view.host.fontFamily
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        visible: text !== ""
        textFormat: Text.PlainText
        text: view.service.builderNotice
        color: view.host.urgent
        font.family: view.host.fontFamily
        font.pixelSize: Style.font.bodySmall
      }

      Text {
        textFormat: Text.PlainText
        text: view.host.t("Click a window to add or take it out · Tab switches side · Enter goes back with them · Esc goes back without changes")
        color: view.host.dim
        font.family: view.host.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }
}
