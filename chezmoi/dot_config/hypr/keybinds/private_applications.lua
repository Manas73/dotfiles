--------------------------
-- APPLICATION BINDINGS --
--------------------------

local home = os.getenv("HOME")

-- Application launchers
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + D",      hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + B",      hl.dsp.exec_cmd(browser))
hl.bind(mainMod .. " + M",      hl.dsp.exec_cmd(home .. "/.config/.settings/work_messenger.sh"))
hl.bind(mainMod .. " + G",      hl.dsp.exec_cmd(home .. "/.config/.settings/git_client.sh"))

-- Rofi - Simple binds
hl.bind(mainMod .. " + Space",  hl.dsp.exec_cmd("rofi -show drun -show-icons"))
hl.bind(mainMod .. " + Delete", hl.dsp.exec_cmd(home .. "/.config/.settings/powermenu.sh"))

-- Push-to-talk: hold Super+I to record, release to transcribe
hl.bind("SUPER + I", hl.dsp.exec_cmd("voxtype record start"))
hl.bind("SUPER + I", hl.dsp.exec_cmd("voxtype record stop"), { release = true })
