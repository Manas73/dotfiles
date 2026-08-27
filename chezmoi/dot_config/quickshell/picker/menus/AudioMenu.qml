import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../widgets/audio/Model.js" as AudioModel

Item {
  id: root

  property bool active: false
  readonly property string prompt: "Audio Device"
  readonly property int initialIndex: items.length > 1 ? 1 : 0
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var sink: Pipewire.defaultAudioSink

  readonly property var candidateSinks: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (n && n.isSink && !n.isStream) list.push(n)
    }
    return list
  }

  readonly property var items: buildItems()

  function buildItems() {
    var list = []
    var current = root.sink
    if (current) {
      list.push({
        key: "current",
        kind: "select",
        label: AudioModel.nodeLabel(current),
        glyph: AudioModel.sinkGlyph(current),
        current: true,
        nodeId: current.id,
        nodeName: String(current.name || "")
      })
    }
    var muted = current && current.audio ? current.audio.muted : false
    list.push({
      key: "mute",
      kind: "mute",
      label: muted ? "Enable Audio" : "Disable Audio",
      glyph: muted ? "" : "󰖁",
      current: false
    })
    for (var i = 0; i < candidateSinks.length; i++) {
      var n = candidateSinks[i]
      if (!n || (current && n.id === current.id)) continue
      list.push({
        key: "sink-" + n.id,
        kind: "select",
        label: AudioModel.nodeLabel(n),
        glyph: AudioModel.sinkGlyph(n),
        current: false,
        nodeId: n.id,
        nodeName: String(n.name || "")
      })
    }
    return list
  }

  function nodeById(id) {
    for (var i = 0; i < candidateSinks.length; i++) {
      if (candidateSinks[i] && candidateSinks[i].id === id) return candidateSinks[i]
    }
    return null
  }

  function activate(item) {
    if (!item) return "close"
    if (item.kind === "mute") {
      if (sink && sink.audio) sink.audio.muted = !sink.audio.muted
      return "close"
    }
    var node = nodeById(item.nodeId) || (sink && sink.id === item.nodeId ? sink : null)
    if (!node) return "close"
    Pipewire.preferredDefaultAudioSink = node
    if (node.id !== undefined && node.name) {
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-audio-output-set-default",
        String(node.id), String(node.name)])
    }
    return "close"
  }

  PwObjectTracker { objects: root.candidateSinks }
}
