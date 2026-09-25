import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "CardsModel.js" as CardsModel

// The Cards tab: Hyprflip's cards on every workspace, the one on screen
// first. Each shows its name, whether it is tiled or floating, and the apps
// on each side, the side on show in bold. Flip, edit and take apart the
// chosen one, or make a new one.
Column {
  id: tab
  required property var host
  readonly property var service: host.service
  readonly property var flip: service.flip
  readonly property var groups: CardsModel.groups(flip.snapshot.cards, service.focusedWorkspace)
  property string selectedKey: ""
  readonly property var selected: CardsModel.flat(groups).find(function(c) { return c.key === selectedKey }) || null
  spacing: Style.space(10)

  function titleOf(card) { return CardsModel.title(card, service.names, service.byAddress, service.appName) }

  function move(dx, dy) {
    if (dy === 0) return false
    selectedKey = CardsModel.step(groups, selectedKey, dy)
    return true
  }

  function key(text) {
    var k = String(text).toLowerCase()
    if (k === "n") { if (flip.canCreate) service.startBuilder(null); return }
    if (!selected) return
    if (k === "v") service.cardAction("flip", selected)
    else if (k === "e" && flip.canCreate) service.startBuilder(selected)
    else if (k === "d" && flip.canUnpair) service.cardAction("unpair", selected)
    else if (k === "u") service.cardAction("unfold", selected)
    else if (k === "t") service.cardAction("floating", selected)
  }

  function activate() {
    if (selected) service.cardAction("flip", selected)
  }

  onGroupsChanged: if (!selected) selectedKey = CardsModel.step(groups, selectedKey, 0)
  Component.onCompleted: selectedKey = CardsModel.step(groups, "", 0)

  Column {
    width: parent.width
    visible: !tab.flip.available
    spacing: Style.space(6)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: host.t("Cards need Hyprflip")
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: tab.flip.unavailableText
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      text: host.t("Check again")
      iconText: "󰑓"
      bordered: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.flip.check()
    }
  }

  Text {
    width: parent.width
    visible: text !== ""
    textFormat: Text.PlainText
    text: tab.flip.busy ? host.t("Working…") : (tab.flip.failed ? tab.flip.notice : tab.service.cardsNotice)
    color: tab.flip.failed ? host.urgent : host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  Text {
    width: parent.width
    visible: tab.flip.available && tab.groups.length === 0
    textFormat: Text.PlainText
    text: host.t("No cards yet. Press n to make one.")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: tab.flip.available ? tab.groups : []

    Column {
      id: group
      required property var modelData
      width: tab.width
      spacing: Style.space(6)

      PanelSectionHeader {
        width: parent.width
        text: host.t("Workspace %1", [group.modelData.workspace])
        foreground: host.foreground
        fontFamily: host.fontFamily
      }

      Repeater {
        model: group.modelData.cards

        Rectangle {
          id: cardRow
          required property var modelData
          readonly property bool chosen: tab.selectedKey === modelData.key
          readonly property var names: CardsModel.faceNames(modelData, tab.service.byAddress, tab.service.appName)
          width: group.width
          height: details.implicitHeight + Style.space(14)
          radius: Math.min(Style.cornerRadius, Style.space(6))
          color: chosen ? Qt.rgba(host.accent.r, host.accent.g, host.accent.b, 0.14) : "transparent"
          border.width: chosen ? 2 : 1
          border.color: chosen ? host.accent : Qt.rgba(host.foreground.r, host.foreground.g, host.foreground.b, 0.25)

          Column {
            id: details
            x: Style.space(10)
            y: Style.space(7)
            width: parent.width - Style.space(20)
            spacing: Style.space(2)

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Text {
                Layout.fillWidth: true
                textFormat: Text.PlainText
                text: tab.titleOf(cardRow.modelData)
                color: host.foreground
                font.family: host.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Text {
                textFormat: Text.PlainText
                text: CardsModel.modeText(cardRow.modelData, host.t)
                color: host.dim
                font.family: host.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Repeater {
              model: [0, 1]

              Text {
                required property int modelData
                width: details.width
                textFormat: Text.PlainText
                text: CardsModel.sideText(modelData, cardRow.names[modelData] || [], host.t)
                color: cardRow.modelData.active === modelData ? host.foreground : host.dim
                font.family: host.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: cardRow.modelData.active === modelData
                elide: Text.ElideRight
              }
            }
          }

          MouseArea {
            anchors.fill: parent
            onClicked: tab.selectedKey = cardRow.modelData.key
            onDoubleClicked: tab.service.cardAction("flip", cardRow.modelData)
          }
        }
      }
    }
  }

  Flow {
    width: parent.width
    spacing: Style.space(6)
    visible: tab.flip.available

    Button {
      text: host.t("Flip")
      iconText: "󰑓"
      bordered: true
      enabled: tab.selected !== null && !tab.flip.busy
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.cardAction("flip", tab.selected)
    }

    Button {
      text: host.t("Edit")
      iconText: "󰏫"
      bordered: true
      enabled: tab.selected !== null && tab.flip.canCreate && !tab.flip.busy
      tooltipText: tab.flip.canCreate ? "e" : host.t("Creating and editing cards needs the updated Hyprflip helper.")
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.startBuilder(tab.selected)
    }

    Button {
      text: host.t("Dismantle")
      iconText: "󰆴"
      bordered: true
      enabled: tab.selected !== null && tab.flip.canUnpair && !tab.flip.busy
      tooltipText: tab.flip.canUnpair ? "d" : host.t("Dismantling needs the updated Hyprflip helper.")
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.cardAction("unpair", tab.selected)
    }

    Button {
      text: host.t("New card")
      iconText: "＋"
      bordered: true
      enabled: tab.flip.canCreate && !tab.flip.busy
      tooltipText: tab.flip.canCreate ? "n" : host.t("Creating and editing cards needs the updated Hyprflip helper.")
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.startBuilder(null)
    }
  }

  Text {
    width: parent.width
    visible: tab.flip.available
    textFormat: Text.PlainText
    text: host.t("v flip · e edit · d dismantle · u unfold · t float · n new")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }
}
