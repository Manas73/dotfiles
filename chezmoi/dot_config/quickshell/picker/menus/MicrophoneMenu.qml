import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import "../../widgets/audio/Model.js" as AudioModel

Item {
  id: root

  property bool active: false
  readonly property string prompt: "Microphone Device"
  readonly property int initialIndex: items.length > 1 ? 1 : 0
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var source: Pipewire.defaultAudioSource

  readonly property var candidateSources: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n || n.isSink || n.isStream || !AudioModel.isAudioSource(n)) continue
      var name = String(n.name || "")
      if (name === "quickshell" || name.indexOf(".monitor") !== -1) continue
      list.push(n)
    }
    return list
  }

  readonly property var items: buildItems()

  function buildItems() {
    var list = []
    var current = root.source
    if (current) {
      list.push({
        key: "current",
        kind: "select",
        label: AudioModel.nodeLabel(current),
        glyph: AudioModel.sourceGlyph(current),
        current: true,
        nodeId: current.id,
        nodeName: String(current.name || "")
      })
    }
    var muted = current && current.audio ? current.audio.muted : false
    list.push({
      key: "mute",
      kind: "mute",
      label: muted ? "Enable Microphone" : "Disable Microphone",
      glyph: muted ? "󰍬" : "󰍭",
      current: false
    })
    for (var i = 0; i < candidateSources.length; i++) {
      var n = candidateSources[i]
      if (!n || (current && n.id === current.id)) continue
      list.push({
        key: "source-" + n.id,
        kind: "select",
        label: AudioModel.nodeLabel(n),
        glyph: AudioModel.sourceGlyph(n),
        current: false,
        nodeId: n.id,
        nodeName: String(n.name || "")
      })
    }
    return list
  }

  function nodeById(id) {
    for (var i = 0; i < candidateSources.length; i++) {
      if (candidateSources[i] && candidateSources[i].id === id) return candidateSources[i]
    }
    return null
  }

  function activate(item) {
    if (!item) return "close"
    if (item.kind === "mute") {
      if (source && source.audio) source.audio.muted = !source.audio.muted
      return "close"
    }
    var node = nodeById(item.nodeId) || (source && source.id === item.nodeId ? source : null)
    if (!node) return "close"
    Pipewire.preferredDefaultAudioSource = node
    if (node.id !== undefined && node.name) {
      Quickshell.execDetached([Quickshell.shellDir + "/bin/omarchy-audio-input-set-default",
        String(node.id), String(node.name)])
    }
    return "close"
  }

  PwObjectTracker { objects: root.candidateSources }
}
