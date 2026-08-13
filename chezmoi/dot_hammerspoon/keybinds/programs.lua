--------------------------------------------------------------------------------
-- programs — settings-script paths (mirror of hypr/conf/private_programs.lua)
--------------------------------------------------------------------------------
--
-- Every launcher/menu shells out to a resolved ~/.config/.settings/*.sh script,
-- exactly like Hyprland. Those scripts are chezmoi-rendered per OS/host, so the
-- macOS app (e.g. `open -a Vivaldi`) is chosen there, not here.

local home = os.getenv("HOME")
local settings = home .. "/.config/.settings"

_G.settingsDir = settings

_G.terminal      = settings .. "/terminal.sh"
_G.fileManager   = settings .. "/file_manager.sh"
_G.browser       = settings .. "/browser.sh"
_G.workMessenger = settings .. "/work_messenger.sh"
_G.gitClient     = settings .. "/git_client.sh"
_G.powerMenu     = settings .. "/powermenu.sh"
