import QtQuick
import Quickshell.Wayland

// A picture of one window. Live only while the pointer or the keyboard is on
// it; otherwise a new frame every few seconds. Hyprland draws no frames for
// a card's hidden side, so those keep their last picture, or none.
ScreencopyView {
  id: view
  property var toplevel: null
  captureSource: toplevel ? toplevel.wayland : null
  paintCursor: false
  live: false

  Timer {
    interval: 3000
    repeat: true
    running: !view.live && view.captureSource !== null
    triggeredOnStart: true
    onTriggered: view.captureFrame()
  }
}
