import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

import "bar"
import "osd"
import "notifications"
import "widgets/workspaces"
import "widgets/submap"
import "widgets/clock"
import "widgets/keyboard"
import "widgets/weather"
import "widgets/tray"
import "widgets/notify"
import "widgets/audio"
import "widgets/usage"
import "widgets/tailscale"
import "widgets/vpn"
import "widgets/network"
import "widgets/wifiqr"
import "widgets/speedtest"
import "widgets/bluetooth"
import "widgets/monitor"
import "widgets/power"
import "picker"

ShellRoot {
  id: shell

  property alias bar: bar
  property alias media: media

  function firstPartyServiceFor(id) {
    var key = String(id || "")
    if (key === "media" || key === "omarchy.media") return media
    if (key === "notifications" || key === "omarchy.notifications") return notifications
    return null
  }

  function summon(id, payloadJson) {
    var key = String(id || "")
    if (key === "osd" || key === "omarchy.osd") {
      osd.open(payloadJson)
      return true
    }
    if (key === "wifi-qr" || key === "omarchy.wifiqr") {
      wifiQr.open(payloadJson)
      return true
    }
    if (key === "speedtest" || key === "omarchy.speedtest") {
      speedTest.open(payloadJson)
      return true
    }
    if (key === "picker" || key === "omarchy.picker") {
      var payload = {}
      try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
      picker.openMenu(payload.menu || payload.id || "")
      return true
    }
    return false
  }

  function hide(id) {
    var key = String(id || "")
    if (key === "osd" || key === "omarchy.osd") osd.close()
    else if (key === "wifi-qr" || key === "omarchy.wifiqr") wifiQr.close()
    else if (key === "speedtest" || key === "omarchy.speedtest") speedTest.close()
    else if (key === "picker" || key === "omarchy.picker") picker.close()
  }

  Mpris { id: media; shell: shell }

  Notifications {
    id: notifications
    shell: shell
    screenName: "DP-1"
  }

  Osd { id: osd }

  WifiQr { id: wifiQr; shell: shell }
  SpeedTest { id: speedTest; shell: shell }
  Picker { id: picker; shell: shell }

  Bar {
    id: bar
    shell: shell
    position: "top"
    transparent: false

    leftSection: Row {
      spacing: 0
      Workspaces {
        icons: ({
          "1": "", "2": "", "3": "", "4": "",
          "5": "", "6": "", "7": "", "8": "",
          "default": "󰒅"
        })
      }
      Submap {}
    }

    centerSection: Row {
      spacing: 8
      Clock {
        format: "hh:mm AP"
        formatAlt: "yyyy-MM-dd hh:mm:ss AP"
      }
      KeyboardLayout {}
      Weather {}
    }

    rightSection: Row {
      spacing: 0
      Tray {}
      Notify {}
      Audio {}
      Microphone {}
      // Usage {}
      Tailscale {}
      Vpn {}
      Network {}
      Bluetooth {}
      Monitor {}
      Power {}
    }
  }

  IpcHandler {
    target: "shell"

    function ping(): string { return "ok" }

    function summon(id: string, payloadJson: string): string {
      return shell.summon(id, payloadJson) ? "ok" : "unknown"
    }

    function hide(id: string): void { shell.hide(id) }
  }
}
