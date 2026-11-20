# Caelestia Overview

A Hyprland workspace overview for Quickshell, tuned for the [Caelestia](https://github.com/caelestia-dots) shell setup. Shows all workspaces with live window previews, drag-and-drop, a special-workspace (scratchpad) strip, layered transparency, and Roman-numeral workspace numbering.

Forked from [Shanu-Kumawat/quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview), itself extracted from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland).

---

## Preview

![Overview Screenshot](assets/image.png)

> Workspace overview with live previews and drag-and-drop. Screenshot is from upstream and may not reflect current Caelestia theming.

---

## What this fork adds

Everything upstream does, plus:

- Colors read live from Caelestia's scheme file (`~/.local/state/caelestia/scheme.json`), watched
  with `FileView` — this replaces upstream's `caelestia scheme get` polling for `colorSource: "caelestia"`
- Transparency read from Caelestia (`~/.config/caelestia/shell.json` → `appearance.transparency`)
- Layered transparency via `Colours.layer()` — backgrounds, panels, and tiles tint coherently;
  when Caelestia transparency is off, upstream's flat opacity/glass effects apply instead
- Roman-numeral labels for workspaces (I, II, III, …)
- WlrLayer namespace `caelestia-overview` (Caelestia's Hyprland layerrules blur/tint it)
- `WlrLayershell.exclusionMode: ExclusionMode.Ignore`
- Hot-corner exit calls back into the main `caelestia` IPC (`qs ipc -c caelestia call hotcorner ignore`)
- Defaults tuned for this setup: 2x4 grid, `colorSource: "caelestia"`, empty rows never collapse

## Installation

### Prerequisites

- Hyprland
- Quickshell ([install guide](https://quickshell.org/docs/v0.1.0/guide/install-setup/))
- Qt 6 (QtQuick, QtQuick.Controls, QtQuick.Layouts)
- Caelestia shell installed and writing `scheme.json` (only required for live theming — defaults are bundled)

### Setup

1. Link the checkout into your Quickshell config directory:

   ```bash
   ln -s ~/Projects/Caelestia/overview ~/.config/quickshell/overview
   ```

2. Auto-start it (Hyprland Lua config, e.g. `~/.config/caelestia/hypr-user.lua`):

   ```lua
   hl.on("hyprland.start", function()
       hl.exec_cmd("qs -c overview")
   end)
   ```

3. Open it from the Caelestia shell's top-left hot corner, or bind it:

   ```lua
   hl.bind("SUPER + TAB", hl.dsp.exec_cmd("qs ipc -c overview call overview toggle"))
   ```

### Manual start

```bash
qs -c overview &
```

## Usage

| Action | Description |
|---|---|
| Top-left hot corner | Toggle overview (from the Caelestia shell; sliding back into the corner closes it) |
| Arrow keys / `h j k l` | Navigate workspaces |
| `1`–`9`, `0` | Jump to Nth workspace in current group (`0` = 10th) |
| `Escape` / `Enter` | Close overview |
| Click workspace | Switch to it |
| Click window | Focus it |
| Middle-click window | Close it |
| Drag window | Move to another workspace, or onto a scratchpad tile |

## Configuration

Everything is driven by an optional `config.json` next to `shell.qml`
(`~/.config/quickshell/overview/config.json`). It is not tracked by git. Copy
`config.example.json` to start from the documented set of keys; anything absent falls back to
the defaults in `common/Config.qml`.

```json
{
  "overview": {
    "rows": 2,
    "columns": 4,
    "scale": 0.16,
    "hideEmptyRows": false,
    "showSpecialWorkspaces": true
  },
  "position": { "topMargin": 100 },
  "appearance": { "colorSource": "caelestia" }
}
```

Notable keys:

- `overview.scale` — overall size (smaller = more compact)
- `overview.hideEmptyRows` — collapse rows with no windows (this fork defaults to `false`)
- `overview.showSpecialWorkspaces` — show the scratchpad strip
- `overview.specialWorkspaces` — pin scratchpads that should always be shown; by default the
  strip auto-discovers the special workspaces that exist on the current monitor, which is what
  matches Caelestia's per-output `special:<N>-<MONITOR>` naming
- `position.topMargin` — vertical placement of the overview panel
- `appearance.colorSource` — `caelestia` (default here), `matugen`, or `default`

### Theming

Colors come from Caelestia's scheme (`~/.local/state/caelestia/scheme.json`). Without it, the `M3Palette` defaults in `services/Colours.qml` apply.

Transparency is read from `~/.config/caelestia/shell.json`:

```json
{
  "appearance": {
    "transparency": {
      "enabled": true,
      "base": 0.85,
      "layers": 0.4
    }
  }
}
```

`base` controls the root layer alpha; `layers` controls how strongly stacked layers are tinted.
With `enabled: false` the overview falls back to upstream's `overview.effects.*` opacity and
glass options from `config.json`.

## Removed (vs. illogical-impulse)

App search, emoji picker, clipboard history, and integration with the full illogical-impulse shell were all removed upstream to make this standalone.

## File structure

```
overview/
├── shell.qml                       # Entry point
├── config.example.json             # Documented config.json keys
├── quickshell-overview.qml         # matugen template (only used by colorSource: "matugen")
├── common/
│   ├── Appearance.qml              # Color/font/animation roles; picks the color source
│   ├── Config.qml                  # Defaults + config.json loader
│   ├── functions/
│   │   ├── ColorUtils.qml
│   │   └── NumberUtils.qml         # toRoman() for workspace labels
│   └── widgets/                    # StyledText, StyledToolTip, ...
├── services/
│   ├── Colours.qml                 # Caelestia palette + transparency loader
│   ├── GlobalStates.qml            # overviewOpen
│   └── HyprlandData.qml
└── modules/overview/
    ├── Overview.qml                # PanelWindow, key handling, hot corner
    ├── OverviewWidget.qml          # Workspace grid + scratchpad strip
    └── OverviewWindow.qml          # Per-window preview
```

## IPC

```bash
qs ipc -c overview call overview toggle
qs ipc -c overview call overview open
qs ipc -c overview call overview close
```

## Known issues

- Window icons may fall back to a generic icon if the app class doesn't match the icon theme
- Rapid window state changes can briefly produce stale previews — mitigated by Hyprland event-driven re-capture, but not eliminated

## Credits

- Upstream: [Shanu-Kumawat/quickshell-overview](https://github.com/Shanu-Kumawat/quickshell-overview)
- Original: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland)
