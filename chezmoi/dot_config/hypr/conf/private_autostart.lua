---------------
-- AUTOSTART --
---------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- The old `exec-once = ...` is replaced by binding the hyprland.start event.

hl.on("hyprland.start", function()
  hl.exec_cmd("/usr/lib/pam_kwallet_init")
  hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")
  hl.exec_cmd("waybar")
  hl.exec_cmd("awww-daemon")
  hl.exec_cmd("sleep 0.5 && awww restore")
  hl.exec_cmd("swayosd-server")
  hl.exec_cmd("wl-clip-persist --clipboard regular")
  hl.exec_cmd("copyq --start-server")
  hl.exec_cmd("hyprsunset")
  hl.exec_cmd("solaar --window=hide")

  -- Launch apps (workspace rules will handle placement)
  hl.exec_cmd("slack")
  hl.exec_cmd("rambox --ozone-platform=wayland --enable-features=WaylandWindowDecorations")

  -- Focus on default workspaces (5 then 1)
  hl.exec_cmd("sleep 1 && hyprctl dispatch workspace 5")
  hl.exec_cmd("sleep 1 && hyprctl dispatch workspace 1")
end)
