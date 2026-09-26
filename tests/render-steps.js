// The render harness's steps (tests/render.qml): which page, in which
// language, and what changes from tests/fixtures/render.json (snapshotPatch
// changes fields of its snapshot). A step can also run `calls` on the page
// ([function, args…], as keys would), name page properties to log in
// `state`, and `expect` the service calls and state that follow. A task that
// adds a page adds its steps here.
var STEPS = [
  { name: "workspace-en", page: "WorkspaceTab.qml", lang: "en", patch: {} },
  { name: "workspace-es", page: "WorkspaceTab.qml", lang: "es", patch: {} },
  { name: "workspace-paused-es", page: "WorkspaceTab.qml", lang: "es",
    patch: { status: { available: false, reason: "no-plugin", fix: "cd ~/.local/src/hyprflip-omacards && make" } } },
  { name: "workspace-empty-es", page: "WorkspaceTab.qml", lang: "es", patch: { record: null, loginRows: [] } },
  // Hyprflip's status is ok but its first snapshot has not come back yet
  // (still Protocol.emptySnapshot(), available: false): no verdict, so no
  // false "cards paused" warning and no live ungroup button.
  { name: "workspace-unsettled-es", page: "WorkspaceTab.qml", lang: "es", patch: { settled: false, snapshot: {} } },
  // bin/cards ungroup failed (windows still grouped after 64 tries): the
  // Workspace tab shows what the script said, translated.
  { name: "workspace-cards-notice-es", page: "WorkspaceTab.qml", lang: "es",
    patch: { ungroupNotice: "Algunas ventanas siguen en un grupo; probá de nuevo" } },
  // A card action's notice ("Card created.") belongs to the Cards tab; the
  // Workspace tab only shows what ungroup said, in its warning color.
  { name: "workspace-card-notice-es", page: "WorkspaceTab.qml", lang: "es", patch: { cardsNotice: "Tarjeta creada." } },
  { name: "builder-new-en", page: "CardBuilder.qml", lang: "en",
    patch: { draft: { mode: "create", card: null, workspace: 3, faces: [["0x1"], ["0x4", "0x5"]], axes: ["row", "column"],
                      visible: 0, floating: null, name: "Work", cursor: "0x4" } } },
  { name: "builder-edit-es", page: "CardBuilder.qml", lang: "es",
    patch: { draft: { mode: "edit", card: { kind: "container", id: 1, faces: [["0x2"], ["0x3"]] }, workspace: 3,
                      faces: [["0x2"], ["0x3"]], axes: ["row", "row"], visible: 0, floating: null, name: "Notes", cursor: "" } } },
  { name: "builder-notice-es", page: "CardBuilder.qml", lang: "es",
    patch: { builderNotice: "Una cara admite hasta 5 ventanas.",
             draft: { mode: "create", card: null, workspace: 3, faces: [["0x1"], []], axes: ["row", "row"],
                      visible: 0, floating: null, name: "", cursor: "0x1" } } },
  { name: "cards-en", page: "CardsTab.qml", lang: "en", patch: {} },
  { name: "cards-es", page: "CardsTab.qml", lang: "es", patch: { cardsNotice: "Tarjeta creada." } },
  { name: "cards-unavailable-es", page: "CardsTab.qml", lang: "es",
    patch: { status: { available: false, reason: "no-helper", fix: "python3 ~/.local/src/hyprflip-omacards/scripts/install-setup.py --backend-only" } } },
  // Hyprflip's status is ok but its first snapshot has not come back yet
  // (still Protocol.emptySnapshot(), available: false): no verdict, so no
  // premature "Cards need Hyprflip" — only "Checking Hyprflip…" (Fix round 1).
  { name: "cards-unsettled-es", page: "CardsTab.qml", lang: "es", patch: { settled: false, snapshot: {} } },
  { name: "cards-empty-en", page: "CardsTab.qml", lang: "en", patch: { emptyCards: true } },
  // A native pair, and a Hyprflip without floating cards: u (the helper only
  // unfolds a container) and t do nothing, and their hints are greyed.
  { name: "cards-pair-keys-en", page: "CardsTab.qml", lang: "en",
    patch: { snapshotPatch: {
      capabilities: { containers: true, max_panes: 5, create_faces: true, unpair: true, floating: false },
      cards: [{ id: 5, kind: "pair", key: "pair:5", token: "p5", current: "0x2", active: 0, unfolded: false,
                floating: false, workspace: 3, name: "Calculator ↔ Obsidian",
                faces: [{ index: 0, axis: "horizontal", panes: [{ address: "0x2", label: "Calculator" }] },
                        { index: 1, axis: "horizontal", panes: [{ address: "0x3", label: "Obsidian" }] }] }] } },
    calls: [["key", "u"], ["key", "t"], ["key", "v"]],
    expect: { calls: [["cardAction", "flip", "pair:5"]] } },
  { name: "settings-en", page: "SettingsTab.qml", lang: "en", patch: {} },
  { name: "settings-es", page: "SettingsTab.qml", lang: "es", patch: {} },
  { name: "settings-unavailable-es", page: "SettingsTab.qml", lang: "es",
    patch: { status: { available: false, reason: "mismatch", hyprland: "0.57.0", built_for: "0.56.2", fix: "make" } } },
  // Hyprflip's duration is none of the presets (set by hand): a Custom row
  // shows it, selected, instead of no speed at all.
  { name: "settings-custom-speed-en", page: "SettingsTab.qml", lang: "en", patch: { snapshotPatch: { duration_ms: 500 } } },
  { name: "shortcuts-es", page: "ShortcutsPage.qml", lang: "es", patch: {} },
  // setOption()/save() now leave a notice instead of dropping a refused
  // action silently (Task 15 fix round 1): both pages show it the way
  // CardsTab shows cardAction's result.
  { name: "settings-failed-es", page: "SettingsTab.qml", lang: "es",
    patch: { failed: true, notice: "Hyprflip está ocupado; probá de nuevo en un momento." } },
  { name: "shortcuts-busy-en", page: "ShortcutsPage.qml", lang: "en", patch: { busy: true } },
  // Enter picked "flip"; j then must not walk the highlight off the row that
  // Enter (and Save) act on while it is selected.
  { name: "shortcuts-selected-move-en", page: "ShortcutsPage.qml", lang: "en", patch: {},
    calls: [["activate"], ["move", 0, 1]], state: ["cursor", "selectedId"],
    expect: { calls: [], state: { cursor: "flip", selectedId: "flip" } } },
  // While Hyprflip is busy the mouse cannot pick a Hyprflip row; Enter must
  // not either. Language rows stay live for both.
  { name: "settings-busy-keys-en", page: "SettingsTab.qml", lang: "en", patch: { busy: true },
    calls: [["move", 0, 3], ["activate"], ["move", 0, -2], ["activate"]], state: ["cursor"],
    expect: { calls: [["setLanguage", "en"]], state: { cursor: "language:en" } } },
  { name: "pick-es", page: "PickView.qml", lang: "es",
    patch: { pickFace: 0, draft: { mode: "create", card: null, workspace: 3, faces: [["0x1"], ["0x4"]], axes: ["row", "row"],
                                   visible: 0, floating: null, name: "", cursor: "0x4" } } },
]

if (typeof module !== "undefined") module.exports = { STEPS: STEPS }
