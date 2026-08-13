--------------------------------------------------------------------------------
-- helper — thin binding layer mirroring Hyprland's hl.* helpers
--------------------------------------------------------------------------------
--
-- Hyprland uses SUPER (mainMod). omniwm already owns SUPER->Hyper on macOS for
-- window management, so these app/menu binds share the same Hyper chord
-- (Control+Option+Command) to stay consistent and avoid clashing with native
-- Command shortcuts.

-- Global modifier tables, analogous to Hyprland's mainMod.
_G.mainMod = { "ctrl", "alt", "cmd" }        -- Hyper  == Hyprland SUPER

-- exec_cmd(cmd): run a shell command detached, like hl.dsp.exec_cmd.
-- Runs through the login shell so PATH/`open` resolve as in a terminal.
local function exec_cmd(cmd)
  return function()
    hs.execute(cmd, true) -- true => wrap in the user's $SHELL -l -c
  end
end

-- bind(mods, key, fn): register a global hotkey, like hl.bind.
local function bind(mods, key, fn)
  hs.hotkey.bind(mods, key, fn)
end

--------------------------------------------------------------------------------
-- Submaps (modal keymaps) — Hammerspoon equivalent of hl.define_submap.
--------------------------------------------------------------------------------
--
-- Hyprland's 3-arg define_submap("name", "reset", fn) auto-exits to "reset"
-- after any child bind fires. We reproduce that with hs.hotkey.modal:
--   * entering shows an hs.alert hint of the available keys
--   * each action exits the modal after firing (auto-reset)
--   * escape exits without acting
--
-- define_submap(name, entryMods, entryKey, builder)
--   builder(m) receives the modal; call m:entry(key, label, fn) to add actions.
local function define_submap(name, entryMods, entryKey, builder)
  local modal = hs.hotkey.modal.new()
  local hints = {}

  -- m:entry(key, label, fn) — add an auto-exiting action to the submap.
  function modal:entry(key, label, fn)
    table.insert(hints, key .. " " .. label)
    self:bind({}, key, function()
      fn()
      self:exit()
    end)
  end

  builder(modal)

  -- Escape always leaves the submap.
  modal:bind({}, "escape", function() modal:exit() end)

  function modal:entered()
    hs.alert.show(name .. ":  " .. table.concat(hints, "   |   "), 3)
  end
  function modal:exited()
    hs.alert.closeAll()
  end

  -- Entry hotkey opens the submap.
  bind(entryMods, entryKey, function() modal:enter() end)
  return modal
end

_G.hs_helper = {
  exec_cmd = exec_cmd,
  bind = bind,
  define_submap = define_submap,
}
