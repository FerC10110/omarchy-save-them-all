import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "Protocol.js" as Protocol
import "HelperText.js" as HelperText

// The connection to Hyprflip, after OmaCards' Service.qml (MIT, see NOTICE).
// `bin/cards status` says whether cards can be used and, if not, why; the
// helper's `snapshot` lists the cards and `run` changes them. The helper owns
// every window change: this only asks, resumes its focus handoffs, refuses
// its questions (a panel action never has one) and reports how it ended.
Scope {
  id: root

  // Set by Service.qml.
  property var t: function(text, args) { return text }
  property string binDir: ""
  property string lang: "en"
  property var owner: null          // the panel: closed for a handoff
  property bool watching: false     // refresh on Hyprland events only while someone looks

  readonly property string helper: Quickshell.env("SAVE_THEM_ALL_HYPRFLIP_HELPER")
    || (Quickshell.env("HOME") + "/.local/lib/hyprflip/control.py")

  property var status: ({ available: false, reason: "", fix: "", detail: "", hyprland: "", built_for: "", hyprflip: "" })
  property var snapshot: Protocol.emptySnapshot()
  property string snapshotProblem: ""
  // A real answer has replaced the placeholders above: the status came
  // back, and, once it says Hyprflip is available, so did a first snapshot.
  property bool statusChecked: false
  property bool snapshotChecked: false
  readonly property bool available: status.available === true && snapshot.available === true && snapshotProblem === ""
  // Whether "available" is actually known yet, not still a guess from the
  // placeholders: nothing that reads Hyprflip as absent should say so before
  // this is true, or it is reporting on data that has not arrived.
  readonly property bool settled: statusChecked && (status.available !== true || snapshotChecked)
  readonly property bool canCreate: Protocol.canCreate(available, snapshot)
  readonly property bool canUnpair: available && snapshot.capabilities.unpair === true
  readonly property string unavailableText: Protocol.whyUnavailable(status, snapshot, snapshotProblem, t, say)

  // A message the helper wrote (in Spanish only), in the panel's language.
  function say(message) { return HelperText.forLang(message, lang) }

  property string notice: ""
  property bool failed: false
  property var pending: null        // { action, extra, options } until the helper exits
  property var sent: null
  property bool completed: false
  property bool refused: false
  // A snapshot was already in flight (an unrelated refresh) when run() was
  // called: that answer is about a moment before the click, so accept()
  // throws it away and asks again instead of resolving the action against it.
  property bool rerun: false
  readonly property bool busy: pending !== null
  readonly property bool checking: statusProcess.running

  signal finished(string action, bool ok, string message, var pending)

  // Ask again whether Hyprflip can be used; then list its cards.
  function check() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function refresh() {
    if (busy || snapshotProcess.running || status.available !== true) return
    snapshotProcess.running = true
  }

  // action: a helper action; extra: its fields; options:
  //   workspace  go there first (Hyprflip acts on the cards of the active workspace)
  //   card       {kind, id, faces}: the card acted on, checked against a fresh snapshot
  //   replace    the same, for a create that rebuilds a card
  //   reopen     the caller wants the panel back when it ends
  function run(action, extra, options) {
    if (busy || !available) return false
    pending = { action: action, extra: extra || {}, options: options || {} }
    notice = ""
    failed = false
    completed = false
    refused = false
    sent = null
    // snapshotProcess may already be answering an unrelated refresh (from
    // attach()/check() or an event); setting `running` again would be a
    // no-op, so that stale answer would otherwise land in accept() as if it
    // were fresh. Let it finish, then ask again once it is out of the way.
    rerun = snapshotProcess.running
    var ws = pending.options.workspace
    var here = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 0
    if (ws && ws !== here) {
      switchProcess.command = ["hyprctl", "dispatch", "hl.dsp.focus({ workspace = '" + Number(ws) + "' })"]
      switchProcess.running = true
    } else if (!rerun) {
      snapshotProcess.running = true
    }
    return true
  }

  function fail(text) {
    var p = pending
    pending = null
    failed = true
    notice = text
    root.finished(p ? p.action : "", false, text, p)
  }

  // The fresh target of a card the panel showed, or null if it changed.
  function resolve(ref) {
    var fresh = (snapshot.cards || []).find(function(c) { return c.kind === ref.kind && c.id === ref.id }) || null
    if (!fresh || !Protocol.sameFaces(Protocol.faceAddresses(fresh), ref.faces)) return null
    return Protocol.cardTarget(fresh)
  }

  function accept(text) {
    if (rerun) {
      // Discard the stale snapshot this reply carries; ask again once any
      // workspace switch in flight is done (switchProcess.onExited asks if
      // this does not need to), so the action sees a snapshot taken after
      // the click, not before it.
      rerun = false
      if (pending && !switchProcess.running) snapshotProcess.running = true
      return
    }
    var parsed = Protocol.parseSnapshot(text)
    snapshot = parsed.snapshot
    snapshotProblem = parsed.problem
    snapshotChecked = true
    if (!pending) return
    if (!available) { fail(unavailableText); return }
    var o = pending.options
    if (o.workspace && (!snapshot.context || snapshot.context.workspace !== o.workspace)) {
      fail(t("Could not switch to workspace %1.", [o.workspace]))
      return
    }
    var extra = Object.assign({}, pending.extra)
    if (o.card) {
      extra.target = resolve(o.card)
      if (!extra.target) { fail(t("That card changed; look at it again.")); return }
    }
    if (o.replace) {
      extra.replace = resolve(o.replace)
      if (!extra.replace) { fail(t("That card changed; look at it again.")); return }
    }
    sent = Protocol.request(pending.action, snapshot.context, extra)
    operationProcess.command = ["python3", helper, "run", "--request", JSON.stringify(sent)]
    operationProcess.running = true
  }

  function write(value) {
    operationProcess.write(JSON.stringify(value) + "\n")
  }

  function receive(line) {
    var r = Protocol.receive(line)
    if (r.kind === "blank" || r.kind === "opening") return
    if (r.kind === "handoff") {
      // The panel holds a keyboard grab; the helper waits until it is gone.
      if (owner) owner.dismiss()
      Qt.callLater(function() { if (operationProcess.running && !root.refused) root.write({ resume: r.id }) })
    } else if (r.kind === "question" || r.kind === "unreadable") {
      refused = true
      failed = true
      notice = r.kind === "question"
        ? t("Hyprflip asked something this panel cannot answer; the action was cancelled.")
        : t("The Hyprflip helper sent an unreadable answer.")
      root.write({ cancel: true })
      cancelTimer.restart()
    } else {
      completed = true
      if (!refused) {
        notice = say(r.message)
        failed = r.kind === "error"
      }
    }
  }

  Process {
    id: statusProcess
    command: [root.binDir + "/cards", "status"]
    environment: ({ SAVE_THEM_ALL_LANG: root.lang })
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var s = JSON.parse(String(text || ""))
          root.status = s && typeof s === "object" ? s : { available: false, reason: "helper", detail: "" }
        } catch (e) {
          root.status = { available: false, reason: "helper", detail: String(text || "").trim().slice(0, 200) }
        }
        root.statusChecked = true
        if (root.status.available === true) root.refresh()
      }
    }
  }

  Process {
    id: snapshotProcess
    command: ["python3", root.helper, "snapshot"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.accept(text)
    }
  }

  Process {
    id: switchProcess
    onExited: if (root.pending) snapshotProcess.running = true
  }

  Process {
    id: operationProcess
    stdinEnabled: true
    stdout: SplitParser { onRead: function(data) { root.receive(data) } }
    stderr: StdioCollector { id: operationErrors; waitForEnd: true }
    onExited: function(exitCode) {
      cancelTimer.stop()
      var p = root.pending
      root.pending = null
      if (!root.completed && !root.refused) {
        root.failed = true
        root.notice = root.t("The Hyprflip helper stopped. Try again.")
        console.warn("[save-them-all] helper exit " + exitCode + ": " + operationErrors.text.slice(0, 2000))
      }
      root.finished(p ? p.action : "", !root.failed, root.notice, p)
      Qt.callLater(root.refresh)
    }
  }

  // A helper that ignores the cancel is stopped; it is our own child process.
  Timer {
    id: cancelTimer
    interval: 9000
    onTriggered: if (operationProcess.running) operationProcess.signal(15)
  }

  Timer { id: eventRefresh; interval: 180; onTriggered: root.refresh() }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded") { root.check(); return }
      if (!root.watching || root.busy) return
      if (["openwindow", "closewindow", "movewindowv2", "workspacev2", "changefloatingmode"].indexOf(event.name) >= 0)
        eventRefresh.restart()
    }
  }

  Component.onDestruction: {
    if (operationProcess.running) {
      root.write({ cancel: true })
      operationProcess.signal(15)
    }
  }
}
