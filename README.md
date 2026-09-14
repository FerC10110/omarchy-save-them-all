# Save Them All

Save the window layout of a Hyprland workspace and bring it back exactly: the
same apps, the same splits, the same sizes.

![The Save Them All panel](preview.png)

Omarchy restores your session, not your arrangement. You reopen the browser,
the terminal and three chart webapps, then spend a minute dragging them back
into the shape you actually work in. Save Them All records that shape once and
replays it on demand, or on its own every time you log in.

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

### Restore at login

The bottom of the panel lists every workspace with a saved layout, each with its
own switch. They all start off. Turn one on and that workspace comes back by
itself the next time you log in, without opening the panel or running anything.

With several switches on, workspaces are restored in order. Rebuilding a layout
means focusing its windows, so you will see the workspaces go by while it works;
it finishes on the workspace you started on.

It runs once per session. Restarting the shell, or the plugin reloading, does not
restore again and does not reshuffle windows you have moved since. Saving a
workspace again keeps its switch as it was.

### From the menu, a keybinding or the terminal

The scripts are plain bash and work on their own. Put them on your `PATH`:

```sh
for s in save-them-all restore-them-all restore-them-all-at-login; do
  ln -s ~/.config/omarchy/plugins/io.github.ferc10110.save-them-all/bin/$s ~/.local/bin/
done
```

`restore-them-all --workspace 3` restores workspace 3 from anywhere. The login
switches are available too:

```sh
restore-them-all-at-login --list        # every saved workspace and its switch, as JSON
restore-them-all-at-login --enable 3    # restore workspace 3 at login
restore-them-all-at-login --disable 3
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

When the browser is not running yet, as right after logging in, it is started
first and given time to finish restoring its own last session. Only then does
the script count what is still missing, so it does not launch a window the
browser was about to bring back.

The login restore is started by the panel when the shell loads it, and runs
detached from the shell. Before doing anything it claims a marker named after
the Hyprland instance in `$XDG_RUNTIME_DIR/save-them-all/`. That directory is
private to your user and emptied when the session ends, so the marker means
"this session has been restored" and nothing more.

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
| `SAVE_THEM_ALL_LOGIN_DELAY` | `3` | Seconds to let the session settle before restoring at login |
| `SAVE_THEM_ALL_RUNTIME` | `$XDG_RUNTIME_DIR/save-them-all` | Where the once-per-session marker lives |

## Requirements

Omarchy 4 with Hyprland 0.56 or newer, on the dwindle layout. It leans on
`hyprctl`'s Lua dispatchers, which replaced the old string syntax in 0.56, and
on `jq`, `python3` and `pstree`, all of which ship with Omarchy.

## Limitations

- **Dwindle only.** The tree reconstruction is guillotine cuts; master and
  scrolling layouts are not handled.
- **One monitor's workspace at a time.** A layout belongs to a workspace id, and
  restoring targets whichever workspace is active.
- **Login restore needs the widget in the bar.** The panel is what starts it, so
  a disabled plugin, or a bar without the widget, restores nothing at login.
- **Chromium is a single instance.** Its windows are created by the process
  that is already running, so they are arranged after the fact rather than
  placed as they open. When the browser restores its own last session, those
  windows open on whichever workspace is on screen at that moment, which may
  not be the one they were saved on.
- **Apps are matched by window class and count.** Two windows of the same app
  are told apart by their position in the saved order, not by their content.
- **A terminal comes back as a terminal.** It reopens through Omarchy's own
  launcher so a `herdr` or `tmux` session is picked up again, which also means
  a terminal that was running something else starts empty.

## Remove

```sh
omarchy plugin remove io.github.ferc10110.save-them-all
```

Saved layouts are left behind in `~/.local/state/save-them-all/`; delete that
directory to clear them.

## License

MIT. See [LICENSE](LICENSE).
