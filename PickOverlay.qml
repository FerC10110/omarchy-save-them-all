import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import "Pick.js" as Pick

// The plugin's overlay entry point: the shell loads it when the builder
// summons "Pick on screen", calls open(), and unloads it on hide. It covers
// the focused monitor with PickView and takes the keyboard while it is up.
Item {
  id: root
  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false
  // The monitor and workspace open() recorded, once: the overlay keeps
  // showing what was on screen when picking started even if a workspace
  // keybind fires under the exclusive keyboard grab (Hyprland still runs
  // those) or focus drifts to another output mid-pick.
  property var pin: null

  function monitorNamed(name) {
    var list = Hyprland.monitors ? Hyprland.monitors.values : []
    for (var i = 0; i < list.length; i++) if (list[i] && list[i].name === name) return list[i]
    return null
  }

  readonly property var pinnedMonitor: root.pin ? monitorNamed(root.pin.name) : null
  readonly property int pinnedWorkspaceId: pinnedMonitor && pinnedMonitor.activeWorkspace ? pinnedMonitor.activeWorkspace.id : -1

  // The pinned monitor moved to another workspace while picking: cancel
  // instead of silently showing (and letting a click add from) whatever is
  // on that workspace now.
  onPinnedWorkspaceIdChanged: {
    if (service && service.picking && Pick.pinChanged(root.pin, pinnedWorkspaceId)) service.finishPick(false)
  }

  // Only startPick() opens this for real: it sets pickDraft, then summons.
  // Anything else that reaches this plugin id now that it also carries kind
  // "overlay" — an external summon/toggle aimed at the id, e.g. a keybind
  // that used to open the panel — finds picking false here and gets nothing
  // but a self-hide, not a stray fullscreen veil left mounted and invisible.
  function open(payloadJson) {
    if (!service || !service.picking) {
      if (shell && manifest) shell.hide(manifest.id)
      return
    }
    var mon = Hyprland.focusedMonitor
    pin = { name: mon ? mon.name : "", x: mon ? mon.x : 0, y: mon ? mon.y : 0, workspace: service.focusedWorkspace }
    opened = true
    Qt.callLater(function() { view.forceActiveFocus() })
  }

  // Hidden by anyone else (the shell, IPC): the builder keeps its draft.
  function close() {
    opened = false
    if (service && service.picking) service.finishPick(false)
    pin = null
  }

  function toggle() {
    if (opened) close()
    else open("")
  }

  QtObject {
    id: pickHost
    readonly property var service: root.service
    readonly property color foreground: Color.foreground
    readonly property color dim: Qt.darker(Color.foreground, 1.55)
    readonly property color urgent: Color.urgent
    readonly property color accent: Color.accent
    readonly property string fontFamily: Style.font.family
    function t(text, args) { return root.service ? root.service.t(text, args) : text }
  }

  PanelWindow {
    id: window
    visible: root.opened && root.service !== null && root.service.picking
    screen: {
      var name = root.pin ? root.pin.name : ""
      return name ? (Quickshell.screens.find(function(s) { return s.name === name }) || null) : null
    }
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "save-them-all-pick"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    PickView {
      id: view
      anchors.fill: parent
      host: pickHost
      origin: root.pin ? ({ x: root.pin.x, y: root.pin.y }) : ({ x: 0, y: 0 })
      workspace: root.pin ? root.pin.workspace : (root.service ? root.service.focusedWorkspace : 0)
    }
  }
}
