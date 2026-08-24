---------------------------
-- ENVIRONMENT VARIABLES --
---------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

do
	local home = os.getenv("HOME") or ""
	local path = os.getenv("PATH") or "/usr/bin"
	hl.env("PATH", home .. "/.config/quickshell/bin:" .. path)
end

hl.env("XDG_MENU_PREFIX", "plasma-")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Prevent dpms from triggerring on monitor removal
hl.env("WLR_NO_HARDWARE_CURSORS", "1")

-- Vivladi Hardware Acceleration fix
hl.env("__GL_VRR_ALLOWED", "0")
hl.env("NVD_BACKEND", "direct")

