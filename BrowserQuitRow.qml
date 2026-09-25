import QtQuick
import qs.Commons
import qs.Ui

// Omarchy's Logout, Reboot and Shutdown close windows one at a time, which
// costs Chromium its tabs. This is the one switch that reaches outside the
// plugin's own files, so it starts off and says so.
Column {
  id: row
  required property var host
  spacing: Style.space(10)

  readonly property bool blocked: host.browserQuit.enabled !== true
    && (host.browserQuit.conflict !== "" || host.browserQuitError !== "")

  readonly property string description: {
    if (host.browserQuitError !== "") return host.browserQuitError
    if (host.browserQuit.enabled !== true && host.browserQuit.conflict !== "")
      return host.t("Your Omarchy menu already changes %1, so this stays off.", [host.browserQuit.conflict])
    return host.t("Before Logout, Reboot and Shutdown, so it brings its tabs back. Edits the Omarchy menu.")
  }

  PanelSeparator { width: parent.width; foreground: row.host.foreground }

  PanelSectionHeader {
    width: parent.width
    text: row.host.t("Leaving the session")
    foreground: row.host.foreground
    fontFamily: row.host.fontFamily
  }

  Toggle {
    width: parent.width
    label: row.host.t("Close the browser cleanly")
    description: row.description
    checked: row.host.browserQuit.enabled === true
    enabled: !row.blocked
    opacity: enabled ? 1 : 0.55
    foreground: row.host.foreground
    fontFamily: row.host.fontFamily
    onClicked: row.host.toggleBrowserQuit()
  }
}
