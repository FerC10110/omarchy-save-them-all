import QtQuick
import "SaveThemAll/I18n.js" as I18n
import "SaveThemAll/AppNames.js" as AppNames
import "SaveThemAll/Protocol.js" as Protocol
import "SaveThemAll/HelperText.js" as HelperText

// Service.qml's face without processes: the render harness fills it from
// tests/fixtures/render.json, and every action does nothing.
QtObject {
  id: fake
  property string lang: "en"
  property string languageSetting: "auto"
  property var entries: []
  property var clients: []
  property var names: ({})
  property int focusedWorkspace: 3
  property bool thumbnails: false
  property var draft: null
  property string builderNotice: ""
  property string cardsNotice: ""
  property bool cardsFailed: false
  property string optionNotice: ""
  property bool optionFailed: false
  property string optionAction: ""
  property string ungroupNotice: ""
  property bool ungroupFailed: false
  property var pickDraft: null
  property int pickFace: 0
  // Every action a page called, as [name, args…]: what a step's `expect`
  // checks (tests/render-steps.js).
  property var calls: []
  readonly property var byAddress: {
    var out = {}
    clients.forEach(function(c) { out[c.address] = c })
    return out
  }

  readonly property QtObject flip: QtObject {
    property var t: function(text, args) { return fake.t(text, args) }
    property var status: ({ available: true, reason: "ok" })
    property var snapshot: Protocol.emptySnapshot()
    // Real Hyprflip.qml: true once status and (if it says available) the
    // first snapshot came back. Defaults true here; a step patches it false
    // to render the moment right after attach(), before either has landed.
    property bool settled: true
    readonly property bool available: status.available === true && snapshot.available === true
    readonly property bool canCreate: Protocol.canCreate(available, snapshot)
    readonly property bool canUnpair: available && snapshot.capabilities.unpair === true
    readonly property string unavailableText: Protocol.whyUnavailable(status, snapshot, "", t,
      function(message) { return HelperText.forLang(message, fake.lang) })
    property bool busy: false
    property string notice: ""
    property bool failed: false
    function check() {}
  }

  function t(text, args) { return I18n.t(text, lang, args) }
  function appName(win) { return AppNames.resolve(win, entries).name }
  function appIcon(win) { return AppNames.resolve(win, entries).icon }

  function load(f, language) {
    lang = language
    entries = f.entries || []
    clients = f.clients || []
    names = f.names || {}
    focusedWorkspace = f.focusedWorkspace || 3
    draft = f.draft === undefined ? null : f.draft
    pickDraft = f.pickDraft === undefined ? draft : f.pickDraft
    pickFace = f.pickFace || 0
    builderNotice = f.builderNotice || ""
    cardsNotice = f.cardsNotice || ""
    cardsFailed = f.cardsFailed === true
    optionNotice = f.optionNotice || ""
    optionFailed = f.optionFailed === true
    optionAction = f.optionAction || ""
    ungroupNotice = f.ungroupNotice || ""
    ungroupFailed = f.ungroupFailed === true
    flip.status = f.status || { available: true, reason: "ok" }
    flip.snapshot = Protocol.parseSnapshot(JSON.stringify(Object.assign({}, f.snapshot || {}, f.snapshotPatch || {}))).snapshot
    if (f.emptyCards) flip.snapshot = Object.assign({}, flip.snapshot, { cards: [] })
    flip.settled = f.settled === false ? false : true
    flip.busy = f.busy === true
    flip.notice = f.notice || ""
    flip.failed = f.failed === true
    calls = []
  }

  function record(name, args) { calls = calls.concat([[name].concat(args || [])]) }

  // Actions: the harness only looks, and records what was asked.
  function attach(panel) {}
  function setLanguage(value) { languageSetting = value; record("setLanguage", [value]) }
  function setName(id, name) { record("setName", [id, name]) }
  function refreshClients() {}
  function toplevelFor(address) { return null }
  function ungroup(workspace) { record("ungroup", [workspace]) }
  function moveCursor(address) {}
  function place(address, face, index) { record("place", [address, face, index]) }
  function removeFromDraft(address) { record("removeFromDraft", [address]) }
  function setAxis(face, axis) {}
  function setDraftName(name) {}
  function submitDraft() { record("submitDraft") }
  function cancelBuilder() { record("cancelBuilder") }
  function startBuilder(card) { record("startBuilder", [card ? card.key : null]) }
  function cardAction(action, card) { record("cardAction", [action, card ? card.key : null]) }
  function setOption(action, extra) { record("setOption", [action, extra]); return true }
  function startPick() { record("startPick") }
  function pickToggle(address) { record("pickToggle", [address]) }
  function finishPick(apply) { record("finishPick", [apply]) }
}
