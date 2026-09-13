import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

// The panel is a thin face over two bash scripts: it shows what is on disk for
// the workspace you are looking at, and runs save / restore. Everything it
// knows comes from the state file, which the scripts own, so a layout saved
// from the menu or the terminal shows up here without anyone being told.
Panel {
  id: root
  moduleName: "io.github.ferc10110.save-them-all"
  ipcTarget: "io.github.ferc10110.save-them-all"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property var record: null
  property string lastError: ""
  property string phase: ""        // "save" | "restore" | ""

  readonly property bool busy: phase !== ""
  readonly property bool hasSaved: record !== null
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property string stateDir: Quickshell.env("SAVE_THEM_ALL_STATE") || (Quickshell.env("HOME") + "/.local/state/save-them-all")
  readonly property string statePath: workspaceId > 0 ? stateDir + "/workspace-" + workspaceId + ".json" : ""

  readonly property var savedWindows: record && Array.isArray(record.windows) ? record.windows : []
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string summaryText: {
    if (lastError !== "") return lastError
    if (phase === "save") return "Saving…"
    if (phase === "restore") return "Restoring…"
    if (!hasSaved) return "Nothing saved for this workspace yet."
    var n = savedWindows.length
    return n + (n === 1 ? " window" : " windows") + " · saved " + savedAtText
  }

  readonly property string savedAtText: {
    if (!record || !record.saved_at) return "earlier"
    var when = new Date(String(record.saved_at))
    if (isNaN(when.getTime())) return "earlier"
    var now = new Date()
    var sameDay = when.getFullYear() === now.getFullYear()
      && when.getMonth() === now.getMonth()
      && when.getDate() === now.getDate()
    return sameDay ? Qt.formatTime(when, "HH:mm") : Qt.formatDateTime(when, "d MMM HH:mm")
  }

  // Absolute path of a file shipped inside this plugin. Qt resolves it against
  // the plugin folder, wherever the user installed it, so nothing is hardcoded.
  function pluginPath(relative) {
    var url = String(Qt.resolvedUrl(relative))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }

  // Window classes are addresses, not names. Chromium names a webapp window
  // after its URL (chrome-host__some_path-Default), where the host is the part
  // a person recognises; a reverse-DNS class (org.gnome.Nautilus) carries its
  // name in the last segment. Anything else is already as readable as it gets.
  function prettyClass(cls) {
    var name = String(cls || "")
    var webapp = name.match(/^chrome-([^_]+)__.*-Default$/)
    if (webapp) return webapp[1]
    var parts = name.split(".")
    if (parts.length >= 3 && parts[parts.length - 1] !== "") return parts[parts.length - 1]
    return name
  }

  function run(phaseName, script) {
    if (busy) return
    lastError = ""
    phase = phaseName
    proc.command = [pluginPath("bin/" + script), "--quiet"]
    proc.running = true
  }

  function save() {
    run("save", "save-them-all")
  }

  function restore() {
    if (!hasSaved) return
    run("restore", "restore-them-all")
    // Restoring shuffles every window on the workspace; a panel floating over
    // that is in the way of the thing you asked to look at.
    close()
  }

  // The scripts own the state file, so the panel simply reads whatever is
  // there — including layouts saved from the menu, a keybinding or a terminal.
  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var parsed = JSON.parse(String(text() || ""))
        root.record = parsed && typeof parsed === "object" && Array.isArray(parsed.windows) ? parsed : null
      } catch (e) {
        root.record = null
      }
    }
    onLoadFailed: root.record = null
  }

  Process {
    id: proc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.lastError = message.split("\n").pop()
      }
    }
    onExited: function(exitCode) {
      root.phase = ""
      if (exitCode === 0) root.lastError = ""
      else if (root.lastError === "") root.lastError = "Something went wrong. Check the notification."
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(520))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        var key = String(t).toLowerCase()
        if (key === "s") root.save()
        else if (key === "r") root.restore()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(10)

        PanelHero {
          id: hero
          width: parent.width
          title: "Save Them All"
          meta: root.workspaceId > 0 ? "Workspace " + root.workspaceId : "No workspace"
          foreground: root.foreground
          fontFamily: root.fontFamily
          // `root` inside this Component resolves to PanelHero, not this
          // Panel, so the icon reads its colors off the hero by id.
          iconComponent: Component {
            Text {
              text: "󱂬"
              color: hero.foreground
              font.family: hero.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          textFormat: Text.PlainText
          width: parent.width
          text: root.summaryText
          color: root.lastError !== "" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          width: parent.width
          visible: root.savedWindows.length > 0
          foreground: root.foreground
        }

        // What is on disk, in the order the layout was saved: left to right,
        // top to bottom. Seeing the names is how you tell two saves apart.
        Column {
          width: parent.width
          visible: root.savedWindows.length > 0
          spacing: Style.space(2)

          Repeater {
            model: root.savedWindows

            Text {
              required property var modelData
              textFormat: Text.PlainText
              width: parent.width
              text: "· " + root.prettyClass(modelData["class"])
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        ColumnLayout {
          width: parent.width
          spacing: Style.space(6)

          Button {
            Layout.fillWidth: true
            text: "Save them all"
            iconText: "󰆓"
            tooltipText: "Save every window on this workspace (s)"
            enabled: !root.busy && root.workspaceId > 0
            leftAlign: true
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconSpinning: root.phase === "save"
            onClicked: root.save()
          }

          Button {
            Layout.fillWidth: true
            text: "Restore them all"
            iconText: "󰑓"
            tooltipText: root.hasSaved
              ? "Reopen the saved layout (r)"
              : "Nothing saved for this workspace yet"
            enabled: !root.busy && root.hasSaved
            leftAlign: true
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconSpinning: root.phase === "restore"
            onClicked: root.restore()
          }
        }
      }
    }
  }
}
