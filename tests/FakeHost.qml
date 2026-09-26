import QtQuick
import qs.Commons

// Panel.qml's face for the pages, without the bar, the processes or the
// keyboard grab: what the render harness hands each page as `host`.
QtObject {
  id: host
  readonly property FakeService service: FakeService {}
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property color urgent: Color.urgent
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property int workspaceId: 3
  property var record: null
  property string phase: ""
  property string lastError: ""
  property var loginRows: []
  property var browserQuit: ({ enabled: false, conflict: "" })
  property string browserQuitError: ""
  property string pageName: ""
  readonly property bool busy: phase !== ""
  readonly property bool hasSaved: record !== null

  function t(text, args) { return service.t(text, args) }

  function load(fixture, lang, patch) {
    var f = Object.assign({}, fixture, patch || {})
    record = f.record === undefined ? null : f.record
    loginRows = f.loginRows || []
    phase = f.phase || ""
    lastError = f.lastError || ""
    service.load(f, lang)
  }

  function save() {}
  function restore() {}
  function toggleLogin(row) {}
  function toggleBrowserQuit() {}
  function openPage(name) { pageName = name }
  function ensureVisible(item) {}
  function close() {}
}
