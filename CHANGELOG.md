# Changelog

## 2.0.1

### Fixed

- **Restoring on another layout.** A workspace that tiles with Omarchy's
  scrolling layout (or master) was left with every window on the hidden
  workspace: the tree is rebuilt with dwindle's `preselect`, which those
  layouts refuse, and the script died there, in silence. On a layout other
  than dwindle, restoring now reopens the missing windows, places the floating
  ones and leaves the tiles where the layout puts them, and the notification
  says so. Without Hyprflip, the cards (grouped as tabs with that same
  `preselect`) are left unbuilt there, with one note instead of one failure
  per card.
- **A restore that dies halfway** (a dispatch Hyprland refuses, a signal)
  brings every window on the hidden workspace back to the workspace, as plain
  tiles, and says where it stopped in the notification, on stderr and in
  `restore.log`. Windows an earlier run left there are brought back at the
  start of the next restore, before counting what is missing, so they are not
  launched a second time.
- A window saved floating but tiled when restoring was parked with the other
  tiles and never came back. It comes back after the others, and floats.

## 2.0.0

### Added

- **Cards.** With [Hyprflip](https://github.com/nocstah/hyprflip) loaded, the
  panel makes and manages flip cards: windows grouped on two sides, Front and
  Back, that flip in the same place.
  - A card builder with live thumbnails: drag windows onto either side, or
    pick them with the keyboard. Twin windows are told apart by where they
    are on screen, and windows that cannot join a card say why.
  - **Pick on screen**: click the windows themselves.
  - A Cards tab to flip, edit, take apart, unfold or float any card, on any
    workspace.
  - Hyprflip's own settings (appearance, spacing, animation) and its keyboard
    shortcuts, with conflict detection.
- **Saving a workspace saves its cards**, and restoring it builds them again:
  sides, order, axis, proportions, the side on show and where a floating card
  was. Without Hyprflip, each card comes back as a native Hyprland group with
  tabs, so no window stays hidden.
- **Show both faces**: when Hyprflip stops loading (after a Hyprland update, for
  instance), one button takes every window out of its group.
- **English and Spanish**, for the panel and the notifications. Automatic
  follows the system language.

### Changed

- The panel has tabs: Workspace, Cards and Settings. **Close the browser
  cleanly** moved to Settings.
- Restoring at login is started by the plugin's service instead of the panel.

### Fixed

- Card names show in the panel from the start of a session. The service
  watched the names file before its directory existed and never saw it
  appear, so names only showed after the shell reloaded.
- Restoring a workspace whose card is still built puts the other windows back
  around the card, where they were saved, instead of wherever Hyprland opened
  them (a window saved left of the card could come back on its right).
- Opening **Pick on screen** no longer logs a TypeError.
- A Hyprflip helper that hangs, or cannot start, no longer leaves the panel
  busy until the shell reloads: the action is stopped after a while, and says
  so.
- Editing a card keeps the proportions of a side that did not change (with a
  Hyprflip helper that reports them; older ones start the sides equal, as
  before); changing only its name just renames it.
- In English, the Hyprflip helper's messages (it speaks Spanish only) show in
  English.
- With a panel on each monitor, handing the focus to Hyprflip closes all of
  them. Fast language changes no longer flip back to an earlier one.
- **Show both faces** says when it worked. A card made or taken apart whose
  windows could not go back where they were says so, instead of a plain
  success.
- A card's name from the builder goes to that card only, not to one made later
  with the same windows. A builder left open in a closed panel stops refreshing
  windows and thumbnails. The builder notices cards made or taken apart
  elsewhere.
- Cards tab: `u` only unfolds a card of several apps and `t` needs floating
  cards (their hints are greyed out otherwise), and the chosen card scrolls
  into view.
- Settings: a speed set by hand shows as Custom; the keyboard cannot pick what
  the mouse cannot while Hyprflip is busy; shortcut conflicts match what
  Hyprflip refuses; and each page shows only its own messages.
- Pick on screen is cancelled if its monitor is unplugged.

The card format in `workspace-N.json` is a new, optional `cards` block. Version
1.3.0 ignores it, and a file without it reads as before.
