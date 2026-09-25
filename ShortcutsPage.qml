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
  // A row's own id, not its index (Fix round 1, Finding 4): `bindings.rows`
  // is a fresh array on every snapshot refresh, so an index-based cursor
  // could end up pointing at a different action once the list changes.
  property string cursor: ""
  property string selectedId: ""
  readonly property var selected: bindings.rows.find(function(r) { return r.id === selectedId }) || null
  property int candidateMask: 0
  property string candidateKey: ""
  property string error: ""
  property bool recording: false
  readonly property bool typing: recording
  readonly property string conflictText: selected
    ? Shortcuts.conflict(bindings.occupied, selectedId, candidateMask, candidateKey, host.t, labelOf) : ""
  // Whether the candidate chord can be saved: also false while Hyprflip is
  // busy, so a keyboard Enter and the Save button agree (Fix round 1,
  // Finding 3).
  readonly property bool canSave: !recording && error === "" && conflictText === "" && !service.flip.busy
    && selected !== null && candidateKey !== ""
    && (candidateMask !== selected.mask || candidateKey.toLowerCase() !== String(selected.key).toLowerCase())
  spacing: Style.space(8)

  // Keep the cursor on the same row across a refresh; fall back to the
  // first one once it is gone.
  onBindingsChanged: if (!bindings.rows.find(function(r) { return r.id === cursor })) cursor = Labels.step(bindings.rows, cursor, 0)
  Component.onCompleted: cursor = Labels.step(bindings.rows, cursor, 0)

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

  function startRecording() {
    if (!selected) return
    error = ""
    recording = true
    Qt.callLater(function() { recorder.forceActiveFocus() })
  }

  function useDefault() {
    if (!selected) return
    candidateMask = selected.default_mask
    candidateKey = selected.default_key
    error = ""
  }

  function save() {
    if (!canSave) return
    service.setOption("shortcut", { binding: selectedId, mask: candidateMask, key: candidateKey })
  }

  function cancelEdit() {
    recording = false
    selectedId = ""
  }

  function capture(event) {
    event.accepted = true
    var r = Shortcuts.capture(event.key, event.modifiers, event.isAutoRepeat, host.t)
    if (r.ignore) return
    // Esc alone, while recording: stop listening, but stay on this row and
    // this panel (only the chord capture is cancelled).
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
    cursor = Labels.step(bindings.rows, cursor, dy)
    return true
  }

  // Enter: pick the row under the cursor; once one is selected, either
  // start recording (nothing worth saving yet) or save a captured chord —
  // whichever the Save button itself would allow (Fix round 1, Finding 2).
  function activate() {
    if (selected) {
      if (canSave) save()
      else startRecording()
      return
    }
    var row = bindings.rows.find(function(r) { return r.id === cursor })
    if (row) choose(row)
  }

  function key(text) {
    if (!selected || recording) return
    if (String(text).toLowerCase() === "d") useDefault()
  }

  function back() {
    if (selectedId !== "") {
      cancelEdit()
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

  // What the last save said, the way CardsTab shows cardAction's result
  // (Fix round 1, Finding 3): busy first, then a failure, then whatever
  // bin/cards said outside this page's own edit.
  Text {
    width: parent.width
    visible: text !== ""
    textFormat: Text.PlainText
    text: service.flip.busy ? host.t("Working…") : (service.flip.failed ? service.flip.notice : service.cardsNotice)
    color: service.flip.failed ? host.urgent : host.dim
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
    // Losing focus for any reason (the panel closing, a click elsewhere)
    // must stop the recording too, or the ShortcutInhibitor could stay
    // engaged with nothing actually listening (Fix round 1, Finding 1).
    onActiveFocusChanged: if (!activeFocus) page.recording = false
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

    Text {
      width: parent.width
      visible: !page.recording
      textFormat: Text.PlainText
      text: page.canSave ? host.t("Enter saves this shortcut · d for the default · Esc cancels.")
                         : host.t("Enter records a new shortcut · d for the default · Esc cancels.")
      color: host.dim
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
        onClicked: page.startRecording()
      }

      Button {
        text: host.t("Use default")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.useDefault()
      }

      Button {
        text: host.t("Save shortcut")
        bordered: true
        enabled: page.canSave
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.save()
      }

      Button {
        text: host.t("Cancel")
        bordered: true
        foreground: host.foreground
        fontFamily: host.fontFamily
        onClicked: page.cancelEdit()
      }
    }

    PanelSeparator { width: parent.width; foreground: host.foreground }
  }

  Repeater {
    model: page.bindings.rows

    ChoiceRow {
      required property var modelData
      width: page.width
      title: page.rowTitle(modelData)
      detail: page.rowDetail(modelData)
      selected: modelData.id === page.selectedId
      cursorHere: page.cursor === modelData.id
      enabled: modelData.editable === true
      textColor: host.foreground
      fontFamily: host.fontFamily
      onActivated: { page.cursor = modelData.id; page.choose(modelData) }
    }
  }
}
