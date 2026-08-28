-----------------
-- LAYER RULES --
-----------------

-- Quickshell bar + widget panels (namespace `quickshell`).
-- ignore_alpha 0.2 skips the fully-transparent overlay around a panel card
-- so only the tinted fill (alpha 0.4) gets blur.
-- blur_popups covers xdg-popups spawned by that layer (tray right-click
-- menus, Qt dropdowns) — those are not layers of their own, so `blur`
-- alone never reaches them.
hl.layer_rule({
  name         = "quickshell-blur",
  match        = { namespace = "quickshell" },
  blur         = true,
  blur_popups  = true,
  ignore_alpha = 0.2,
})

-- Rofi blur
hl.layer_rule({
  name      = "rofi-blur",
  match     = { namespace = "rofi" },
  blur      = true,
  animation = "popin 95%",
})

-- copyq blur
hl.layer_rule({
  name         = "copyq",
  match        = { class = "com.github.hluk.copyq" },
  blur         = true,
  ignore_alpha = 0.39,
})
