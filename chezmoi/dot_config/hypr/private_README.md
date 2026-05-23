# Hyprland Configuration

This configuration follows **SOLID principles** for better maintainability and organization.

## Directory Structure

```
~/.config/hypr/
├── hyprland.conf          # Main entry point (sources all modules)
├── conf.d/                # Core configuration modules
│   ├── monitors.conf      # Monitor setup & workspace assignments
│   ├── environment.conf   # Environment variables
│   ├── programs.conf      # Program definitions ($terminal, etc.)
│   ├── autostart.conf     # Startup applications (exec-once)
│   ├── input.conf         # Input devices, keyboard, gestures
│   ├── appearance.conf    # Visual settings (general, decoration, animations)
│   └── layouts.conf       # Window layouts (dwindle, master)
├── keybinds/             # Keybinding modules
│   ├── base.conf         # Core keybindings (kill, float, lock, etc.)
│   ├── applications.conf # App launchers (terminal, browser, etc.)
│   ├── window-mgmt.conf  # Focus, move, resize windows
│   ├── workspaces.conf   # Workspace switching & moving
│   └── submaps.conf      # Rofi menus, IDE selector submaps
├── rules/                # Window and layer rules
│   ├── layer-rules.conf  # Layer rules (rofi, swaync, swayosd blur)
│   └── window-rules.conf # Window rules (app workspaces, float, etc.)
└── colors/               # Theme colors
    └── matugen.conf
```

## SOLID Principles Applied

### Single Responsibility Principle
Each module handles one specific aspect of configuration:
- `monitors.conf` → Monitor setup only
- `keybinds/applications.conf` → Application launchers only
- `rules/window-rules.conf` → Window rules only

### Open/Closed Principle
Easy to extend without modifying existing files:
- Add new keybindings → Create new file in `keybinds/` and source it
- Add new window rules → Append to `rules/window-rules.conf`
- No need to touch the main `hyprland.conf`

### Liskov Substitution Principle
Similar configurations follow the same patterns:
- All keybind files use consistent binding syntax
- All rules follow the same structure

### Interface Segregation Principle
Load only what you need:
- Comment out specific source lines to disable modules
- Each module is independent and optional

### Dependency Inversion Principle
Main config depends on abstractions (sourced modules), not implementation details:
- `hyprland.conf` doesn't contain concrete configurations
- It sources modular files that can be swapped or modified independently

## Making Changes

### Adding New Keybindings
Edit the appropriate file in `keybinds/`:
- General keybinds → `keybinds/base.conf`
- App launchers → `keybinds/applications.conf`
- Window management → `keybinds/window-mgmt.conf`

### Adding New Window Rules
Add rules to `rules/window-rules.conf`

### Modifying Appearance
Edit `conf.d/appearance.conf` for:
- Gaps, borders, colors
- Shadows and blur
- Animations

### Changing Monitors
Edit `conf.d/monitors.conf`

## Reloading Configuration

After making changes, reload Hyprland:
```bash
hyprctl reload
```

Or use the keyboard shortcut if configured.

## Backup

The original monolithic configuration has been preserved as:
- `hyprland.conf.save` (already existed as backup)

## Benefits

- **Easier Navigation**: Find settings quickly by category
- **Reduced Conflicts**: Multiple people can edit different modules
- **Selective Loading**: Disable modules by commenting out source lines
- **Better Version Control**: Git diffs show exactly which category changed
- **Maintainability**: Add/modify features without touching unrelated config
