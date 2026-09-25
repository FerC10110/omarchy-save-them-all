import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "I18n.js" as I18n
import "AppNames.js" as AppNames

// Loaded once by the shell (kind "service"). It owns what outlives the
// panel: the language, the connection to Hyprflip, the list of windows and
// the card names of this session. The bar's panel (and, later, the pick
// overlay) read it as `service`.
Scope {
  id: root
  property var shell: null
  property var manifest: null

  readonly property string pluginId: "io.github.ferc10110.save-them-all"
  readonly property string stateDir: Quickshell.env("SAVE_THEM_ALL_STATE") || (Quickshell.env("HOME") + "/.local/state/save-them-all")
  readonly property string runtimeDir: Quickshell.env("SAVE_THEM_ALL_RUNTIME")
    || (Quickshell.env("XDG_RUNTIME_DIR") ? Quickshell.env("XDG_RUNTIME_DIR") + "/save-them-all" : "")
  readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || ""
  readonly property string binDir: pluginPath("bin")

  property var settingsData: ({})
  readonly property string languageSetting: ["en", "es"].indexOf(settingsData.language) >= 0 ? settingsData.language : "auto"
  readonly property string lang: I18n.resolveLang(languageSetting,
    Quickshell.env("LC_ALL") || Quickshell.env("LC_MESSAGES") || Quickshell.env("LANG") || "")

  property var panel: null          // the bar panel shown last
  property var clients: []
  property var names: ({})
  readonly property var byAddress: {
    var out = {}
    clients.forEach(function(c) { out[c.address] = c })
    return out
  }
  readonly property var entries: DesktopEntries.applications.values.map(function(e) {
    return { id: e.id, name: e.name, icon: e.icon, startupClass: e.startupClass, exec: e.execString }
  })
  readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool watching: panel !== null && panel.opened === true
  readonly property var flip: flipConnection

  function pluginPath(relative) {
    var url = String(Qt.resolvedUrl(relative))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }

  function t(text, args) { return I18n.t(text, lang, args) }
  function appName(win) { return AppNames.resolve(win, entries).name }
  function appIcon(win) { return AppNames.resolve(win, entries).icon }

  // The panel calls this when it opens: it is the one to close for a
  // handoff and to show again afterwards.
  function attach(p) {
    panel = p
    flipConnection.check()
    refreshClients()
  }

  function setLanguage(value) {
    var next = Object.assign({}, settingsData, { language: value })
    settingsData = next
    settingsWrite.command = ["sh", "-c",
      'mkdir -p "$1" && printf "%s\\n" "$2" >"$1/.settings.tmp" && mv "$1/.settings.tmp" "$1/settings.json"',
      "sh", stateDir, JSON.stringify(next)]
    settingsWrite.running = true
  }

  function setName(id, name) {
    Quickshell.execDetached([binDir + "/cards", "name", "--id", String(id), "--name", String(name || "")])
  }

  // "Show both faces": let go of every native group on the workspace.
  function ungroup(workspace) {
    if (ungroupProcess.running) return
    ungroupProcess.command = [binDir + "/cards", "ungroup", "--workspace", String(workspace)]
    ungroupProcess.running = true
  }

  function refreshClients() {
    if (clientsProcess.running) clientsPending = true
    else clientsProcess.running = true
  }
  property bool clientsPending: false

  // Hyprland's toplevel for a window address ("0x…"), for live thumbnails.
  function toplevelFor(address) {
    var bare = String(address || "").replace(/^0x/, "")
    return Hyprland.toplevels.values.find(function(tl) { return tl.address === bare }) || null
  }

  function flipFinished(action, ok, message, pending) {
    var reopen = pending && pending.options && pending.options.reopen
    var ws = flipConnection.sent && flipConnection.sent.context ? flipConnection.sent.context.workspace : 0
    if (reopen && panel && (!ws || ws === focusedWorkspace)) panel.reveal()
  }

  Hyprflip {
    id: flipConnection
    t: function(text, args) { return root.t(text, args) }
    binDir: root.binDir
    lang: root.lang
    owner: root.panel
    watching: root.watching
    onFinished: function(action, ok, message, pending) { root.flipFinished(action, ok, message, pending) }
  }

  FileView {
    path: root.stateDir + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(String(text() || "{}"))
        root.settingsData = data && typeof data === "object" && !Array.isArray(data) ? data : {}
      } catch (e) {
        root.settingsData = {}
      }
    }
  }

  Process { id: settingsWrite }

  // Card names of this Hyprland session, written by bin/cards.
  FileView {
    path: root.runtimeDir && root.instance ? root.runtimeDir + "/cards-" + root.instance + ".json" : ""
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var data = JSON.parse(String(text() || "{}"))
        root.names = data && typeof data === "object" && !Array.isArray(data) ? data : {}
      } catch (e) {
        root.names = {}
      }
    }
    onLoadFailed: root.names = {}
  }

  Process {
    id: clientsProcess
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var list = JSON.parse(String(text || "[]"))
          root.clients = Array.isArray(list) ? list.filter(function(c) { return c && c.address }) : []
        } catch (e) {}
      }
    }
    onExited: {
      if (!root.clientsPending) return
      root.clientsPending = false
      running = true
    }
  }

  Process {
    id: ungroupProcess
    environment: ({ SAVE_THEM_ALL_LANG: root.lang })
    onExited: {
      root.refreshClients()
      flipConnection.check()
    }
  }

  Timer { id: clientsRefresh; interval: 150; onTriggered: root.refreshClients() }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!root.watching) return
      if (["openwindow", "closewindow", "movewindowv2", "windowtitlev2", "changefloatingmode",
           "fullscreen", "workspacev2"].indexOf(event.name) >= 0)
        clientsRefresh.restart()
    }
  }

  // The shell loads this service when the session starts, which makes it the
  // place to bring marked layouts back. The script decides whether this is the
  // first start of the session; it runs detached so a shell reload halfway
  // through does not stop it.
  Component.onCompleted: Quickshell.execDetached([binDir + "/restore-them-all-at-login"])
}
