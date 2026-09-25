import QtQuick
import qs.Commons
import qs.Ui
import "Labels.js" as Labels
import "Shortcuts.js" as Shortcuts

// Hyprflip's keyboard shortcuts, after OmaCards' ShortcutsContent.qml (MIT,
// see NOTICE): pick one, record a new chord (the panel stops Hyprland from
// acting on it meanwhile), see what else uses it, and save.
Column {
  id: page
  required property var host
  readonly property var service: host.service
  readonly property var bindings: service.flip.snapshot.shortcuts
  property int cursor: 0
  property string selectedId: ""
  readonly property var selected: bindings.rows.find(function(r) { return r.id === selectedId }) || null
  property int candidateMask: 0
  property string candidateKey: ""
  property string error: ""
  property bool recording: false
  readonly property bool typing: recording
  readonly property string conflictText: selected
    ? Shortcuts.conflict(bindings.occupied, selectedId, candidateMask, candidateKey, host.t, labelOf) : ""
  spacing: Style.space(8)

  function labelOf(binding) {
    var own = Labels.shortcutLabel(binding.id, "")
    return own ? host.t(own) : String(binding.label || "")
  }

  function rowTitle(row) { return labelOf(row) }

  function rowDetail(row) {
    var text = row.key ? Shortcuts.chord(row.mask, row.key, host.t) : host.t("Not assigned")
    return row.editable ? text : text + " · " + host.t("Not editable here")
  }

  function choose(row) {
    if (!row.editable) return
    selectedId = row.id
    candidateMask = row.mask
    candidateKey = row.key
    recording = false
    error = ""
  }

  function capture(event) {
    event.accepted = true
    var r = Shortcuts.capture(event.key, event.modifiers, event.isAutoRepeat, host.t)
    if (r.ignore) return
    if (r.cancel) { recording = false; return }
    if (r.error) { error = r.error; return }
    candidateMask = r.mask
    candidateKey = r.key
    error = ""
    recording = false
  }

  function stopRecording() { recording = false }

  function move(dx, dy) {
    if (dy === 0) return false
    cursor = Math.max(0, Math.min(bindings.rows.length - 1, cursor + dy))
    return true
  }

  function activate() {
    if (cursor >= 0 && cursor < bindings.rows.length) choose(bindings.rows[cursor])
  }

  function back() {
    if (selectedId !== "") {
      recording = false
      selectedId = ""
      return true
    }
    host.openPage("settings")
    return true
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: host.t("Keyboard shortcuts")
    color: host.foreground
    font.family: host.fontFamily
    font.pixelSize: Style.font.title
    font.bold: true
  }

  Text {
    width: parent.width
    textFormat: Text.PlainText
    text: page.bindings.available ? host.t("Pick an action to change its shortcut.")
                                  : host.t("Update Hyprflip's guided setup to edit shortcuts.")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  // Keys go here while recording; the panel's key catcher stands aside.
  Item {
    id: recorder
    width: 0
    height: 0
    Keys.onPressed: function(event) { if (page.recording) page.capture(event) }
  }

  Column {
    width: parent.width
    visible: page.selected !== null
    spacing: Style.space(6)

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: page.selected ? page.rowTitle(page.selected) : ""
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: page.recording ? host.t("Press the new shortcut. Esc cancels.")
                           : Shortcuts.chord(page.candidateMask, page.candidateKey, host.t)
      color: host.foreground
      font.family: host.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    Text {
      width: parent.width
      visible: text !== ""
      textFormat: Text.PlainText
      text: page.error || page.conflictText
      color: host.urgent
      font.family: host.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }

    Flow {
      width: parent.width
      spacing: Style.space(6)

      Button {
        text: page.recording ? host.t("Listening…") : host.t("Record shortcut")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: {
          page.error = ""
          page.recording = true
          recorder.forceActiveFocus()
        }
      }

      Button {
        text: host.t("Use default")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: {
          page.candidateMask = page.selected.default_mask
          page.candidateKey = page.selected.default_key
          page.error = ""
        }
      }

      Button {
        text: host.t("Save shortcut")
        bordered: true
        enabled: !page.recording && page.error === "" && page.conflictText === "" && page.selected !== null
          && page.candidateKey !== "" && (page.candidateMask !== page.selected.mask
          || page.candidateKey.toLowerCase() !== String(page.selected.key).toLowerCase())
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.service.setOption("shortcut", { binding: page.selectedId, mask: page.candidateMask, key: page.candidateKey })
      }

      Button {
        text: host.t("Cancel")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: {
          page.recording = false
          page.selectedId = ""
        }
      }
    }

    PanelSeparator { width: parent.width; foreground: host.foreground }
  }

  Repeater {
    model: page.bindings.rows

    ChoiceRow {
      required property var modelData
      required property int index
      width: page.width
      title: page.rowTitle(modelData)
      detail: page.rowDetail(modelData)
      selected: modelData.id === page.selectedId
      cursorHere: page.cursor === index
      enabled: modelData.editable === true
      textColor: host.foreground
      fontFamily: host.fontFamily
      onActivated: { page.cursor = index; page.choose(modelData) }
    }
  }
}
