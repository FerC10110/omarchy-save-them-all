import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

// The Workspace tab: what is saved for the workspace you are on, the notice
// when its saved cards are paused, save / restore, and which workspaces come
// back at login. Everything it shows comes from files the scripts own.
Column {
  id: tab
  required property var host
  readonly property var service: host.service
  readonly property var record: host.record
  readonly property var windows: record && Array.isArray(record.windows) ? record.windows : []
  readonly property int cardCount: record && Array.isArray(record.cards) ? record.cards.length : 0
  readonly property bool cardsPaused: cardCount > 0 && service !== null
    && service.flip.status.reason !== "" && !service.flip.available
  spacing: Style.space(10)

  function key(text) {
    var k = String(text).toLowerCase()
    if (k === "s") host.save()
    else if (k === "r") host.restore()
  }

  function windowsText(n) { return n === 1 ? host.t("1 window") : host.t("%1 windows", [n]) }
  function cardsText(n) { return n === 1 ? host.t("1 card") : host.t("%1 cards", [n]) }

  readonly property string savedAtText: {
    if (!record || !record.saved_at) return host.t("earlier")
    var when = new Date(String(record.saved_at))
    if (isNaN(when.getTime())) return host.t("earlier")
    var now = new Date()
    var sameDay = when.getFullYear() === now.getFullYear() && when.getMonth() === now.getMonth()
      && when.getDate() === now.getDate()
    return sameDay ? Qt.formatTime(when, "HH:mm") : Qt.formatDateTime(when, "d MMM HH:mm")
  }

  readonly property string summaryText: {
    if (host.lastError !== "") return host.lastError
    if (host.phase === "save") return host.t("Saving…")
    if (host.phase === "restore") return host.t("Restoring…")
    if (!record) return host.t("Nothing saved for this workspace yet.")
    var parts = [windowsText(windows.length)]
    if (cardCount > 0) parts.push(cardsText(cardCount))
    parts.push(host.t("saved %1", [savedAtText]))
    return parts.join(" · ")
  }

  Text {
    textFormat: Text.PlainText
    width: parent.width
    text: tab.summaryText
    color: host.lastError !== "" ? host.urgent : host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  // Hyprflip is gone but this workspace saved cards: say why, and offer to
  // take the windows out of their groups so none stays hidden.
  Column {
    width: parent.width
    visible: tab.cardsPaused
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: host.t("Cards paused")
      color: host.urgent
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      textFormat: Text.PlainText
      width: parent.width
      text: tab.service ? tab.service.flip.unavailableText : ""
      color: host.dim
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Button {
      text: host.t("Show both faces")
      iconText: "󰕰"
      tooltipText: host.t("Take this workspace's windows out of their groups so none stays hidden")
      bordered: true
      leftAlign: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      onClicked: tab.service.ungroup(host.workspaceId)
    }
  }

  PanelSeparator {
    width: parent.width
    visible: tab.windows.length > 0
    foreground: host.foreground
  }

  // What is on disk, in the order the layout was saved.
  Column {
    width: parent.width
    visible: tab.windows.length > 0
    spacing: Style.space(2)

    Repeater {
      model: tab.windows

      Text {
        required property var modelData
        textFormat: Text.PlainText
        width: parent.width
        text: "· " + (tab.service ? tab.service.appName(modelData) : String(modelData["class"]))
        color: host.dim
        font.family: host.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  PanelSeparator { width: parent.width; foreground: host.foreground }

  ColumnLayout {
    width: parent.width
    spacing: Style.space(6)

    Button {
      Layout.fillWidth: true
      text: host.t("Save them all")
      iconText: "󰆓"
      tooltipText: host.t("Save every window on this workspace (s)")
      enabled: !host.busy && host.workspaceId > 0
      leftAlign: true
      bordered: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      iconSpinning: host.phase === "save"
      onClicked: host.save()
    }

    Button {
      Layout.fillWidth: true
      text: host.t("Restore them all")
      iconText: "󰑓"
      tooltipText: host.hasSaved ? host.t("Reopen the saved layout (r)") : host.t("Nothing saved for this workspace yet.")
      enabled: !host.busy && host.hasSaved
      leftAlign: true
      bordered: true
      foreground: host.foreground
      fontFamily: host.fontFamily
      iconSpinning: host.phase === "restore"
      onClicked: host.restore()
    }
  }

  // Which layouts come back on their own at login: one switch per saved
  // workspace. The choice lives in each layout's own file.
  PanelSeparator { width: parent.width; visible: host.loginRows.length > 0; foreground: host.foreground }

  PanelSectionHeader {
    width: parent.width
    visible: host.loginRows.length > 0
    text: host.t("Restore at login")
    foreground: host.foreground
    fontFamily: host.fontFamily
  }

  Column {
    width: parent.width
    visible: host.loginRows.length > 0
    spacing: Style.space(6)

    Repeater {
      model: host.loginRows

      Toggle {
        required property var modelData
        width: parent.width
        label: host.t("Workspace %1", [modelData.workspace])
        description: tab.windowsText(modelData.windows)
          + (modelData.cards > 0 ? " · " + tab.cardsText(modelData.cards) : "")
          + (modelData.workspace === host.workspaceId ? " · " + host.t("this workspace") : "")
        checked: modelData.autostart === true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: host.toggleLogin(modelData)
      }
    }
  }

  BrowserQuitRow { width: parent.width; host: tab.host }
}
