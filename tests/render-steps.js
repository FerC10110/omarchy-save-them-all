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
]

if (typeof module !== "undefined") module.exports = { STEPS: STEPS }
