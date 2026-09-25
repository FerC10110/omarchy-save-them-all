import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "Builder.js" as Builder

// The card builder (spec §6.2, option B): the card on the left, drawn with
// the shape of its place, Front above and Back below; the windows that can
// join it on the right, the card's workspace first. Drag a window onto a
// side, or walk the list with j/k and press f (Front) or r (Back).
Item {
  id: page
  required property var host
  readonly property var service: host.service
  readonly property var draft: service.draft
  readonly property bool typing: nameField.activeFocus
  readonly property var ctx: Builder.context(service.flip.snapshot.cards, draft, service.flip.snapshot.capabilities)
  // The window list's model. Rebuilt only when what it actually shows can
  // differ (the draft's faces, the client list, or the language) — not on
  // every draft reassignment: a cursor move or a name keystroke also
  // replaces `draft` as a whole (Service.qml keeps it immutable), and
  // Builder.candidates() always returns brand new objects, so binding
  // `groups` straight to `draft` would tear down and rebuild every
  // WindowTile (and its live thumbnail) on each keypress.
  readonly property string groupsKey: draft ? Builder.facesKey(draft) + "\u0000" + service.lang : ""
  property var groups: []
  function refreshGroups() { groups = draft ? Builder.candidates(service.clients, draft, ctx, host.t) : [] }
  onGroupsKeyChanged: refreshGroups()
  Component.onCompleted: refreshGroups()
  property var expanded: ({})
  readonly property var order: {
    var out = []
    groups.forEach(function(g) {
      if (g.current || expanded[g.workspace]) g.windows.forEach(function(w) { if (w.reason === "") out.push(w.address) })
    })
    return out
  }
  readonly property var moving: draft ? Builder.movesFrom(draft, service.byAddress) : []
  readonly property int count: draft ? draft.faces[0].length + draft.faces[1].length : 0
  implicitHeight: layout.implicitHeight

  // service.clients is reassigned (a new array) on every real refresh, not
  // on a draft-only change, so this is exactly the "clients identity"
  // half of groups' invalidation — the other half is groupsKey, above.
  Connections {
    target: page.service
    function onClientsChanged() { page.refreshGroups() }
  }

  function move(dx, dy) {
    if (dy !== 0 && order.length > 0 && draft) {
      var i = order.indexOf(draft.cursor)
      var next = i < 0 ? 0 : Math.max(0, Math.min(order.length - 1, i + dy))
      service.moveCursor(order[next])
    }
    return true
  }

  function key(text) {
    if (!draft) return
    var k = String(text).toLowerCase()
    if (k === "f" && draft.cursor) service.place(draft.cursor, 0, -1)
    else if (k === "r" && draft.cursor) service.place(draft.cursor, 1, -1)
    else if (k === "n") nameField.forceActiveFocus()
    else if (k === "e") service.startPick()
  }

  function remove() {
    if (draft && draft.cursor && Builder.faceOf(draft, draft.cursor) >= 0) service.removeFromDraft(draft.cursor)
  }

  // submitDraft() itself guards on readiness and Hyprflip's state and sets
  // builderNotice accordingly, so Enter on an incomplete draft says why
  // instead of doing nothing.
  function activate() {
    service.submitDraft()
  }

  function back() {
    service.cancelBuilder()
    return true
  }

  function groupTitle(ws) {
    return ws > 0 ? host.t("Workspace %1", [ws]) : host.t("Special workspaces")
  }

  ColumnLayout {
    id: layout
    width: parent.width
    spacing: Style.space(10)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(10)

      Text {
        textFormat: Text.PlainText
        text: page.draft && page.draft.mode === "edit" ? host.t("Edit card") : host.t("New card")
        color: host.foreground
        font.family: host.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: page.draft ? host.t("Workspace %1 · %2 windows", [page.draft.workspace, page.count]) : ""
        color: host.dim
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
      }
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(14)

      Column {
        Layout.preferredWidth: layout.width * 0.56
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(10)

        Repeater {
          model: [0, 1]

          FaceBox {
            required property int modelData
            width: parent.width
            host: page.host
            face: modelData
            dragLayer: page
            aspect: Builder.slotAspect(page.draft, page.service.byAddress)
          }
        }
      }

      Column {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText
          text: host.t("Windows")
          color: host.foreground
          font.family: host.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Flickable {
          width: parent.width
          height: Math.min(list.implicitHeight, Style.space(460))
          contentWidth: width
          contentHeight: list.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: list
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: page.groups

              Column {
                id: group
                required property var modelData
                readonly property bool open: modelData.current || page.expanded[modelData.workspace] === true
                width: list.width
                spacing: Style.space(4)

                Button {
                  width: parent.width
                  text: page.groupTitle(group.modelData.workspace)
                  iconText: group.open ? "▾" : "▸"
                  leftAlign: true
                  foreground: host.foreground
                  fontFamily: host.fontFamily
                  fontSize: Style.font.bodySmall
                  onClicked: {
                    var next = Object.assign({}, page.expanded)
                    next[group.modelData.workspace] = !group.open
                    page.expanded = next
                  }
                }

                Repeater {
                  model: group.open ? group.modelData.windows : []

                  WindowTile {
                    required property var modelData
                    width: group.width
                    host: page.host
                    win: modelData.win
                    reason: modelData.reason
                    face: modelData.face
                    current: page.draft !== null && page.draft.cursor === modelData.address
                    dragLayer: page
                  }
                }
              }
            }
          }
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: page.moving.length > 0
      textFormat: Text.PlainText
      text: page.moving.length > 0 ? host.t("These windows will move to workspace %1: %2",
        [page.draft.workspace, page.moving.map(function(a) { return page.service.appName(page.service.byAddress[a]) }).join(", ")]) : ""
      color: host.accent
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      visible: text !== ""
      textFormat: Text.PlainText
      text: page.service.builderNotice
      color: host.urgent
      font.family: host.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
    }

    Text {
      Layout.fillWidth: true
      textFormat: Text.PlainText
      text: host.t("Drag a window onto a side, or pick it with j/k and press f (Front) or r (Back). x takes it out; e picks on screen.")
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(8)

      TextField {
        id: nameField
        Layout.fillWidth: true
        placeholderText: host.t("Card name (optional)")
        text: page.draft ? page.draft.name : ""
        maximumLength: 60
        onTextEdited: page.service.setDraftName(text)
        onAccepted: page.activate()
        Keys.onEscapePressed: page.forceActiveFocus()
      }

      Button {
        text: host.t("Pick on screen")
        iconText: "󰆿"
        bordered: true
        tooltipText: "e"
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.startPick()
      }

      Button {
        text: Builder.submitText(page.draft, host.t)
        iconText: "󰘸"
        bordered: true
        enabled: Builder.ready(page.draft) && !page.service.flip.busy
        iconSpinning: page.service.flip.busy
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.submitDraft()
      }

      Button {
        text: host.t("Cancel")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.cancelBuilder()
      }
    }
  }
}
