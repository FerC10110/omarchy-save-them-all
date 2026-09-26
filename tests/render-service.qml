import QtQuick
import Quickshell
import Quickshell.Io
import "SaveThemAll" as SaveThemAll

// The real Service.qml, with its real Hyprflip.qml, offscreen: the fake
// helper tests/render-helper.py stands in for Hyprflip's control.py, a stub
// bin/cards for the plugin's own, tests/fakes/hyprctl for Hyprland, and two
// fake panels for the bar's panel on two monitors. It runs the scenarios
// below in order (they share the service, as a session would) and logs what
// each one saw:
//   SERVICE_RESULT <name> <json>
// then SERVICE_DONE. tests/test_render.py checks them.
ShellRoot {
  id: harness
  readonly property string dir: Quickshell.env("RENDER_HELPER_DIR")
  readonly property string stateDir: Quickshell.env("SAVE_THEM_ALL_STATE")
  readonly property var flip: service.flip

  QtObject {
    id: fakeShell
    property bool accepts: true
    function summon(id, payload) { return accepts }
    function hide(id) {}
  }

  component FakePanel: QtObject {
    property bool opened: false
    property int dismissed: 0
    property int revealed: 0
    property string page: ""
    function dismiss() { dismissed++; opened = false }
    function reveal() { revealed++; opened = true }
    function openPage(name) { page = name }
    function openHome() { page = "cards" }
  }
  FakePanel { id: panelA }
  FakePanel { id: panelB }

  SaveThemAll.Service {
    id: service
    shell: fakeShell
    manifest: ({ id: "io.github.ferc10110.save-them-all" })
  }

  property int pickChanges: 0
  property var languages: []
  Connections {
    target: service
    function onPickDraftChanged() { harness.pickChanges++ }
    function onLanguageSettingChanged() { harness.languages = harness.languages.concat([service.languageSetting]) }
  }

  function card(id) { return (flip.snapshot.cards || []).find(function(c) { return c.id === id }) || null }
  function lines(text) { return String(text || "").split("\n").filter(function(l) { return l !== "" }) }
  function view(extra) {
    return Object.assign({ busy: flip.busy, failed: flip.failed, notice: flip.notice }, extra || {})
  }

  // Each scenario: a name and its steps, one of
  //   { run: fn(c) }              do something now
  //   { until: fn(c), ms }        wait until fn(c) is true (or ms pass)
  //   { sleep: ms }
  //   { sh: "script" }            run it in RENDER_HELPER_DIR, wait for it
  //   { read: "file", into: k }   c[k] = the file's text ("" if missing)
  //   { log: fn(c) }              SERVICE_RESULT <scenario> <json of fn(c)>
  // c is the scenario's own scratch object.
  readonly property var scenarios: [
    { name: "settle", steps: [
      { run: function(c) { panelA.opened = true; service.attach(panelA) } },
      { until: function(c) { return flip.settled && flip.available }, ms: 10000 },
      { log: function(c) { return { settled: flip.settled, available: flip.available, cards: flip.snapshot.cards.length } } },
    ] },

    // startPick / pickToggle / finishPick, end to end (Task 16).
    { name: "pick", steps: [
      { run: function(c) {
        service.startBuilder(null)
        service.place("0x1", 0, -1)
        service.place("0x2", 1, -1)
        service.builderNotice = "before"
        fakeShell.accepts = false
        c.revealed = panelA.revealed
        service.startPick()
        c.refused = { picking: service.picking, builderNotice: service.builderNotice,
                      revealed: panelA.revealed - c.revealed, opened: panelA.opened }
        fakeShell.accepts = true
        panelA.opened = true
        service.builderNotice = "before"
        c.dismissed = panelA.dismissed
        service.startPick()
        c.started = { picking: service.picking, builderNotice: service.builderNotice,
                      dismissed: panelA.dismissed - c.dismissed, faces: service.pickDraft.faces }
        service.pickToggle("0x3")
        service.pickFace = 1
        service.pickToggle("0x4")
        service.pickToggle("0x2")
        c.revealed = panelA.revealed
        service.finishPick(true)
        c.applied = { picking: service.picking, faces: service.draft.faces, builderNotice: service.builderNotice,
                      revealed: panelA.revealed - c.revealed }
        service.builderNotice = "kept"
        service.startPick()
        service.pickToggle("0x5")
        service.finishPick(false)
        c.cancelled = { picking: service.picking, faces: service.draft.faces, builderNotice: service.builderNotice }
        service.cancelBuilder()
      } },
      { log: function(c) { return { refused: c.refused, started: c.started, applied: c.applied, cancelled: c.cancelled } } },
    ] },

    // A client refresh that closes nothing leaves the pick's draft alone.
    { name: "prune-quiet", steps: [
      { run: function(c) {
        service.startBuilder(null)
        service.place("0x1", 0, -1)
        service.place("0x2", 1, -1)
        service.startPick()
        harness.pickChanges = 0
        service.refreshClients()
      } },
      { sleep: 500 },
      { run: function(c) { service.refreshClients() } },
      { sleep: 500 },
      { log: function(c) { return { picking: service.picking, changes: harness.pickChanges } } },
      { run: function(c) { service.finishPick(false); service.cancelBuilder() } },
    ] },

    // Two monitors, a panel on each: a handoff lets go of both.
    { name: "multi-panel", steps: [
      { sh: "printf done > run-mode" },
      { run: function(c) {
        panelA.opened = true
        service.attach(panelA)
        panelB.opened = true
        service.attach(panelB)
        c.a = panelA.dismissed
        c.b = panelB.dismissed
        c.br = panelB.revealed
        c.started = service.setOption("duration", { duration_ms: 420 })
      } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { log: function(c) {
        return { started: c.started, aDismissed: panelA.dismissed - c.a, bDismissed: panelB.dismissed - c.b,
                 bRevealed: panelB.revealed - c.br, aOpened: panelA.opened, bOpened: panelB.opened }
      } },
      { run: function(c) { panelA.opened = true; service.attach(panelA) } },
    ] },

    // The helper speaks Spanish; the panel in English says it in English.
    { name: "english", steps: [
      { run: function(c) { service.setLanguage("en") } },
      { until: function(c) { return service.lang === "en" }, ms: 3000 },
      { sh: "printf 'error:Espera a que termine el giro e inténtalo de nuevo.' > run-mode" },
      { run: function(c) { flip.run("transition", { mode: "flip" }, {}) } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.error = view() } },
      { sh: "printf 'say:Algo que el asistente dice ahora.' > run-mode" },
      { run: function(c) { flip.run("transition", { mode: "flip" }, {}) } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.unknown = view() } },
      { sh: "printf done > run-mode" },
      { run: function(c) { service.setLanguage("es") } },
      { until: function(c) { return service.lang === "es" }, ms: 3000 },
      { run: function(c) { flip.run("transition", { mode: "flip" }, {}) } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.spanish = view() } },
      { run: function(c) { service.setLanguage("en") } },
      { until: function(c) { return service.lang === "en" }, ms: 3000 },
      { log: function(c) { return { error: c.error, unknown: c.unknown, spanish: c.spanish } } },
    ] },

    // A helper that never answers is stopped; the panel is usable again.
    { name: "watchdog-operation", steps: [
      { sh: "printf hang > run-mode" },
      { run: function(c) {
        flip.operationTimeout = 700
        c.t0 = Date.now()
        c.started = flip.run("transition", { mode: "flip" }, {})
      } },
      { until: function(c) { return !flip.busy }, ms: 6000 },
      { run: function(c) { c.stopped = view({ seconds: (Date.now() - c.t0) / 1000 }) } },
      { sh: "printf done > run-mode" },
      { until: function(c) { return flip.run("transition", { mode: "flip" }, {}) }, ms: 10000 },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.after = view(); flip.operationTimeout = 30000 } },
      { log: function(c) { return { started: c.started, stopped: c.stopped, after: c.after } } },
    ] },

    { name: "watchdog-snapshot", steps: [
      { sh: "touch snapshot-hang" },
      { run: function(c) {
        flip.snapshotTimeout = 700
        c.t0 = Date.now()
        c.started = flip.run("transition", { mode: "flip" }, {})
      } },
      { until: function(c) { return !flip.busy }, ms: 6000 },
      { run: function(c) { c.stopped = view({ seconds: (Date.now() - c.t0) / 1000 }) } },
      { sh: "rm -f snapshot-hang" },
      { run: function(c) { flip.snapshotTimeout = 15000 } },
      { until: function(c) { return flip.run("transition", { mode: "flip" }, {}) }, ms: 10000 },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.after = view({ available: flip.available }) } },
      { log: function(c) { return { started: c.started, stopped: c.stopped, after: c.after } } },
    ] },

    // The helper cannot even start: busy ends at once, not at the watchdog.
    // Here the snapshot's own python is missing (a command is read when the
    // process spawns, just after run() returns)...
    { name: "spawn-failure", steps: [
      { run: function(c) {
        c.t0 = Date.now()
        c.started = flip.run("transition", { mode: "flip" }, {})
        flip.python = "/nonexistent/python3"
      } },
      { until: function(c) { return !flip.busy }, ms: 5000 },
      { run: function(c) { c.stopped = view({ seconds: (Date.now() - c.t0) / 1000 }); flip.python = "python3" } },
      { sleep: 300 },
      { until: function(c) { return flip.run("transition", { mode: "flip" }, {}) }, ms: 10000 },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.after = view() } },
      { log: function(c) { return { started: c.started, stopped: c.stopped, after: c.after } } },
    ] },

    // ...and here the run's: the snapshot started with a good one.
    { name: "spawn-failure-run", steps: [
      { sh: "touch snapshot-slow" },
      { run: function(c) {
        c.t0 = Date.now()
        c.started = flip.run("transition", { mode: "flip" }, {})
      } },
      { sleep: 200 },
      { run: function(c) { flip.python = "/nonexistent/python3" } },
      { until: function(c) { return !flip.busy }, ms: 5000 },
      { run: function(c) { c.stopped = view({ seconds: (Date.now() - c.t0) / 1000 }); flip.python = "python3" } },
      { sh: "rm -f snapshot-slow" },
      { log: function(c) { return { started: c.started, stopped: c.stopped } } },
    ] },

    // The helper dies with an error on stderr: it lands in the log whole.
    { name: "crash", steps: [
      { sh: "printf crash > run-mode" },
      { run: function(c) { flip.run("transition", { mode: "flip" }, {}) } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { sleep: 300 },
      { run: function(c) { c.stopped = view() } },
      { sh: "printf done > run-mode" },
      { log: function(c) { return { stopped: c.stopped } } },
    ] },
  ]

  property int scenario: -1
  property int step: 0
  property var scratch: ({})
  property var waiting: null        // { until, deadline } or null
  property bool started: false

  property double scenarioDeadline: 0

  function next() {
    step++
    var list = scenario >= 0 ? scenarios[scenario].steps : []
    if (scenario < 0 || step >= list.length) return nextScenario()
    return true
  }

  function nextScenario() {
    scenario++
    step = 0
    scratch = {}
    waiting = null
    scenarioDeadline = Date.now() + 30000
    if (scenario >= scenarios.length) {
      console.log("SERVICE_DONE")
      Qt.quit()
      return false
    }
    return true
  }

  // Runs steps until one has to wait (a condition, a sleep, a process). A
  // step that throws, or a scenario past 30 s, is reported and skipped, so
  // one broken scenario cannot hold up the others.
  function pump() {
    while (true) {
      if (Date.now() > scenarioDeadline) {
        console.log("SERVICE_STUCK " + scenarios[scenario].name + " at step " + step)
        if (!nextScenario()) return
        continue
      }
      try {
        if (!pumpOne()) return
      } catch (e) {
        console.log("SERVICE_STEP_FAILED " + scenarios[scenario].name + " at step " + step + ": " + e)
        if (!nextScenario()) return
      }
    }
  }

  // One step, or none while waiting. -> whether to go on at once.
  function pumpOne() {
    {
      if (waiting) {
        if (!waiting.until(scratch) && Date.now() < waiting.deadline) return false
        waiting = null
        return next()
      }
      if (runner.running || reader.running) return false
      var s = scenarios[scenario].steps[step]
      var c = scratch
      if (s.run) s.run(c)
      else if (s.until) { waiting = { until: s.until, deadline: Date.now() + (s.ms || 5000) }; return true }
      else if (s.sleep) { waiting = { until: function() { return false }, deadline: Date.now() + s.sleep }; return true }
      else if (s.sh) { runner.command = ["sh", "-c", s.sh]; runner.running = true; next(); return false }
      else if (s.read) {
        reader.into = s.into
        reader.command = ["sh", "-c", 'cat "$1" 2>/dev/null; true', "sh", s.read]
        reader.running = true
        next()
        return false
      }
      else if (s.log) console.log("SERVICE_RESULT " + scenarios[scenario].name + " " + JSON.stringify(s.log(c)))
      return next()
    }
  }

  Process { id: runner; workingDirectory: harness.dir }
  Process {
    id: reader
    property string into: ""
    workingDirectory: harness.dir
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: harness.scratch[reader.into] = text }
  }

  Timer {
    interval: 30
    running: true
    repeat: true
    onTriggered: {
      if (!harness.started) { harness.started = true; harness.nextScenario() }
      harness.pump()
    }
  }
}
