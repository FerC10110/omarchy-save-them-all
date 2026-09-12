import QtQuick
import qs.Commons
import qs.Ui

// Bar entry point for Save Them All. The button is a status light as much as a
// button: it only lights up once the active workspace has a saved layout, so a
// glance at the bar answers "can I bring this back?".
//
// Left click opens the panel. Middle click saves the current layout without
// opening anything, because that is the action you repeat most often.
BarWidget {
  id: root
  moduleName: "io.github.ferc10110.save-them-all"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool hasSaved: panelLoader.item ? panelLoader.item.hasSaved === true : false
  readonly property bool busy: panelLoader.item ? panelLoader.item.busy === true : false

  // Forwarded so this widget can stand in for the panel as the bar's popout
  // identity: Bar.requestPopout prefers closeForPopoutSwitch over close, and
  // KeyboardPanel reads popoutSwitchClosing back off its owner.
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function saveNow() {
    if (panelLoader.item) panelLoader.item.save()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󱂬"
    slotSize: Style.bar.statusSlot
    tooltipText: ""
    // Dimmed until this workspace has something to restore, and brought back
    // to full strength while a save or restore is running.
    opacity: root.busy ? 1.0 : (root.hasSaved ? 1.0 : 0.55)

    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.saveNow()
      else root.togglePanel()
    }
  }
}
