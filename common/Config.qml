pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root
    
    property QtObject options: QtObject {
        property QtObject overview: QtObject {
            property int rows: 2
            property int columns: 4
            property real scale: 0.16
            property bool enable: true
            property bool showSpecialWorkspaces: true
            // Workspace counts from Hyprland configuration
            property int normalWorkspaceCount: 8  // Shown in grid (rows * columns)
            property int specialWorkspaceCount: 8  // From hyprland/scratchpad-workspaces.conf
        }
        
        property QtObject hacks: QtObject {
            property int arbitraryRaceConditionDelay: 150
        }
    }
}
