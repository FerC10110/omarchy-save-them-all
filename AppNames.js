// A readable name and an icon for a window. Hyprland knows a window by its
// class, which is an address, not a name: a webapp is
// chrome-host__path-Default and a GNOME app is org.gnome.Calculator. The
// desktop entries hold the real names. In order:
//   1. an Omarchy webapp: the entry whose Exec=omarchy-launch-webapp URL makes
//      that class (or the URL Save Them All saved in launch.url);
//   2. an entry whose StartupWMClass, or whose id, is the class;
//   3. an unknown webapp: its host; a reverse-DNS class: its last part;
//   4. the class itself.
//
// entries: [{ id, name, icon, startupClass, exec }], from Quickshell's
// DesktopEntries in QML or from tests/fixtures in node. No QML in here.

// https://host/a/b?x -> chrome-host__a_b-Default, as Chromium names a webapp
// (the same rule as url_class in bin/save-them-all).
function urlClass(url) {
  var u = String(url || "").replace(/^[^:\/]*:\/\//, "")
  u = u.split("?")[0].split("#")[0]
  var slash = u.indexOf("/")
  var host = slash < 0 ? u : u.substring(0, slash)
  var path = slash < 0 ? "" : u.substring(slash + 1)
  return "chrome-" + host + "__" + path.split("/").join("_") + "-Default"
}

// The URL an Exec line opens as a webapp, or "". An Exec line writes a
// literal % as %%.
function webappUrl(exec) {
  var m = /^omarchy-launch-webapp\s+"?([^"\s]+)"?/.exec(String(exec || ""))
  return m ? m[1].replace(/%%/g, "%") : ""
}

function found(entry, source) {
  return { name: String(entry.name || ""), icon: String(entry.icon || ""), source: source }
}

function resolve(win, entries) {
  var cls = String((win && win["class"]) || "")
  var launch = win && win.launch
  var list = entries || []
  var web = launch && launch.kind === "webapp" && launch.url ? urlClass(launch.url) : cls
  if (/^chrome-.+-Default$/.test(web)) {
    for (var i = 0; i < list.length; i++) {
      var url = webappUrl(list[i].exec)
      if (url !== "" && urlClass(url) === web) return found(list[i], "webapp")
    }
  }
  var lower = cls.toLowerCase()
  if (lower !== "") {
    for (var j = 0; j < list.length; j++)
      if (String(list[j].startupClass || "").toLowerCase() === lower) return found(list[j], "entry")
    for (var k = 0; k < list.length; k++)
      if (String(list[k].id || "").replace(/\.desktop$/, "").toLowerCase() === lower) return found(list[k], "entry")
  }
  var host = /^chrome-([^_]+)__.*-Default$/.exec(web)
  if (host) return { name: host[1], icon: "", source: "class" }
  var parts = cls.split(".")
  if (parts.length >= 3 && parts[parts.length - 1] !== "")
    return { name: parts[parts.length - 1], icon: "", source: "class" }
  return { name: cls, icon: "", source: "raw" }
}

if (typeof module !== "undefined") {
  module.exports = { urlClass: urlClass, webappUrl: webappUrl, resolve: resolve }
}
