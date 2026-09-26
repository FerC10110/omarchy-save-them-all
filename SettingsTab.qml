import QtQuick
import qs.Commons
import qs.Ui
import "Labels.js" as Labels

// The Settings tab: language, and Hyprflip's own preferences for every card
// (appearance, spacing, animation, shortcuts), what Hyprflip says about
// itself, and the switch to close the browser cleanly. Every choice is one
// row, so j/k walk them all and Enter picks.
Column {
  id: tab
  required property var host
  readonly property var service: host.service
  readonly property var flip: service.flip
  readonly property var snap: flip.snapshot
  readonly property var caps: snap.capabilities
  // A row's own id, not its index: `rows` is rebuilt (new array, new
  // objects) whenever Hyprflip settles or a capability appears, which would
  // otherwise leave an index-based cursor pointing at a different row, or
  // past the end once rows shrink (Fix round 1, Finding 4).
  property string cursor: ""
  spacing: Style.space(6)

  readonly property var rows: {
    var out = []
    Labels.LANGUAGES.forEach(function(l) {
      out.push({ id: "language:" + l.value, section: "language", title: host.t(l.label), detail: "",
                 selected: service.languageSetting === l.value, act: { kind: "language", value: l.value } })
    })
    if (flip.available && caps.appearance === true) Labels.APPEARANCES.forEach(function(a) {
      out.push({ id: "appearance:" + a.value, section: "appearance", title: host.t(a.label), detail: host.t(a.detail),
                 selected: snap.appearance === a.value, act: { kind: "appearance", value: a.value } })
    })
    if (flip.available && caps.spacing === true) Labels.SPACINGS.forEach(function(s) {
      out.push({ id: "spacing:" + s.value, section: "spacing", title: host.t(s.label), detail: host.t(s.detail),
                 selected: snap.card_gap === s.value, act: { kind: "spacing", value: s.value } })
    })
    if (flip.available) {
      Labels.transitions(snap.transition_modes).forEach(function(m) {
        out.push({ id: "transition:" + m.value, section: "animation", title: host.t(m.label), detail: host.t(m.detail),
                   selected: snap.transition === m.value, act: { kind: "transition", value: m.value } })
      })
      Labels.speeds(snap.duration_ms).forEach(function(s) {
        out.push({ id: "duration:" + s.ms, section: "speed", title: host.t(s.label), detail: host.t("%1 ms", [s.ms]),
                   selected: snap.duration_ms === s.ms, act: { kind: "duration", value: s.ms } })
      })
      out.push({ id: "shortcuts-page", section: "shortcuts", title: host.t("Keyboard shortcuts"),
                 detail: host.t("Change a shortcut or bring back the default"), selected: false, act: { kind: "page" } })
    }
    // No verdict yet (right after attach(), before status/snapshot land): say
    // so, not "Hyprflip is not available" — that would be reporting on
    // placeholder data (Task 11 review's reasoning, applied here too).
    out.push({ id: "hyprflip-status", section: "hyprflip",
               title: !flip.settled ? host.t("Checking Hyprflip…")
                 : flip.available ? host.t("Hyprflip %1 on Hyprland %2", [flip.status.hyprflip, flip.status.hyprland])
                 : host.t("Hyprflip is not available"),
               detail: !flip.settled ? ""
                 : flip.available ? host.t("Everything is in order. Press Enter to check again.") : flip.unavailableText,
               selected: false, act: { kind: "check" } })
    return out
  }

  // Keep the cursor on the same row across a rebuild; once that row is gone
  // (a capability disappeared, Hyprflip settled), fall back to the first one.
  onRowsChanged: if (!rows.find(function(r) { return r.id === cursor })) cursor = Labels.step(rows, cursor, 0)
  Component.onCompleted: cursor = Labels.step(rows, cursor, 0)

  function sectionTitle(section) {
    switch (section) {
    case "language": return host.t("Language")
    case "appearance": return host.t("Card appearance")
    case "spacing": return host.t("Space between apps")
    case "animation": return host.t("Animation")
    case "speed": return host.t("Speed")
    case "shortcuts": return host.t("Shortcuts")
    default: return "Hyprflip"
    }
  }

  // service.setOption already refuses (and leaves a notice) while Hyprflip
  // is busy, for both the keyboard (activate()) and the mouse (ChoiceRow's
  // onActivated) — both go through this same function, so neither path
  // drops the action silently (Fix round 1, Finding 3).
  function choose(row) {
    var a = row.act
    if (a.kind === "language") service.setLanguage(a.value)
    else if (a.kind === "appearance") service.setOption("appearance", { style: a.value })
    else if (a.kind === "spacing") service.setOption("spacing", { gap: a.value })
    else if (a.kind === "transition") service.setOption("transition", { mode: a.value })
    else if (a.kind === "duration") service.setOption("duration", { duration_ms: a.value })
    else if (a.kind === "page") host.openPage("shortcuts")
    else if (a.kind === "check") flip.check()
  }

  function move(dx, dy) {
    if (dy === 0) return false
    cursor = Labels.step(rows, cursor, dy)
    return true
  }

  // Whether a row can be picked now: the same for the mouse (ChoiceRow's
  // enabled) and Enter, so the keyboard cannot reach what the mouse cannot.
  function rowEnabled(row) { return !flip.busy || row.section === "language" }

  function activate() {
    var row = rows.find(function(r) { return r.id === cursor })
    if (row && rowEnabled(row)) choose(row)
  }

  Repeater {
    model: tab.rows

    Column {
      id: entry
      required property var modelData
      required property int index
      width: tab.width
      spacing: Style.space(4)

      PanelSectionHeader {
        width: parent.width
        visible: entry.index === 0 || tab.rows[entry.index - 1].section !== entry.modelData.section
        text: tab.sectionTitle(entry.modelData.section)
        foreground: host.foreground
        fontFamily: host.fontFamily
      }

      ChoiceRow {
        width: parent.width
        title: entry.modelData.title
        detail: entry.modelData.detail
        selected: entry.modelData.selected
        cursorHere: tab.cursor === entry.modelData.id
        onCursorHereChanged: if (cursorHere) host.ensureVisible(entry)
        textColor: host.foreground
        fontFamily: host.fontFamily
        enabled: tab.rowEnabled(entry.modelData)
        onActivated: { tab.cursor = entry.modelData.id; tab.choose(entry.modelData) }
      }
    }
  }

  Text {
    width: parent.width
    visible: tab.flip.available && tab.caps.drag_to_add === true
    textFormat: Text.PlainText
    text: host.t("To add an app to a card, drag its window onto the card's “Drop to add” area. Esc cancels.")
    color: host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  // What the last setOption()/language/check said, the way CardsTab shows
  // cardAction's result (Fix round 1, Finding 3): busy first, then a
  // failure, then whatever bin/cards said outside a card action.
  Text {
    width: parent.width
    visible: text !== ""
    textFormat: Text.PlainText
    text: tab.flip.busy ? host.t("Working…") : (tab.flip.failed ? tab.flip.notice : tab.service.cardsNotice)
    color: tab.flip.failed ? host.urgent : host.dim
    font.family: host.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }

  BrowserQuitRow { width: parent.width; host: tab.host }
}
