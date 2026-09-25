# Changelog

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

The card format in `workspace-N.json` is a new, optional `cards` block. Version
1.3.0 ignores it, and a file without it reads as before.
