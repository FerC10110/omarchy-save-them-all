import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "I18n.js" as I18n
import "AppNames.js" as AppNames
import "Builder.js" as Builder
import "Pick.js" as Pick
import "CardsModel.js" as CardsModel
import "HelperText.js" as HelperText

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
  property var panels: []           // every bar panel that opened (one per monitor)
  property var clients: []
  property var names: ({})
  // Each page's own word on how its last action went: a card action's on
  // the Cards tab; a preference's on Settings, or Shortcuts for a shortcut.
  property string cardsNotice: ""
  property bool cardsFailed: false
  property string optionNotice: ""
  property bool optionFailed: false
  property string optionAction: ""  // which preference it was about
  property string ungroupNotice: "" // how "Show both faces" went (Workspace tab)
  property bool ungroupFailed: false
  property var ungroupCode: null    // its exit code and last stderr line, read in either order
  property var ungroupError: null
  readonly property var byAddress: {
    var out = {}
    clients.forEach(function(c) { out[c.address] = c })
    return out
  }
  readonly property var entries: DesktopEntries.applications.values.map(function(e) {
    return { id: e.id, name: e.name, icon: e.icon, startupClass: e.startupClass, exec: e.execString }
  })
  readonly property int focusedWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
  // Keep windows and cards fresh (event refreshes, live thumbnails) only
  // while someone looks: a panel is open, the pick overlay is up, or the
  // builder's card is being made. A draft left behind in a closed panel does
  // not count; attach() refreshes everything when the panel opens again.
  readonly property bool panelOpen: panels.some(function(p) { return !!p && p.opened === true })
  readonly property bool watching: panelOpen || pickDraft !== null || (draft !== null && flipConnection.busy)
  readonly property var flip: flipConnection
  // The builder's window pictures refresh every few seconds: only while a
  // panel shows them.
  readonly property bool thumbnails: panelOpen
  property var draft: null          // the card builder's, kept while the panel closes
  property string builderNotice: ""
  // A card just made, waiting for its name: { faces, name, until }. It
  // applies once, to the card that create made, and only for nameTimeout
  // ms: a card with the same windows later on was made some other way.
  property var pendingName: null
  property int nameTimeout: 15000
  property var pickDraft: null      // the overlay's copy of the draft
  property int pickFace: 0
  property string pickNotice: ""    // builderNotice from before the pick, restored on Esc
  readonly property bool picking: pickDraft !== null

  function pluginPath(relative) {
    var url = String(Qt.resolvedUrl(relative))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.substring(7)) : url
  }

  function t(text, args) { return I18n.t(text, lang, args) }
  function appName(win) { return AppNames.resolve(win, entries).name }
  function appIcon(win) { return AppNames.resolve(win, entries).icon }

  // The panel calls this when it opens: the one to show again after an
  // action. Every panel that opened is kept too, for dismiss().
  function attach(p) {
    panel = p
    if (panels.indexOf(p) < 0) panels = panels.filter(function(x) { return !!x }).concat([p])
    flipConnection.check()
    refreshClients()
  }

  // Hyprflip's handoff: the helper waits until no panel holds the keyboard,
  // so every open one closes, on any monitor, not only the last one shown.
  function dismiss() {
    panels.forEach(function(p) { if (p && p.opened) p.dismiss() })
  }

  function setLanguage(value) {
    settingsData = Object.assign({}, settingsData, { language: value })
    writeSettings()
  }

  // One write at a time, the latest settings last: a pick made while a
  // write runs waits for it (setting `running` again would only queue a
  // restart of the old command), and the file watcher ignores what lands
  // meanwhile, or an older pick would come back for a moment.
  property bool settingsQueued: false
  function writeSettings() {
    if (settingsWrite.running) { settingsQueued = true; return }
    settingsQueued = false
    settingsWrite.command = ["sh", "-c",
      'mkdir -p "$1" && printf "%s\\n" "$2" >"$1/.settings.tmp" && mv "$1/.settings.tmp" "$1/settings.json"',
      "sh", stateDir, JSON.stringify(settingsData)]
    settingsWrite.running = true
  }

  function setName(id, name) {
    Quickshell.execDetached([binDir + "/cards", "name", "--id", String(id), "--name", String(name || "")])
  }

  // "Show both faces": let go of every native group on the workspace.
  function ungroup(workspace) {
    if (ungroupProcess.running) return
    ungroupNotice = ""
    ungroupFailed = false
    ungroupCode = null
    ungroupError = null
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
  // Why an action cannot start now.
  function busyText() {
    return flipConnection.stopping ? t("Hyprflip is still stopping the last action; try again in a moment.")
                                   : t("Hyprflip is busy; try again in a moment.")
  }

  function cardAction(action, card) {
    if (!card) return
    cardsNotice = ""
    cardsFailed = false
    var started = flipConnection.run(action, {}, { card: CardsModel.reference(card), workspace: card.workspace, reopen: true,
                                                   from: panel })
    if (!started) {
      cardsNotice = busyText()
      cardsFailed = true
    }
  }

  // One of Hyprflip's preferences (appearance, spacing, transition,
  // duration, shortcut): they apply to every card. -> whether it was sent.
  readonly property var optionActions: ["appearance", "spacing", "transition", "duration", "shortcut"]
  function setOption(action, extra) {
    optionAction = action
    optionNotice = ""
    optionFailed = false
    var started = flipConnection.run(action, extra, { reopen: true, from: panel })
    if (!started) {
      optionNotice = busyText()
      optionFailed = true
    }
    return started
  }

  // -- pick on screen -----------------------------------------------------

  function startPick() {
    if (!draft || !shell) return
    pickDraft = draft
    pickFace = 0
    pickNotice = builderNotice
    builderNotice = ""
    refreshClients()
    if (panel) panel.dismiss()
    if (!shell.summon(pluginId, "{}")) {
      // No overlay came up (the summon itself was refused): the panel is
      // already dismissed, so bring it back and say why instead of leaving
      // the builder gone with nothing on screen.
      pickDraft = null
      builderNotice = t("Could not open pick on screen.")
      if (panel) panel.reveal()
    }
  }

  function pickToggle(address) {
    if (!pickDraft) return
    var r = Pick.toggle(pickDraft, address, pickFace, t)
    pickDraft = r.draft
    builderNotice = r.problem
  }

  function finishPick(apply) {
    if (!pickDraft) return
    if (apply) {
      // Prune against the live client list, not whatever pruneDraft() last
      // caught: a window can close between its last run and Enter, and
      // applying a stale pickDraft would resurrect it in the card.
      draft = Builder.prune(pickDraft, clients).draft
      builderNotice = ""
    } else {
      builderNotice = pickNotice
    }
    pickDraft = null
    if (shell) shell.hide(pluginId)
    if (panel) panel.reveal()
  }

  function submitDraft() {
    if (!draft) return
    // Only the name changed: rename the card; rebuilding it would reset its
    // layout for nothing.
    if (Builder.nameOnly(draft)) {
      // The card must still be there, as it was: a create would check the
      // same against a fresh snapshot.
      if (!flipConnection.resolve(draft.card)) { builderNotice = t("That card changed; look at it again."); return }
      setName(draft.card.id, draft.name)
      cardsNotice = t("Changes saved.")
      cardsFailed = false
      draft = null
      builderNotice = ""
      if (panel) panel.openHome()
      return
    }
    if (!Builder.ready(draft)) { builderNotice = t("Put at least one window on each side."); return }
    if (flipConnection.busy) { builderNotice = busyText(); return }
    if (!flipConnection.canCreate) { builderNotice = flipConnection.unavailableText || t("The card could not be made."); return }
    builderNotice = ""
    pendingName = null
    var started = flipConnection.run("create", Builder.request(draft), {
      workspace: draft.workspace, replace: draft.mode === "edit" ? draft.card : null, reopen: true, from: panel })
    if (!started) builderNotice = busyText()
  }

  // A window of the draft closed: it leaves the card, the rest stays.
  function pruneDraft(before) {
    // Only when a picked window closed: most refreshes close nothing.
    if (pickDraft) {
      var picked = Builder.prune(pickDraft, clients)
      if (picked.gone.length > 0) pickDraft = picked.draft
    }
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
    // The panel the action came from comes back, even if another opened since.
    var from = (pending && pending.options && pending.options.from) || panel
    var ws = flipConnection.sent && flipConnection.sent.context ? flipConnection.sent.context.workspace : 0
    if (reopen && from && (!ws || ws === focusedWorkspace)) from.reveal()
    if (optionActions.indexOf(action) >= 0) {
      // message: the helper's own (in the panel's language), or why it failed.
      optionAction = action
      optionNotice = message
      optionFailed = !ok
    } else if (action === "create" && draft) {
      if (ok) {
        cardsNotice = HelperText.unplaced(message) ? message
          : draft.mode === "edit" ? t("Changes saved.") : t("Card created.")
        cardsFailed = false
        pendingName = { faces: draft.faces, name: draft.name, until: Date.now() + nameTimeout }
        draft = null
        builderNotice = ""
        if (panel) panel.openHome()
      } else {
        builderNotice = message || t("The card could not be made.")
      }
    } else if (action !== "create" || !ok) {
      // flip, unfold, floating, unpair; or a create whose builder is gone.
      cardsFailed = !ok
      cardsNotice = ok && action === "unpair" && !HelperText.unplaced(message) ? t("Card taken apart; its windows stay open.") : message
    }
  }

  Hyprflip {
    id: flipConnection
    t: function(text, args) { return root.t(text, args) }
    binDir: root.binDir
    lang: root.lang
    owner: root
    watching: root.watching
    onFinished: function(action, ok, message, pending) { root.flipFinished(action, ok, message, pending) }
  }

  // A new card gets its name once Hyprflip lists it, if that is soon.
  Connections {
    target: flipConnection
    function onSnapshotChanged() {
      var waiting = root.pendingName
      if (!waiting) return
      if (Date.now() > waiting.until) { root.pendingName = null; return }
      var made = CardsModel.namedCard(flipConnection.snapshot.cards, waiting, Date.now())
      if (!made) return
      root.pendingName = null
      root.setName(made.id, waiting.name)
    }
  }

  FileView {
    path: root.stateDir + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      // Our own write landing: settingsData already holds it, or newer.
      if (settingsWrite.running || root.settingsQueued) return
      try {
        var data = JSON.parse(String(text() || "{}"))
        root.settingsData = data && typeof data === "object" && !Array.isArray(data) ? data : {}
      } catch (e) {
        root.settingsData = {}
      }
    }
  }

  Process {
    id: settingsWrite
    onExited: if (root.settingsQueued) root.writeSettings()
  }

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

  // Once both the exit code and stderr are in: a word when it worked, what
  // bin/cards said (already translated) when it did not.
  function ungroupDone() {
    if (ungroupCode === null || ungroupError === null) return
    ungroupFailed = ungroupCode !== 0
    ungroupNotice = !ungroupFailed ? t("Every window on this workspace is out of its group.")
      : ungroupError || t("Could not take the windows out of their groups.")
  }

  Process {
    id: ungroupProcess
    environment: ({ SAVE_THEM_ALL_LANG: root.lang })
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        root.ungroupError = message === "" ? "" : message.split("\n").pop().replace(/^cards: /, "")
        root.ungroupDone()
      }
    }
    onExited: function(exitCode) {
      root.ungroupCode = exitCode
      root.ungroupDone()
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
