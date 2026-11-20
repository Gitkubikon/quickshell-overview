pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Caelestia colours and transparency, read live from the files the Caelestia shell and CLI
// write: ~/.local/state/caelestia/scheme.json and ~/.config/caelestia/shell.json.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string configPath: `${Quickshell.env("XDG_CONFIG_HOME") || `${home}/.config`}/caelestia`
    readonly property string statePath: `${Quickshell.env("XDG_STATE_HOME") || `${home}/.local/state`}/caelestia`

    property bool currentLight
    readonly property M3Palette current: M3Palette {}
    readonly property Transparency transparency: Transparency {}

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    // Same maths as the shell's Colours.layer(), so panels match the drawers
    function alterColour(c: color, a: real, layer: int): color {
        const luminance = getLuminance(c);
        const offset = (!currentLight || layer == 1 ? 1 : -layer / 2) * (currentLight ? 0.2 : 0.3) * (1 - transparency.base);
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));
        return Qt.rgba(r, g, b, a);
    }

    function layer(c: color, layer: var): color {
        if (!transparency.enabled)
            return c;
        return layer === 0 ? Qt.alpha(c, transparency.base) : alterColour(c, transparency.layers, layer ?? 1);
    }

    component Transparency: QtObject {
        property bool enabled: false
        property real configBase: 0.85
        readonly property real base: configBase - (root.currentLight ? 0.1 : 0)
        property real layers: 0.4
    }

    // Only the keys Appearance.qml maps; scheme entries without a matching property are skipped
    component M3Palette: QtObject {
        property bool darkmode: !root.currentLight
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c91"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
    }

    FileView {
        path: `${root.statePath}/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const scheme = JSON.parse(text());
                root.currentLight = scheme.mode === "light";
                for (const [name, colour] of Object.entries(scheme.colours ?? {})) {
                    const prop = `m3${name}`;
                    if (root.current.hasOwnProperty(prop))
                        root.current[prop] = `#${colour}`;
                }
            } catch (e) {
                console.warn("Colours: cannot parse scheme.json:", e);
            }
        }
    }

    FileView {
        path: `${root.configPath}/shell.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const t = JSON.parse(text()).appearance?.transparency ?? {};
                root.transparency.enabled = t.enabled ?? false;
                root.transparency.configBase = t.base ?? 0.85;
                root.transparency.layers = t.layers ?? 0.4;
            } catch (e) {
                console.warn("Colours: cannot parse shell.json:", e);
            }
        }
    }
}
