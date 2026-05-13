-----------------
-- LAYER RULES --
-----------------

-- Rofi blur
hl.layer_rule({
  name      = "rofi-blur",
  match     = { namespace = "rofi" },
  blur      = true,
  animation = "popin 95%",
})

-- swaync blur — panel
hl.layer_rule({
  name         = "swaync-control-center",
  match        = { class = "swaync-control-center" },
  blur         = true,
  ignore_alpha = 0.4,
})

-- swaync blur — notification popup
hl.layer_rule({
  name         = "swaync-notification-window",
  match        = { class = "swaync-notification-window" },
  blur         = true,
  ignore_alpha = 0.4,
})

-- swayosd blur
hl.layer_rule({
  name         = "swayosd",
  match        = { class = "swayosd" },
  blur         = true,
  ignore_alpha = 0.39,
})

-- copyq blur
hl.layer_rule({
  name         = "copyq",
  match        = { class = "com.github.hluk.copyq" },
  blur         = true,
  ignore_alpha = 0.39,
})
