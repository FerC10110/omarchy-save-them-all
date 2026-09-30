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

    // A draft alone (every panel closed, no pick, no action) watches nothing.
    { name: "watchers", steps: [
      { run: function(c) {
        panelA.opened = false
        panelB.opened = false
        service.startBuilder(null)
        c.closed = service.watching
        c.pictures = service.thumbnails
        panelA.opened = true
        c.open = service.watching
        panelA.opened = false
        service.startPick()
        c.picking = service.watching
        // Back from the pick, the builder shows in the panel again; closing
        // that panel with the draft still there stops watching too.
        service.finishPick(false)
        c.back = service.watching
        panelA.opened = false
        c.none = service.watching
        service.cancelBuilder()
      } },
      { log: function(c) { return { closed: c.closed, pictures: c.pictures, open: c.open, picking: c.picking, back: c.back, none: c.none } } },
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

    // Each page's own notice: a card action's on Cards, a preference's on
    // Settings (or Shortcuts, for a shortcut).
    { name: "notices", steps: [
      { sh: "printf 'error:La tarjeta cambió. Actualiza Tarjetas antes de editarla.' > run-mode" },
      { run: function(c) {
        c.before = { optionNotice: service.optionNotice, optionFailed: service.optionFailed }
        service.cardAction("flip", harness.card(1))
      } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) {
        c.card = { cardsNotice: service.cardsNotice, cardsFailed: service.cardsFailed,
                   optionUntouched: service.optionNotice === c.before.optionNotice
                     && service.optionFailed === c.before.optionFailed }
      } },
      { sh: "printf done > run-mode" },
      { run: function(c) { service.setOption("duration", { duration_ms: 420 }) } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) {
        c.option = { cardsNotice: service.cardsNotice, cardsFailed: service.cardsFailed, optionNotice: service.optionNotice,
                     optionFailed: service.optionFailed, optionAction: service.optionAction }
      } },
      { log: function(c) { return { card: c.card, option: c.option } } },
    ] },

    // A helper that never answers is stopped; the panel is usable again.
    { name: "watchdog-operation", steps: [
      { sh: "printf hang > run-mode" },
      { run: function(c) {
        flip.stopGrace = 300
        flip.killGrace = 300
        flip.operationTimeout = 700
        c.t0 = Date.now()
        c.started = flip.run("transition", { mode: "flip" }, {})
      } },
      { until: function(c) { return !flip.busy }, ms: 6000 },
      { run: function(c) { c.stopped = view({ seconds: (Date.now() - c.t0) / 1000 }) } },
      { sh: "printf done > run-mode" },
      { until: function(c) { return flip.run("transition", { mode: "flip" }, {}) }, ms: 10000 },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.after = view(); flip.operationTimeout = 30000; flip.stopGrace = 9000; flip.killGrace = 30000 } },
      { log: function(c) { return { started: c.started, stopped: c.stopped, after: c.after } } },
    ] },

    // The helper the watchdog stopped ends at once (as control.py does on
    // SIGTERM) and the action is tried again right away: nothing aimed at the
    // old helper may hit the new one, which runs on and ends well.
    { name: "watchdog-retry", steps: [
      { sh: "printf hang-until-term > run-mode" },
      { run: function(c) {
        flip.stopGrace = 300
        flip.killGrace = 1500
        flip.operationTimeout = 700
        c.started = flip.run("transition", { mode: "flip" }, {})
      } },
      { until: function(c) { return !flip.busy }, ms: 6000 },
      { run: function(c) { flip.operationTimeout = 30000 } },
      { sh: "printf slow:4 > run-mode" },
      { until: function(c) { c.t0 = Date.now(); return flip.run("transition", { mode: "flip" }, {}) }, ms: 10000 },
      { until: function(c) { return !flip.busy }, ms: 12000 },
      { run: function(c) {
        c.after = view({ seconds: (Date.now() - c.t0) / 1000 })
        flip.stopGrace = 9000
        flip.killGrace = 30000
      } },
      { sh: "printf done > run-mode" },
      { log: function(c) { return { started: c.started, after: c.after } } },
    ] },

    // The watchdog lets the helper wind down: {cancel} at once, SIGTERM
    // only a grace period later, SIGKILL only much later. Busy ends at once;
    // meanwhile a new action is refused with its own notice.
    { name: "watchdog-grace", steps: [
      { sh: "rm -f signals.log; printf hang-log > run-mode" },
      { run: function(c) {
        flip.stopGrace = 1000
        flip.killGrace = 1500
        flip.operationTimeout = 700
        service.cardAction("flip", harness.card(1))
      } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) {
        c.gaveUp = Date.now()
        c.stopping = flip.stopping
        service.setOption("transition", { mode: "flip" })
        c.refused = { optionNotice: service.optionNotice, optionFailed: service.optionFailed }
      } },
      { until: function(c) { return !flip.stopping }, ms: 10000 },
      { run: function(c) {
        c.gone = Date.now()
        flip.operationTimeout = 30000
        flip.stopGrace = 9000
        flip.killGrace = 30000
      } },
      { sh: "printf done > run-mode" },
      { read: "signals.log", into: "signals" },
      { log: function(c) {
        return { gaveUp: c.gaveUp, gone: c.gone, stopping: c.stopping, refused: c.refused,
                 signals: harness.lines(c.signals).map(function(l) { return JSON.parse(l) }) }
      } },
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

    // "Show both faces": a word when it worked, the script's error when not.
    { name: "ungroup", steps: [
      { run: function(c) { service.ungroup(3) } },
      { until: function(c) { return service.ungroupNotice !== "" }, ms: 3000 },
      { run: function(c) { c.ok = { notice: service.ungroupNotice, failed: service.ungroupFailed } } },
      { sh: "touch ungroup-fails" },
      { run: function(c) { service.ungroup(3) } },
      { until: function(c) { return service.ungroupFailed === true }, ms: 3000 },
      { run: function(c) { c.failed = { notice: service.ungroupNotice, failed: service.ungroupFailed } } },
      { sh: "rm -f ungroup-fails" },
      { log: function(c) { return { ok: c.ok, failed: c.failed } } },
    ] },

    // A new card gets the builder's name once, and only soon after.
    // A create or unpair that worked, but whose windows could not go back
    // where they were: the helper's warning is shown, not a plain success.
    { name: "unplaced", steps: [
      { sh: "printf 'say:Tarjeta creada, pero no se pudo colocar donde estaba. Muévela a mano.' > run-mode" },
      { run: function(c) {
        service.startBuilder(null)
        service.place("0x3", 0, -1)
        service.place("0x4", 1, -1)
        service.submitDraft()
      } },
      { until: function(c) { return !flip.busy && service.draft === null }, ms: 8000 },
      { run: function(c) { c.create = { notice: service.cardsNotice, failed: service.cardsFailed } } },
      { sh: "printf 'say:Tarjeta desarmada. Sus apps siguen abiertas, pero no se pudieron colocar donde estaban.' > run-mode" },
      { run: function(c) { service.cardAction("unpair", harness.card(1)) } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { run: function(c) { c.unpair = { notice: service.cardsNotice, failed: service.cardsFailed } } },
      { sh: "printf done > run-mode" },
      { log: function(c) { return { create: c.create, unpair: c.unpair } } },
    ] },

    { name: "names", steps: [
      { sh: "printf done > run-mode; : > names.log" },
      { run: function(c) {
        service.startBuilder(null)
        service.place("0x1", 0, -1)
        service.place("0x2", 1, -1)
        service.setDraftName("Work")
        service.submitDraft()
      } },
      { until: function(c) { return !flip.busy && service.draft === null }, ms: 8000 },
      { until: function(c) { return harness.card(2) !== null }, ms: 5000 },
      { sleep: 500 },
      { read: "names.log", into: "made" },
      { sh: "printf done-no-card > run-mode" },
      { run: function(c) {
        service.nameTimeout = 300
        service.startBuilder(null)
        service.place("0x3", 0, -1)
        service.place("0x4", 1, -1)
        service.setDraftName("Late")
        service.submitDraft()
      } },
      { until: function(c) { return !flip.busy && service.draft === null }, ms: 8000 },
      { sleep: 800 },
      // The same windows become a card much later, some other way.
      { sh: "python3 -c \"import json; c = json.load(open('cards.json')); " +
            "c.append({'id': 9, 'kind': 'container', 'key': 'container:9', 'token': 't9', 'current': '0x3', " +
            "'active': 0, 'unfolded': False, 'floating': False, 'workspace': 3, 'name': '', " +
            "'faces': [{'index': 0, 'axis': 'horizontal', 'panes': [{'address': '0x3', 'label': 'c'}]}, " +
            "{'index': 1, 'axis': 'horizontal', 'panes': [{'address': '0x4', 'label': 'd'}]}]}); " +
            "json.dump(c, open('cards.json', 'w'))\"; printf done > run-mode" },
      { run: function(c) { flip.refresh() } },
      { until: function(c) { return harness.card(9) !== null }, ms: 5000 },
      { sleep: 500 },
      { read: "names.log", into: "late" },
      { run: function(c) { service.nameTimeout = 15000 } },
      { log: function(c) { return { made: harness.lines(c.made), late: harness.lines(c.late), notice: service.cardsNotice } } },
    ] },

    // Editing only the name renames the card; nothing is rebuilt.
    { name: "name-only", steps: [
      { sh: ": > names.log" },
      { read: "requests.jsonl", into: "before" },
      { run: function(c) {
        service.startBuilder(harness.card(2))
        service.setDraftName("Renamed")
        c.editing = service.draft !== null
        service.submitDraft()
      } },
      { sleep: 800 },
      { read: "requests.jsonl", into: "after" },
      { read: "names.log", into: "names" },
      { log: function(c) {
        return { editing: c.editing, sent: harness.lines(c.after).length - harness.lines(c.before).length,
                 names: harness.lines(c.names), draft: service.draft, notice: service.cardsNotice,
                 page: panelA.page }
      } },
    ] },

    // ...unless the card was taken apart meanwhile: then it says so, as the
    // helper would, and renames nothing.
    { name: "name-only-gone", steps: [
      { sh: ": > names.log" },
      { run: function(c) {
        service.startBuilder(harness.card(2))
        c.editing = service.draft !== null
      } },
      { sh: "python3 -c \"import json; c = json.load(open('cards.json')); " +
            "json.dump([x for x in c if x['id'] != 2], open('cards.json', 'w'))\"" },
      { run: function(c) { flip.refresh() } },
      { until: function(c) { return harness.card(2) === null }, ms: 5000 },
      { run: function(c) {
        service.setDraftName("Gone")
        service.submitDraft()
      } },
      { sleep: 500 },
      { read: "names.log", into: "names" },
      { log: function(c) {
        return { editing: c.editing, names: harness.lines(c.names), open: service.draft !== null,
                 builderNotice: service.builderNotice }
      } },
      { run: function(c) { service.draft = null } },
    ] },

    // The panel an action came from is destroyed (its monitor unplugged)
    // before the action ends: nothing is revealed on it, and nothing throws.
    // The fake helper's workspace is 0 here, so reveal() would be called.
    { name: "panel-gone", steps: [
      { sh: "python3 -c \"import json, os; p = os.environ['FAKE_HYPR_STATE']; s = json.load(open(p)); " +
            "s['active_workspace'] = 0; json.dump(s, open(p, 'w'))\"" },
      { run: function(c) {
        c.panel = Qt.createQmlObject("import QtQuick; QtObject { property bool opened: true; property int revealed: 0; " +
          "function dismiss() { opened = false } function reveal() { revealed++; opened = true } " +
          "function openPage(n) {} function openHome() {} }", harness)
        service.attach(c.panel)
        c.started = service.setOption("transition", { mode: "flip" })
        c.panel.destroy()
      } },
      { until: function(c) { return !flip.busy }, ms: 8000 },
      { sleep: 200 },
      { run: function(c) {
        c.after = { optionNotice: service.optionNotice, optionFailed: service.optionFailed }
        service.dismiss()
        panelA.opened = true
        service.attach(panelA)
      } },
      { sh: "python3 -c \"import json, os; p = os.environ['FAKE_HYPR_STATE']; s = json.load(open(p)); " +
            "s['active_workspace'] = 3; json.dump(s, open(p, 'w'))\"" },
      { log: function(c) { return { started: c.started, after: c.after } } },
    ] },

    // Language picked four times in a row: it ends on the last one, with no
    // step back to an older one on the way.
    { name: "language", steps: [
      { run: function(c) {
        harness.languages = []
        service.setLanguage("es")
        service.setLanguage("en")
        service.setLanguage("es")
        service.setLanguage("en")
      } },
      { sleep: 1500 },
      { read: harness.stateDir + "/settings.json", into: "file" },
      { log: function(c) { return { history: harness.languages, file: JSON.parse(c.file || "{}"), now: service.languageSetting } } },
    ] },

    // The session's runtime directory did not exist when the service
    // started (at login, restore-them-all-at-login makes it a moment later):
    // names bin/cards writes there afterwards still reach the service.
    { name: "names-file", steps: [
      { sh: "python3 -c \"import json, os, tempfile; d = os.environ['SAVE_THEM_ALL_RUNTIME']; " +
            "os.makedirs(d, mode=0o700, exist_ok=True); fd, t = tempfile.mkstemp(dir=d); " +
            "os.write(fd, json.dumps({'1': 'Named later'}).encode()); os.close(fd); " +
            "os.replace(t, d + '/cards-' + os.environ['HYPRLAND_INSTANCE_SIGNATURE'] + '.json')\"" },
      { until: function(c) { return service.names["1"] === "Named later" }, ms: 3000 },
      { log: function(c) { return { names: service.names } } },
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
