import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../common"
import "../../common/functions"
import "../../common/widgets"
import "../../services"
import "."

Item {
    id: root
    required property var panelWindow
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
    readonly property var toplevels: ToplevelManager.toplevels
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor((monitor.activeWorkspace?.id - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ?
        ((monitor.height / monitor.scale - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.scale) :
        ((monitor.width / monitor.scale - (monitorData?.reserved?.[0] ?? 0) - (monitorData?.reserved?.[2] ?? 0)) * root.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ?
        ((monitor.width / monitor.scale - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.scale) :
        ((monitor.height / monitor.scale - (monitorData?.reserved?.[1] ?? 0) - (monitorData?.reserved?.[3] ?? 0)) * root.scale)

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property var draggingFromWorkspace: -1
    property var draggingTargetWorkspace: -1

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceGrid.implicitWidth + padding * 2
        implicitHeight: workspaceGrid.implicitHeight + padding * 2
        radius: Appearance.rounding.screenRounding * root.scale + padding
        color: Colours.layer(Appearance.colors.colLayer0, 0)
        border.width: 1
        border.color: Colours.layer(Appearance.colors.colLayer0Border, 0)


        GridLayout { // Workspaces
            id: workspaceGrid

            z: root.workspaceZ
            anchors.centerIn: parent
            rowSpacing: workspaceSpacing
            columnSpacing: workspaceSpacing
            columns: Config.options.overview.columns

            Repeater {
                model: Config.options.overview.rows * Config.options.overview.columns

                Rectangle { // Workspace
                    id: workspace

                    readonly property int rowIndex: Math.floor(index / Config.options.overview.columns)
                    readonly property int colIndex: index % Config.options.overview.columns
                    readonly property int workspaceValue: root.workspaceGroup * workspacesShown + index + 1

                    property color defaultWorkspaceColor: Colours.layer(Appearance.colors.colLayer1, 1)
                    property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                    property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                    property bool hoveredWhileDragging: false

                    implicitWidth: root.workspaceImplicitWidth
                    implicitHeight: root.workspaceImplicitHeight
                    color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                    radius: Appearance.rounding.screenRounding * root.scale
                    border.width: 2
                    border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                    StyledText {
                        anchors.centerIn: parent
                        text: NumberUtils.toRoman(workspaceValue)
                        font {
                            pixelSize: root.workspaceNumberSize * root.scale
                            weight: Font.DemiBold
                            family: Appearance.font.family.expressive
                        }
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        id: workspaceArea
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (root.draggingTargetWorkspace === -1) {
                                GlobalStates.overviewOpen = false
                                // Exit scratchpad mode when clicking normal workspace
                                Hyprland.dispatch(`exec sh -c "mkdir -p ~/.cache/caelestia && echo normal > ~/.cache/caelestia/workspace-mode"`)
                                Hyprland.dispatch(`workspace ${workspaceValue}`)
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            root.draggingTargetWorkspace = workspaceValue
                            if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                            hoveredWhileDragging = true
                        }
                        onExited: {
                            hoveredWhileDragging = false
                            if (root.draggingTargetWorkspace == workspaceValue) root.draggingTargetWorkspace = -1
                        }
                    }
                }
            }
        }

        // Special Workspaces Section
        Grid {
            id: specialWorkspacesGrid
            z: root.workspaceZ  // Same as normal workspaces; windows will be above
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: workspaceGrid.bottom
            anchors.topMargin: workspaceSpacing * 3
            columns: 4
            rows: 2
            spacing: workspaceSpacing
            visible: Config.options.overview.showSpecialWorkspaces

            Repeater {
                model: Config.options.overview.specialWorkspaceCount

                Rectangle { // Special Workspace
                    id: specialWorkspace
                    required property int index

                    readonly property int workspaceNum: index + 1  // 1-based indexing
                    readonly property string workspaceName: `special:${workspaceNum}`
                    readonly property string displayName: NumberUtils.toRoman(workspaceNum)

                    property color defaultWorkspaceColor: Colours.layer(Appearance.colors.colLayer1, 1)
                    property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                    property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                    property bool hoveredWhileDragging: false

                    implicitWidth: root.workspaceImplicitWidth * 0.7
                    implicitHeight: root.workspaceImplicitHeight * 0.7
                    color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                    radius: Appearance.rounding.screenRounding * root.scale
                    border.width: 2
                    border.color: hoveredWhileDragging ? hoveredBorderColor : Qt.rgba(0, 0, 0, 0)

                    StyledText {
                        anchors.centerIn: parent
                        text: displayName
                        font {
                            pixelSize: root.workspaceNumberSize * root.scale * 0.5
                            weight: Font.DemiBold
                            family: Appearance.font.family.expressive
                        }
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: {
                            if (root.draggingTargetWorkspace === -1) {
                                GlobalStates.overviewOpen = false
                                const specialNum = workspaceName.slice("special:".length);
                                // Enter scratchpad mode and navigate by updating state files directly
                                Hyprland.dispatch(`exec sh -c "mkdir -p ~/.cache/caelestia && echo scratchpad > ~/.cache/caelestia/workspace-mode && echo ${specialNum} > ~/.cache/caelestia/scratchpad-current && hyprctl dispatch workspace special:${specialNum}"`)
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        onEntered: {
                            root.draggingTargetWorkspace = workspaceName
                            if (root.draggingFromWorkspace == root.draggingTargetWorkspace) return;
                            hoveredWhileDragging = true
                        }
                        onExited: {
                            hoveredWhileDragging = false
                            if (root.draggingTargetWorkspace == workspaceName) root.draggingTargetWorkspace = -1
                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceGrid.implicitWidth
            implicitHeight: workspaceGrid.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel.address}`
                            var win = windowByAddress[address]
                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown)
                            const inSpecialWorkspace = win?.workspace?.name?.startsWith("special:")
                            return inWorkspaceGroup || inSpecialWorkspace;
                        }).sort((a, b) => {
                            // Proper stacking order based on Hyprland's window properties
                            const addrA = `0x${a.HyprlandToplevel.address}`
                            const addrB = `0x${b.HyprlandToplevel.address}`
                            const winA = windowByAddress[addrA]
                            const winB = windowByAddress[addrB]

                            // 1. Pinned windows are always on top
                            if (winA?.pinned !== winB?.pinned) {
                                return winA?.pinned ? 1 : -1
                            }

                            // 2. Floating windows above tiled windows
                            if (winA?.floating !== winB?.floating) {
                                return winA?.floating ? 1 : -1
                            }

                            // 3. Within same category, sort by focus history
                            // Lower focusHistoryID = more recently focused = higher in stack
                            return (winB?.focusHistoryID ?? 0) - (winA?.focusHistoryID ?? 0)
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    required property int index
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id === monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    windowData: windowByAddress[address]
                    toplevel: modelData
                    monitorData: monitor

                    // Calculate scale relative to window's source monitor
                    property real sourceMonitorWidth: (monitor?.transform % 2 === 1) ?
                        (monitor?.height ?? 1920) / (monitor?.scale ?? 1) - (monitor?.reserved?.[0] ?? 0) - (monitor?.reserved?.[2] ?? 0) :
                        (monitor?.width ?? 1920) / (monitor?.scale ?? 1) - (monitor?.reserved?.[0] ?? 0) - (monitor?.reserved?.[2] ?? 0)
                    property real sourceMonitorHeight: (monitor?.transform % 2 === 1) ?
                        (monitor?.width ?? 1080) / (monitor?.scale ?? 1) - (monitor?.reserved?.[1] ?? 0) - (monitor?.reserved?.[3] ?? 0) :
                        (monitor?.height ?? 1080) / (monitor?.scale ?? 1) - (monitor?.reserved?.[1] ?? 0) - (monitor?.reserved?.[3] ?? 0)

                    // Local override to update UI immediately on drop, preventing visual glitches
                    property var overrideWorkspaceName: null

                    readonly property string effectiveWorkspaceName: overrideWorkspaceName !== null ? overrideWorkspaceName.toString() : (windowData?.workspace?.name ?? "")

                    readonly property int effectiveWorkspaceId: {
                        if (overrideWorkspaceName !== null) {
                            if (effectiveWorkspaceName.startsWith("special:")) return -99;
                            return parseInt(effectiveWorkspaceName) || -1;
                        }
                        return windowData?.workspace?.id ?? -1;
                    }

                    // Scale windows to fit the workspace size, accounting for different monitor sizes
                    readonly property bool isInSpecialWorkspace: effectiveWorkspaceName.startsWith("special:")
                    readonly property real targetWorkspaceWidth: isInSpecialWorkspace ? root.workspaceImplicitWidth * 0.7 : root.workspaceImplicitWidth
                    readonly property real targetWorkspaceHeight: isInSpecialWorkspace ? root.workspaceImplicitHeight * 0.7 : root.workspaceImplicitHeight

                    scale: Math.min(
                        targetWorkspaceWidth / sourceMonitorWidth,
                        targetWorkspaceHeight / sourceMonitorHeight
                    )

                    availableWorkspaceWidth: targetWorkspaceWidth
                    availableWorkspaceHeight: targetWorkspaceHeight
                    widgetMonitorId: root.monitor.id

                    property bool atInitPosition: (initX == x && initY == y)

                    property int workspaceColIndex: (effectiveWorkspaceId - 1) % Config.options.overview.columns
                    property int workspaceRowIndex: Math.floor((effectiveWorkspaceId - 1) % root.workspacesShown / Config.options.overview.columns)

                    // Calculate special workspace grid position
                    property int specialWorkspaceIndex: {
                        if (!isInSpecialWorkspace) return -1;
                        const wsName = effectiveWorkspaceName;
                        if (!wsName) return -1;
                        const num = parseInt(wsName.slice("special:".length));
                        return isNaN(num) ? -1 : num - 1;  // 0-based index
                    }

                    property int specialWorkspaceCol: specialWorkspaceIndex === -1 ? 0 : specialWorkspaceIndex % 4
                    property int specialWorkspaceRow: specialWorkspaceIndex === -1 ? 0 : Math.floor(specialWorkspaceIndex / 4)

                    // Use simple, constant offsets like normal workspaces
                    readonly property real normalWSOffsetX: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    readonly property real normalWSOffsetY: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex

                    readonly property real specialWSTileSize: root.workspaceImplicitWidth * 0.7
                    readonly property real specialWSGridStartY: workspaceGrid.implicitHeight + workspaceSpacing * 3
                    readonly property real specialWS4TileWidth: 4 * specialWSTileSize + 3 * workspaceSpacing
                    readonly property real specialWSGridStartX: (workspaceGrid.implicitWidth  - specialWS4TileWidth) / 2

                    readonly property real specialWSOffsetX: specialWSGridStartX + specialWorkspaceCol * (specialWSTileSize + workspaceSpacing)
                    readonly property real specialWSOffsetY: specialWSGridStartY + specialWorkspaceRow * (specialWSTileSize + workspaceSpacing)

                    xOffset: isInSpecialWorkspace ? specialWSOffsetX : normalWSOffsetX
                    yOffset: isInSpecialWorkspace ? specialWSOffsetY : normalWSOffsetY

                    readonly property int targetWindowWidth: windowData ? windowData.size[0] * scale : 0
                    readonly property int targetWindowHeight: windowData ? windowData.size[1] * scale : 0

                    // Calculate relative window position
                    // We can just use the actual relative position now because we will apply the correct scale factor
                    readonly property int windowRelativeX: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)), 0)

                    readonly property int windowRelativeY: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)), 0)

                    // Use window.scale (delegate scale) instead of root.scale (global scale)
                    // window.scale automatically accounts for the 0.7x factor in special workspaces, preventing overflow
                    readonly property int initX: Math.round(windowRelativeX * window.scale + xOffset)
                    readonly property int initY: Math.round(windowRelativeY * window.scale + yOffset)

                    // Explicitly override width/height to ensure they follow the local scale, fixing dimension overflow
                    width: Math.min((windowData?.size[0] ?? 100) * window.scale, targetWorkspaceWidth)
                    height: Math.min((windowData?.size[1] ?? 100) * window.scale, targetWorkspaceHeight)

                    // Position is set in OverviewWindow.qml's Component.onCompleted to avoid animation on first render

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(windowRelativeX * window.scale + xOffset)
                            window.y = Math.round(windowRelativeY * window.scale + yOffset)
                        }
                    }

                    z: atInitPosition ? (root.windowZ + index) : root.windowDraggingZ
                    Drag.hotSpot.x: targetWindowWidth / 2
                    Drag.hotSpot.y: targetWindowHeight / 2
                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true
                        onExited: hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        drag.target: parent
                        onPressed: (mouse) => {
                            root.draggingFromWorkspace = effectiveWorkspaceName.startsWith("special:") ? effectiveWorkspaceName : effectiveWorkspaceId
                            window.pressed = true
                            window.Drag.active = true
                            window.Drag.source = window
                            window.Drag.hotSpot.x = mouse.x
                            window.Drag.hotSpot.y = mouse.y
                        }
                        onReleased: {
                            const targetWorkspace = root.draggingTargetWorkspace
                            window.pressed = false
                            window.Drag.active = false
                            const currentWorkspaceName = effectiveWorkspaceName
                            const currentWorkspaceId = effectiveWorkspaceId
                            const currentWorkspace = currentWorkspaceName.startsWith("special:") ? currentWorkspaceName : currentWorkspaceId
                            root.draggingTargetWorkspace = -1
                            root.draggingFromWorkspace = -1

                            // Check if we actually moved to a different workspace
                            if (targetWorkspace !== -1 && targetWorkspace !== currentWorkspace && targetWorkspace !== "") {
                                // Set optimistic override to prevent visual glitches while waiting for Hyprland
                                window.overrideWorkspaceName = targetWorkspace.toString()

                                // Check if target is a special workspace (will be a string starting with "special:")
                                if (typeof targetWorkspace === 'string' && targetWorkspace.startsWith('special:')) {
                                    const specialName = targetWorkspace.slice("special:".length);
                                    Hyprland.dispatch(`movetoworkspacesilent special:${specialName},address:${window.windowData?.address}`)
                                    // FORCE GEOMETRY UPDATE FOR TARGET TOO
                                    // This forces Hyprland to re-calculate layout (e.g. tile/center instead of fullscreen)
                                    Hyprland.dispatch(`resizewindowpixel exact 0 0,address:${window.windowData?.address}`)
                                } else {
                                    Hyprland.dispatch(`movetoworkspacesilent ${targetWorkspace},address:${window.windowData?.address}`)

                                    // If moving FROM a special workspace, force geometry/layout update
                                    // This is CRITICAL because windows in invisible special workspaces often have stale/minimized geometry
                                    if (windowData?.workspace?.name?.startsWith("special:")) {
                                        // Activate the workspace to trigger layout
                                        Hyprland.dispatch(`workspace ${targetWorkspace}`)
                                        // Force tiling recalculation - resizewindowpixel with exact and 0,0 triggers layout update
                                        Hyprland.dispatch(`resizewindowpixel exact 0 0,address:${window.windowData?.address}`)
                                    }
                                }
                                updateWindowPosition.restart()
                            }
                            else {
                                window.x = window.initX
                                window.y = window.initY
                            }
                        }
                        onClicked: (event) => {
                            if (!windowData) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false

                                // Update mode state based on workspace type
                                const wsName = effectiveWorkspaceName;
                                if (wsName && wsName.startsWith("special:")) {
                                    // Enter scratchpad mode
                                    const specialNum = wsName.slice("special:".length);
                                    Hyprland.dispatch(`exec sh -c "mkdir -p ~/.cache/caelestia && echo scratchpad > ~/.cache/caelestia/workspace-mode && echo ${specialNum} > ~/.cache/caelestia/scratchpad-current"`)
                                } else {
                                    // Exit scratchpad mode
                                    Hyprland.dispatch(`exec sh -c "mkdir -p ~/.cache/caelestia && echo normal > ~/.cache/caelestia/workspace-mode"`)
                                }

                                Hyprland.dispatch(`focuswindow address:${windowData.address}`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`closewindow address:${windowData.address}`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active
                            text: `${windowData?.title ?? "Unknown"}\n[${windowData?.class ?? "unknown"}] ${windowData?.xwayland ? "[XWayland] " : ""}`
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int activeWorkspaceInGroup: monitor.activeWorkspace?.id - (root.workspaceGroup * root.workspacesShown)
                property int activeWorkspaceRowIndex: Math.floor((activeWorkspaceInGroup - 1) / Config.options.overview.columns)
                property int activeWorkspaceColIndex: (activeWorkspaceInGroup - 1) % Config.options.overview.columns
                x: (root.workspaceImplicitWidth + workspaceSpacing) * activeWorkspaceColIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * activeWorkspaceRowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                radius: Appearance.rounding.screenRounding * root.scale
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }
        }
    }
}
