---------------------
-- LOOK AND FEEL --
---------------------

-- See https://wiki.hypr.land/Configuring/Basics/Variables/

-- Match Quickshell [bar] background + background-alpha in shell.toml.
local bar_alpha = 0.70

local function with_alpha(color, alpha)
  local hex = tostring(color):match("rgba%((%x%x%x%x%x%x)") or tostring(color):match("#(%x%x%x%x%x%x)")
  if not hex then return color end
  return string.format("rgba(%s%02x)", hex, math.floor(alpha * 255 + 0.5))
end

local bar_bg = with_alpha(colors.background, bar_alpha)
-- Inactive chips are the same color, more transparent, so the active tab
-- reads as solid without a fill change or a bottom strip.
local bar_bg_inactive = with_alpha(colors.background, 0.4)

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
hl.config({
  general = {
    gaps_in  = 5,
    gaps_out = 10,

    border_size = 2,

    -- Gradient borders are a single space-separated color string.
    ["col.active_border"]   = colors.primary,
    ["col.inactive_border"] = colors.on_secondary,

    -- Resize windows by clicking and dragging on borders and gaps
    resize_on_border = true,

    -- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before enabling
    allow_tearing = false,

    layout = "master",
  },

  -- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
  decoration = {
    rounding = 10,
    rounding_power = 2,

    -- Window transparency
    active_opacity   = 1.0,
    inactive_opacity = 1.0,

    shadow = {
      enabled = true,
      range = 12,
      render_power = 10,
      color = "rgba(1a1a1aee)",
    },

    -- https://wiki.hypr.land/Configuring/Basics/Variables/#blur
    blur = {
      enabled = true,
      size = 10,
      passes = 2,
      vibrancy = 0.5,
      vibrancy_darkness = 0.2,

      popups = true,
      popups_ignorealpha = 0.2,
    },
  },

  -- https://wiki.hypr.land/Configuring/Basics/Variables/#misc
  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo   = true,
    focus_on_activate       = false,
  },

  group = {
    ["col.border_active"]          = colors.primary,
    ["col.border_inactive"]        = colors.outline_variant,
    ["col.border_locked_active"]   = colors.tertiary,
    ["col.border_locked_inactive"] = colors.outline_variant,

    groupbar = {
      enabled       = true,
      font_family   = "JetBrainsMono Nerd Font",
      font_size     = 12,
      font_weight_active   = "bold",
      font_weight_inactive = "normal",
      gradients     = true,
      blur          = true,
      height        = 25,
      priority      = 3,
      render_titles = true,
      scrolling     = false,
      rounding      = 0,
      round_only_edges    = false,
      gradient_rounding   = 8,
      gradient_round_only_edges = false,
      indicator_height    = 0,

      ["col.active"]          = bar_bg,
      ["col.inactive"]        = bar_bg_inactive,
      ["col.locked_active"]   = bar_bg,
      ["col.locked_inactive"] = bar_bg_inactive,
      text_color              = colors.on_surface,
      text_color_inactive     = colors.on_surface_variant,
    },
  },
})

-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
-- Default curves, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/#curves
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1    }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0,    0    }, { 1,    1 } } })
hl.curve("almostLinear",   { type = "bezier", points = { { 0.5,  0.5  }, { 0.75, 1 } } })
hl.curve("quick",          { type = "bezier", points = { { 0.15, 0    }, { 0.1,  1 } } })

-- Default animations
hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })
