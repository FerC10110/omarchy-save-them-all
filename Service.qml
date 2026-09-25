import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "I18n.js" as I18n
import "AppNames.js" as AppNames
import "Builder.js" as Builder
import "Protocol.js" as Protocol
import "CardsModel.js" as CardsModel

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
  property string cardsNotice: ""   // what bin/cards last said about an action outside a card (e.g. ungroup)
  readonly property var byAddress: {
    var out = {}
    clients.forEach(function(c) { out[c.address] = c })
    return out
  }
  readonly property var entries: DesktopEntries.applications.values.map(function(e) {
    return { id: e.id, name: e.name, icon: e.icon, startupClass: e.startupClass, exec: e.execString }
  })
  readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  readonly property bool watching: (panel !== null && panel.opened === true) || draft !== null
  readonly property var flip: flipConnection
  readonly property bool thumbnails: true
  property var draft: null          // the card builder's, kept while the panel closes
  property string builderNotice: ""
  property var namedFaces: null     // a card just made, waiting for its name
  property string pendingName: ""

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
    cardsNotice = ""
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

  // -- the card builder --------------------------------------------------

  function startBuilder(card) {
    builderNotice = ""
    if (card) {
      var shown = byAddress[card.current]
      var rect = card.floating && shown ? { at: shown.at, size: shown.size } : null
      draft = Builder.editDraft(card, names[String(card.id)] || "", rect)
    } else {
      draft = Builder.newDraft(focusedWorkspace)
    }
    refreshClients()
    Hyprland.refreshToplevels()
    if (panel) panel.openPage("builder")
  }

  function moveCursor(address) {
    if (draft) draft = Object.assign({}, draft, { cursor: address })
  }

  function place(address, face, index) {
    if (!draft) return
    var r = Builder.place(draft, address, face, index, t)
    draft = r.draft
    builderNotice = r.problem
  }

  function removeFromDraft(address) {
    if (!draft) return
    draft = Builder.remove(draft, address)
    builderNotice = ""
  }

  function setAxis(face, axis) {
    if (draft) draft = Builder.setAxis(draft, face, axis)
  }

  function setDraftName(name) {
    if (draft) draft = Object.assign({}, draft, { name: String(name || "") })
  }

  function cancelBuilder() {
    draft = null
    builderNotice = ""
    if (panel) panel.openHome()
  }

  // An action on a card the panel showed: Hyprflip acts on the cards of the
  // active workspace, so it goes there first.
  function cardAction(action, card) {
    if (!card) return
    cardsNotice = ""
    var started = flipConnection.run(action, {}, { card: CardsModel.reference(card), workspace: card.workspace, reopen: true })
    if (!started) cardsNotice = t("Hyprflip is busy; try again in a moment.")
  }

  // One of Hyprflip's preferences (appearance, spacing, transition,
  // duration, shortcut): they apply to every card.
  function setOption(action, extra) {
    cardsNotice = ""
    flipConnection.run(action, extra, { reopen: true })
  }

  function submitDraft() {
    if (!draft) return
    if (!Builder.ready(draft)) { builderNotice = t("Put at least one window on each side."); return }
    if (flipConnection.busy) { builderNotice = t("Hyprflip is busy; try again in a moment."); return }
    if (!flipConnection.canCreate) { builderNotice = flipConnection.unavailableText || t("The card could not be made."); return }
    builderNotice = ""
    var started = flipConnection.run("create", Builder.request(draft), {
      workspace: draft.workspace, replace: draft.mode === "edit" ? draft.card : null, reopen: true })
    if (!started) builderNotice = t("Hyprflip is busy; try again in a moment.")
  }

  // A window of the draft closed: it leaves the card, the rest stays.
  function pruneDraft(before) {
    if (!draft) return
    var r = Builder.prune(draft, clients)
    if (r.gone.length === 0) return
    draft = r.draft
    builderNotice = t("%1 closed and left the card.", [r.gone.map(function(a) {
      return before[a] ? appName(before[a]) : a
    }).join(", ")])
  }

  function flipFinished(action, ok, message, pending) {
    var reopen = pending && pending.options && pending.options.reopen
    var ws = flipConnection.sent && flipConnection.sent.context ? flipConnection.sent.context.workspace : 0
    if (reopen && panel && (!ws || ws === focusedWorkspace)) panel.reveal()
    if (action === "create" && draft) {
      if (ok) {
        cardsNotice = draft.mode === "edit" ? t("Changes saved.") : t("Card created.")
        namedFaces = draft.faces
        pendingName = draft.name
        draft = null
        builderNotice = ""
        if (panel) panel.openHome()
      } else {
        builderNotice = message || t("The card could not be made.")
      }
    }
    if (action === "unpair" && ok) cardsNotice = t("Card taken apart; its windows stay open.")
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

  // A new card gets its name once Hyprflip lists it.
  Connections {
    target: flipConnection
    function onSnapshotChanged() {
      if (!root.namedFaces) return
      var made = (flipConnection.snapshot.cards || []).find(function(c) {
        return Protocol.sameFaces(Protocol.faceAddresses(c), root.namedFaces)
      })
      if (!made) return
      root.setName(made.id, root.pendingName)
      root.namedFaces = null
    }
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
        // An unparseable or non-array reply is a glitch, not "every window
        // closed": leave root.clients as it was and skip pruning, or an
        // open draft would lose every window it holds over a bad reply.
        var list
        try {
          list = JSON.parse(String(text || "[]"))
        } catch (e) {
          return
        }
        if (!Array.isArray(list)) return
        var before = root.byAddress
        root.clients = list.filter(function(c) { return c && c.address })
        // A genuinely empty list is itself suspect for pruning purposes
        // (a transient hyprctl race, e.g. mid workspace switch): only
        // prune when it can actually tell an open from a closed window.
        if (root.clients.length > 0) root.pruneDraft(before)
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
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.cardsNotice = message.split("\n").pop().replace(/^cards: /, "")
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.cardsNotice = ""
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
