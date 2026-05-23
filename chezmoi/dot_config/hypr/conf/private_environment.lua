---------------------------
-- ENVIRONMENT VARIABLES --
---------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XDG_MENU_PREFIX","plasma-")
hl.env("LIBVA_DRIVER_NAME","nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME","nvidia")
hl.env("XCURSOR_SIZE","24")
hl.env("HYPRCURSOR_SIZE","24")

-- Vivladi Hardware Acceleration fix
hl.env("__GL_VRR_ALLOWED" , "0")
hl.env("NVD_BACKEND", "direct")