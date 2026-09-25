import QtQuick
import "SaveThemAll/I18n.js" as I18n
import "SaveThemAll/AppNames.js" as AppNames
import "SaveThemAll/Protocol.js" as Protocol

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
  property var pickDraft: null
  property int pickFace: 0
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
    readonly property bool canCreate: available && snapshot.capabilities.create_faces === true
    readonly property bool canUnpair: available && snapshot.capabilities.unpair === true
    readonly property string unavailableText: status.available === true ? "" : Protocol.unavailableText(status, t)
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
    flip.status = f.status || { available: true, reason: "ok" }
    flip.snapshot = Protocol.parseSnapshot(JSON.stringify(f.snapshot || {})).snapshot
    if (f.emptyCards) flip.snapshot = Object.assign({}, flip.snapshot, { cards: [] })
    flip.settled = f.settled === false ? false : true
    flip.busy = f.busy === true
    flip.notice = f.notice || ""
    flip.failed = f.failed === true
  }

  // Actions: the harness only looks.
  function attach(panel) {}
  function setLanguage(value) { languageSetting = value }
  function setName(id, name) {}
  function refreshClients() {}
  function toplevelFor(address) { return null }
  function ungroup(workspace) {}
  function moveCursor(address) {}
  function place(address, face, index) {}
  function removeFromDraft(address) {}
  function setAxis(face, axis) {}
  function setDraftName(name) {}
  function submitDraft() {}
  function cancelBuilder() {}
  function startBuilder(card) {}
  function cardAction(action, card) {}
  function setOption(action, extra) {}
  function startPick() {}
  function pickToggle(address) {}
  function finishPick(apply) {}
}
