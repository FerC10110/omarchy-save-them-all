import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "I18n.js" as I18n

// The panel is a face over the scripts in bin/ and over the plugin's service.
// It shows tabs (Workspace, and later Cards and Settings) and loads each page
// with itself as `host`: the pages read state and call actions through it.
// What it knows about saved layouts comes from files the scripts own, so a
// layout saved from the menu or a terminal shows up here too.
Panel {
  id: root
  moduleName: "io.github.ferc10110.save-them-all"
  ipcTarget: "io.github.ferc10110.save-them-all"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var service: null

  property var record: null
  property string lastError: ""
  property string phase: ""        // "save" | "restore" | ""
  property var loginRows: []       // [{ workspace, windows, cards, saved_at, autostart }]
  property bool listPending: false
  property var browserQuit: ({ enabled: false, conflict: "" })
  property string browserQuitError: ""

  readonly property bool busy: phase !== ""
  readonly property bool hasSaved: record !== null
  readonly property int workspaceId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property string stateDir: Quickshell.env("SAVE_THEM_ALL_STATE") || (Quickshell.env("HOME") + "/.local/state/save-them-all")
  readonly property string statePath: workspaceId > 0 ? stateDir + "/workspace-" + workspaceId + ".json" : ""
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // Tabs, in order, and every page by name. Later tasks add entries.
  readonly property var tabs: ["workspace", "cards"]
  readonly property var pages: ({ workspace: "WorkspaceTab.qml", cards: "CardsTab.qml", builder: "CardBuilder.qml" })
  property string pageName: "workspace"
  readonly property bool onTab: tabs.indexOf(pageName) >= 0
  readonly property bool wide: pageName === "builder"

  function t(text, args) { return service ? service.t(text, args) : I18n.t(text, "en", args) }

  function tabLabel(id) {
    switch (id) {
    case "workspace": return t("Workspace")
    case "cards": return t("Cards")
    default: return id
    }
  }

  function openPage(name) {
    if (!(name in pages)) return
    // Already showing it (e.g. h/l or its digit with nothing to switch to):
    // do not reload the page, or a later page's own state would be lost.
    if (name === pageName && page.item) {
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
      return
    }
    pageName = name
    page.setSource(pages[name], { host: root })
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function selectTab(index) {
    if (index >= 0 && index < tabs.length) openPage(tabs[index])
  }

  function stepTab(direction) {
    var i = tabs.indexOf(pageName)
    if (i < 0) return false
    selectTab((i + direction + tabs.length) % tabs.length)
    return true
  }

  // Back from the builder: the Cards tab once it exists, else the first.
  function openHome() { openPage("cards" in pages ? "cards" : tabs[0]) }

  function pluginPath(relative) {
    var url = String(Qt.resolvedUrl(relative))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }

  function run(phaseName, script) {
    if (busy) return
    lastError = ""
    phase = phaseName
    proc.command = [pluginPath("bin/" + script), "--quiet"]
    proc.running = true
  }

  function save() { run("save", "save-them-all") }

  function restore() {
    if (!hasSaved) return
    run("restore", "restore-them-all")
    // Restoring shuffles every window on the workspace; a panel floating over
    // that is in the way of the thing you asked to look at.
    close()
  }

  // Hyprflip asks for the keyboard back while it works (a "handoff"); the
  // service shows the panel again when the action ends.
  function dismiss() { close() }
  function reveal() { open() }

  function refreshLogin() {
    if (listProc.running) listPending = true
    else listProc.running = true
  }

  function toggleLogin(row) {
    if (toggleProc.running) return
    var on = row.autostart !== true
    // Flip the switch on screen now; the list read after the write confirms it.
    loginRows = loginRows.map(function(r) {
      return r.workspace === row.workspace ? Object.assign({}, r, { autostart: on }) : r
    })
    toggleProc.command = [pluginPath("bin/restore-them-all-at-login"), on ? "--enable" : "--disable", String(row.workspace)]
    toggleProc.running = true
  }

  function setBrowserQuitError(text) {
    var message = String(text || "").trim()
    if (message !== "") browserQuitError = message.split("\n").pop().replace(/^close-browser-at-logout: /, "")
  }

  function refreshBrowserQuit() {
    if (!quitStatusProc.running) quitStatusProc.running = true
  }

  function toggleBrowserQuit() {
    var blocked = browserQuit.enabled !== true && (browserQuit.conflict !== "" || browserQuitError !== "")
    if (quitToggleProc.running || blocked) return
    var on = browserQuit.enabled !== true
    browserQuitError = ""
    browserQuit = Object.assign({}, browserQuit, { enabled: on })
    quitToggleProc.command = [pluginPath("bin/close-browser-at-logout"), on ? "--enable" : "--disable"]
    quitToggleProc.running = true
  }

  onServiceChanged: if (service && opened) service.attach(root)

  onOpenedChanged: if (opened) {
    if (service) service.attach(root)
    refreshLogin()
    browserQuitError = ""
    refreshBrowserQuit()
    if (!page.item) openPage(pageName)
  }

  Component.onCompleted: refreshLogin()

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: true
    printErrors: false
    onFileChanged: {
      reload()
      root.refreshLogin()
    }
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
    environment: ({ SAVE_THEM_ALL_LANG: root.service ? root.service.lang : "" })
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
      else if (root.lastError === "") root.lastError = root.t("Something went wrong. Check the notification.")
      root.refreshLogin()
    }
  }

  Process {
    id: listProc
    command: [root.pluginPath("bin/restore-them-all-at-login"), "--list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var rows = JSON.parse(String(text || "[]"))
          root.loginRows = Array.isArray(rows) ? rows : []
        } catch (e) {
          root.loginRows = []
        }
      }
    }
    onExited: {
      if (!root.listPending) return
      root.listPending = false
      running = true
    }
  }

  Process {
    id: toggleProc
    onExited: root.refreshLogin()
  }

  Process {
    id: quitStatusProc
    command: [root.pluginPath("bin/close-browser-at-logout"), "--status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var status = JSON.parse(String(text || ""))
          if (status && typeof status === "object") root.browserQuit = status
        } catch (e) {}
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.setBrowserQuitError(text)
    }
  }

  Process {
    id: quitToggleProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.setBrowserQuitError(text)
    }
    onExited: root.refreshBrowserQuit()
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(root.wide ? Style.space(760) : Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, root.wide ? Style.space(760) : Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: page.item ? page.item.typing === true : false
      onCloseRequested: {
        if (page.item && typeof page.item.back === "function" && page.item.back()) return
        root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (page.item && typeof page.item.move === "function" && page.item.move(dx, dy)) return
        if (dx !== 0) root.stepTab(dx)
      }
      // Enter only, not Space: PanelKeyCatcher fires returnRequested()
      // exclusively for Enter, and activateRequested() for both (a page
      // like CardBuilder's Enter submits the card; Space must not).
      // WorkspaceTab has no activate(), so this is unaffected there.
      onReturnRequested: if (page.item && typeof page.item.activate === "function") page.item.activate()
      onDeleteRequested: if (page.item && typeof page.item.remove === "function") page.item.remove()
      onTextKey: function(text) {
        if (root.onTab && text >= "1" && text <= "9") { root.selectTab(Number(text) - 1); return }
        if (page.item && typeof page.item.key === "function") page.item.key(String(text))
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: column
          width: flick.width
          spacing: Style.space(10)

          PanelHero {
            id: hero
            width: parent.width
            visible: root.onTab
            title: "Save Them All"
            meta: root.workspaceId > 0 ? root.t("Workspace %1", [root.workspaceId]) : root.t("No workspace")
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󱂬"
                color: hero.foreground
                font.family: hero.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Row {
            width: parent.width
            visible: root.onTab && root.tabs.length > 1
            spacing: Style.space(6)

            Repeater {
              model: root.tabs

              Button {
                required property var modelData
                required property int index
                text: root.tabLabel(modelData)
                tooltipText: String(index + 1)
                selected: root.pageName === modelData
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.openPage(modelData)
              }
            }
          }

          Loader {
            id: page
            width: parent.width
          }
        }
      }
    }
  }
}
