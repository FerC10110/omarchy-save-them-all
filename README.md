# Save Them All

Save the window layout of a Hyprland workspace and bring it back exactly: the
same apps, the same splits, the same sizes.

Omarchy restores your session, not your arrangement. You reopen the browser,
the terminal and three chart webapps, then spend a minute dragging them back
into the shape you actually work in. Save Them All records that shape once and
replays it on demand.

## Install

```sh
omarchy plugin add https://github.com/FerC10110/omarchy-save-them-all.git --enable
```

The bar gains a 󱂬 button on the right. It stays dim until the workspace you
are on has a saved layout.

## Usage

Click the button to open the panel:

- **Save them all** (`s`) records every window on the current workspace.
- **Restore them all** (`r`) reopens whatever is missing and rebuilds the layout.

Middle-clicking the bar button saves without opening the panel, which is the
action you repeat most. `Escape` closes the panel.

Each workspace keeps its own layout, so workspace 1 and workspace 2 can hold
different arrangements and never overwrite each other.

Restoring is safe to repeat. Windows that are already open are reused rather
than launched twice, so running it on a half-open workspace fills in the gaps
instead of duplicating what is there.

### From the menu, a keybinding or the terminal

The two scripts are plain bash and work on their own. Put them on your `PATH`:

```sh
ln -s ~/.config/omarchy/plugins/io.github.ferc10110.save-them-all/bin/save-them-all ~/.local/bin/
ln -s ~/.config/omarchy/plugins/io.github.ferc10110.save-them-all/bin/restore-them-all ~/.local/bin/
```

A keybinding in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + SHIFT + S", "Save them all", "save-them-all")
o.bind("SUPER + SHIFT + O", "Restore them all", "restore-them-all")
```

Entries in the Omarchy menu, in `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"windows": {"icon":"󱂬","label":"Windows"},
"windows.save": {"icon":"󰆓","label":"Save them all","action":"save-them-all"},
"windows.restore": {"icon":"󰑓","label":"Restore them all","action":"restore-them-all"},
```

## How it works

`save-them-all` walks the windows of the active workspace, sorted left to right
and top to bottom, and writes one JSON file per workspace to
`~/.local/state/save-them-all/`. For each window it records the position, the
size, and a command that can bring it back:

| Window | How it is reopened |
|---|---|
| Chromium webapp | The `.desktop` file whose URL produces that window class, else the URL rebuilt from the class |
| Browser | `omarchy-launch-browser` |
| Terminal | `omarchy-launch-terminal`, with `herdr` or `tmux` when the process tree has one |
| Anything else | Its own `/proc` command line, through `uwsm-app` |

`restore-them-all` then opens whatever is missing and rebuilds the layout.
Reopening the windows in the right order is not enough: dwindle splits each new
window against the aspect ratio of the one it lands on, so an arrangement with
cuts that don't follow from that ratio comes back wrong. Instead the script
derives the tree of guillotine cuts from the saved rectangles, parks every
window on a hidden workspace, and reinserts them one at a time with an explicit
`preselect` before each. Sizes are settled at the end with relative resizes that
read back the real geometry, because an exact resize is only reliable while a
window floats.

Floating windows skip all of that and are placed directly, and windows that were
open but never saved come back to the right of the last one.

The state files are plain JSON and meant to be edited. Change a size, drop a
window, or write a layout from scratch and restore it.

## Configure

```sh
omarchy bar move io.github.ferc10110.save-them-all --section left
```

| Variable | Default | Meaning |
|---|---|---|
| `SAVE_THEM_ALL_STATE` | `~/.local/state/save-them-all` | Where layouts are kept |
| `SAVE_THEM_ALL_TIMEOUT` | `25` | Seconds to wait for a window to appear |

## Requirements

Omarchy 4 with Hyprland 0.56 or newer, on the dwindle layout. It leans on
`hyprctl`'s Lua dispatchers, which replaced the old string syntax in 0.56, and
on `jq`, `python3` and `pstree`, all of which ship with Omarchy.

## Limitations

- **Dwindle only.** The tree reconstruction is guillotine cuts; master and
  scrolling layouts are not handled.
- **One monitor's workspace at a time.** A layout belongs to a workspace id, and
  restoring targets whichever workspace is active.
- **Chromium is a single instance.** Its windows are created by the process
  that is already running, so they are arranged after the fact rather than
  placed as they open. Restoring a browser window waits for Chrome's own
  session restore to settle first.
- **Apps are matched by window class and count.** Two windows of the same app
  are told apart by their position in the saved order, not by their content.

## Remove

```sh
omarchy plugin remove io.github.ferc10110.save-them-all
```

Saved layouts are left behind in `~/.local/state/save-them-all/`; delete that
directory to clear them.

## License

MIT. See [LICENSE](LICENSE).
