// The render harness's steps (tests/render.qml): which page, in which
// language, and what changes from tests/fixtures/render.json. A task that
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
    patch: { cardsNotice: "Algunas ventanas siguen en un grupo; probá de nuevo" } },
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
]

if (typeof module !== "undefined") module.exports = { STEPS: STEPS }
