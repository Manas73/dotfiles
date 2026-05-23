-----------------
-- MY PROGRAMS --
-----------------

-- Exposed as globals so every keybinds module can use them without re-requiring.

local home = os.getenv("HOME")

_G.terminal    = home .. "/.config/.settings/terminal.sh"
_G.fileManager = home .. "/.config/.settings/file_manager.sh"
_G.menu        = "rofi -show drun -show-icons"
_G.browser     = home .. "/.config/.settings/browser.sh"
