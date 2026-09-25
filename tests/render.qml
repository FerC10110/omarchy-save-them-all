import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import qs.Commons
// Unused, but this is what makes Quickshell's virtual "qs:" filesystem list
// SaveThemAll/'s own .qml files as types: without it, a page's sibling
// component (BrowserQuitRow inside WorkspaceTab.qml) resolves to "is not a
// type" even though the same file loads fine as a real, file:// plugin.
import "SaveThemAll" as SaveThemAll
import "render-steps.js" as Steps

// Loads each page of the panel with a fake host and service, one step of
// tests/render-steps.js at a time, and logs the texts each one shows:
//   RENDER_TEXTS <step> <lang> <json list of texts>
// SAVE_THEM_ALL_CAPTURE_DIR, when set, also gets a PNG per step.
ShellRoot {
  id: harness
  property int step: -1
  property var fixture: null
  property bool finishing: false

  FakeHost { id: host }

  FileView {
    path: Quickshell.env("SAVE_THEM_ALL_RENDER_FIXTURE")
    onLoaded: {
      harness.fixture = JSON.parse(text())
      tick.start()
    }
  }

  Window {
    visible: true
    width: 760
    height: 760
    color: Color.popups.background

    Rectangle {
      id: area
      anchors.fill: parent
      color: Color.popups.background
      Loader { id: page; anchors.fill: parent; anchors.margins: 14 }
    }
  }

  function texts(item, out) {
    if (!item || item.visible === false) return out
    if (typeof item.text === "string" && item.text !== "") out.push(item.text)
    if (typeof item.placeholderText === "string" && item.placeholderText !== "") out.push(item.placeholderText)
    var kids = item.children || []
    for (var i = 0; i < kids.length; i++) texts(kids[i], out)
    return out
  }

  Timer {
    id: tick
    interval: 300
    onTriggered: {
      if (harness.finishing) { console.log("SAVE_THEM_ALL_RENDER_OK"); Qt.quit(); return }
      if (harness.step >= 0) {
        var done = Steps.STEPS[harness.step]
        console.log("RENDER_TEXTS " + done.name + " " + done.lang + " " + JSON.stringify(harness.texts(page.item, [])))
        var dir = Quickshell.env("SAVE_THEM_ALL_CAPTURE_DIR")
        if (dir) area.grabToImage(function(result) { result.saveToFile(dir + "/" + done.name + ".png") })
      }
      harness.step++
      if (harness.step >= Steps.STEPS.length) {
        harness.finishing = true
        tick.start()
        return
      }
      var next = Steps.STEPS[harness.step]
      host.load(harness.fixture, next.lang, next.patch)
      page.setSource(Qt.resolvedUrl("SaveThemAll/" + next.page), { host: host })
      tick.start()
    }
  }
}
