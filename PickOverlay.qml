import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons

// The plugin's overlay entry point: the shell loads it when the builder
// summons "Pick on screen", calls open(), and unloads it on hide. It covers
// the focused monitor with PickView and takes the keyboard while it is up.
Item {
  id: root
  property var shell: null
  property var manifest: null
  property var service: null
  property bool opened: false

  function open(payloadJson) {
    opened = true
    Qt.callLater(function() { view.forceActiveFocus() })
  }

  // Hidden by anyone else (the shell, IPC): the builder keeps its draft.
  function close() {
    opened = false
    if (service && service.picking) service.finishPick(false)
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
      var name = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : ""
      return Quickshell.screens.find(function(s) { return s.name === name }) || null
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
      origin: Hyprland.focusedMonitor ? ({ x: Hyprland.focusedMonitor.x, y: Hyprland.focusedMonitor.y }) : ({ x: 0, y: 0 })
    }
  }
}
