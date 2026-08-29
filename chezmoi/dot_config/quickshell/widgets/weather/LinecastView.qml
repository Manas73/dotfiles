import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import "Model.js" as Model

Item {
  id: root
  clip: true

  property string viewName: "weather"
  property string location: ""
  property string units: ""
  property bool active: false
  property int refreshMs: 60000
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  property int fontPixelSize: Style.font.bodySmall
  property int cellW: 8
  property int cellH: 16

  readonly property int columns: Math.max(20, Math.floor(width / Math.max(1, cellW)))
  readonly property int rows: Math.max(6, Math.floor(height / Math.max(1, cellH)))

  property var lines: []
  property string statusText: "Fetching…"
  property bool loaded: false

  function refresh() {
    if (!root.active || root.width < 16 || root.height < 16) return
    if (proc.running) {
      proc.running = false
      Qt.callLater(root.refresh)
      return
    }
    proc.command = Model.linecastCommand(Util.bin("omarchy-linecast"), root.viewName, {
      print: true,
      icons: "nerd",
      location: root.location,
      units: root.units
    })
    proc.environment = Model.linecastPrintEnvironment(root.columns, root.rows)
    proc.running = true
    if (!root.loaded) root.statusText = "Fetching…"
  }

  onActiveChanged: {
    if (root.active) sizeDebounce.restart()
    else proc.running = false
  }

  onLocationChanged: if (root.active) sizeDebounce.restart()
  onUnitsChanged: if (root.active) sizeDebounce.restart()
  onWidthChanged: if (root.active) sizeDebounce.restart()
  onHeightChanged: if (root.active) sizeDebounce.restart()

  Timer {
    id: sizeDebounce
    interval: 200
    onTriggered: root.refresh()
  }

  Timer {
    interval: Math.max(5000, root.refreshMs)
    running: root.active
    repeat: true
    onTriggered: root.refresh()
  }

  Process {
    id: proc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.ansiToLines(text)
        if (parsed && parsed.length) {
          root.lines = parsed
          root.loaded = true
          root.statusText = ""
          canvas.requestPaint()
        } else if (!root.loaded) {
          root.statusText = "No " + root.viewName + " data"
        }
      }
    }
    onExited: function(exitCode) {
      if (exitCode === 0 || root.loaded) return
      if (exitCode === 127) root.statusText = "linecast is not installed"
      else root.statusText = "Failed to load " + root.viewName
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent
    antialiasing: false
    renderTarget: Canvas.FramebufferObject
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      if (!ctx) return
      ctx.clearRect(0, 0, width, height)
      var family = root.fontFamily.indexOf(" ") >= 0 ? ("\"" + root.fontFamily + "\"") : root.fontFamily
      var baseFont = root.fontPixelSize + "px " + family
      ctx.textBaseline = "top"
      ctx.textAlign = "left"
      var y = 0
      var rows = root.lines || []
      for (var r = 0; r < rows.length; r++) {
        var x = 0
        var segs = rows[r] || []
        for (var s = 0; s < segs.length; s++) {
          var seg = segs[s]
          var text = seg && seg.text ? String(seg.text) : ""
          if (!text) continue
          ctx.font = (seg.bold ? "bold " : "") + baseFont
          var w = ctx.measureText(text).width
          if (seg.bg) {
            ctx.fillStyle = seg.bg
            ctx.fillRect(x, y, w, root.cellH)
          }
          ctx.fillStyle = seg.fg || root.foreground
          ctx.fillText(text, x, y)
          x += w
        }
        y += root.cellH
        if (y > height) break
      }
    }
  }

  Text {
    visible: !root.loaded
    anchors.left: parent.left
    anchors.top: parent.top
    text: root.statusText
    color: Qt.darker(root.foreground, 1.5)
    font.family: root.fontFamily
    font.pixelSize: root.fontPixelSize
    font.italic: true
  }
}
