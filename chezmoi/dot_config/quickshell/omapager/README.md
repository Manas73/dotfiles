# omapager

Vendored from [njpatel/omapager](https://github.com/njpatel/omapager)
(Apache-2.0). Replaces the previous Quickshell notification daemon and
history drawer.

This tree is not loaded as an Omarchy plugin. `shell.qml` instantiates
`Service.qml` as a first-party service and `Widget.qml` in the bar.
Imports use `qs.components` (this shell has no `qs.Commons` / `qs.Ui`).

State lives in `~/.local/state/omarchy/omapager/`. Helpers in `bin/`
are Python 3; `bin/launch` restores `+x` on them.

See [AGENTS.md](AGENTS.md) for layout, IPC, and the things that cost a
day to learn.
