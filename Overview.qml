import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "model/OverviewModel.js" as OverviewModel

// Fullscreen 2x2 map of the occupied workspaces.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool entering: false
  property bool closingFromHost: false
  property var targetScreen: null
  property int selectedIndex: -1
  property var workspaceIds: []
  property double lastStepAt: 0

  readonly property real mapScale: root.opened && !root.entering ? 1 : 1.12
  readonly property real mapOpacity: root.opened && !root.entering ? 1 : 0
  readonly property int hintHeight: Style.space(36)
  readonly property real mapMargin: Style.space(36)
  readonly property real cellGap: Style.space(18)
  readonly property real mapWidth: Math.max(1, panel.width - root.mapMargin * 2)
  readonly property real mapHeight: Math.max(1, panel.height - root.mapMargin * 2 - root.hintHeight)
  readonly property real cellWidth: (mapWidth - root.cellGap) / OverviewModel.GRID_COLUMNS
  readonly property real cellHeight: (mapHeight - root.cellGap) / OverviewModel.VISIBLE_ROWS

  function pluginId() {
    return (root.manifest && root.manifest.id) ? root.manifest.id : "mpb.workspace-overview"
  }

  function targetScreenForOpen() {
    var screens = Quickshell.screens || []
    var focused = Hyprland.focusedMonitor
    for (var i = 0; i < screens.length; i++) {
      var monitor = Hyprland.monitorFor(screens[i])
      if (focused && monitor === focused)
        return screens[i]
      if (focused && String(screens[i].name || "") === String(focused.name || ""))
        return screens[i]
    }
    return screens.length > 0 ? screens[0] : null
  }

  function liveOccupiedIds() {
    var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var raw = []
    for (var i = 0; i < workspaces.length; i++) {
      var workspace = workspaces[i]
      if (!workspace)
        continue
      var toplevels = workspace.toplevels ? workspace.toplevels.values : []
      raw.push({ id: workspace.id, windowCount: toplevels.length })
    }
    return OverviewModel.occupiedWorkspaceIds(raw)
  }

  function snapshotDesks() {
    root.workspaceIds = OverviewModel.exposeWorkspaceIds([], root.liveOccupiedIds())
  }

  function workspaceById(workspaceId) {
    var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var want = Number(workspaceId)
    for (var i = 0; i < workspaces.length; i++) {
      if (workspaces[i] && Number(workspaces[i].id) === want)
        return workspaces[i]
    }
    return null
  }

  function cellForWorkspace(workspaceId) {
    var workspace = root.workspaceById(workspaceId)
    if (!workspace) {
      return {
        workspaceId: Number(workspaceId),
        focused: false,
        monitorName: "",
        canvas: OverviewModel.monitorCanvas(null),
        toplevels: [],
        windows: []
      }
    }
    var toplevels = workspace.toplevels ? workspace.toplevels.values : []
    var monitor = workspace.monitor
    return {
      workspaceId: Number(workspaceId),
      focused: !!workspace.focused,
      monitorName: monitor ? String(monitor.name || "") : "",
      canvas: OverviewModel.monitorCanvas(monitor),
      toplevels: toplevels,
      windows: OverviewModel.windowsFromToplevels(toplevels)
    }
  }

  function indexOfFocused() {
    for (var i = 0; i < root.workspaceIds.length; i++) {
      var workspace = root.workspaceById(root.workspaceIds[i])
      if (workspace && workspace.focused)
        return i
    }
    return root.workspaceIds.length > 0 ? 0 : -1
  }

  function open(payloadJson) {
    root.targetScreen = root.targetScreenForOpen()
    root.entering = true
    root.workspaceIds = []
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.snapshotDesks()
    root.selectedIndex = root.indexOfFocused()
    root.opened = true
    Qt.callLater(root.finishOpen)
  }

  function finishOpen() {
    if (!root.opened)
      return
    root.snapshotDesks()
    root.selectedIndex = root.indexOfFocused()
    root.entering = false
    root.lastStepAt = 0
    if (scroller)
      scroller.contentY = 0
    keyCatcher.forceActiveFocus()
    root.revealIndex(root.selectedIndex)
  }

  function close() {
    root.closingFromHost = true
    root.opened = false
    root.entering = false
    root.targetScreen = null
    root.selectedIndex = -1
    root.workspaceIds = []
    root.closingFromHost = false
  }

  function toggle() {
    if (root.opened)
      root.requestClose()
    else
      root.open("{}")
  }

  function requestClose() {
    if (root.closingFromHost)
      return
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId())
    else
      root.opened = false
  }

  function dispatchAndClose(request) {
    if (request === "") return
    Hyprland.dispatch(request)
    root.requestClose()
  }

  function focusWindow(address) {
    root.dispatchAndClose(OverviewModel.focusDispatch(address))
  }

  function focusWorkspace(workspaceId) {
    root.dispatchAndClose(OverviewModel.workspaceFocusDispatch(workspaceId))
  }

  function activateSelected() {
    if (root.selectedIndex < 0 || root.selectedIndex >= root.workspaceIds.length)
      return
    root.focusWorkspace(root.workspaceIds[root.selectedIndex])
  }

  function moveSelection(dx, dy) {
    root.selectedIndex = OverviewModel.moveIndex(root.selectedIndex, dx, dy, root.workspaceIds.length)
    root.revealIndex(root.selectedIndex)
  }

  function revealIndex(index) {
    if (!scroller || index < 0)
      return
    scroller.contentY = OverviewModel.revealScrollY(
      index,
      scroller.contentY,
      root.cellHeight,
      root.cellGap,
      scroller.contentHeight,
      scroller.height
    )
  }

  function scrollByWheel(pixelY, angleY) {
    var delta = OverviewModel.wheelDelta(pixelY, angleY)
    if (delta === 0)
      return
    var now = Date.now()
    if (now - root.lastStepAt < 180)
      return
    root.lastStepAt = now
    scroller.contentY = OverviewModel.stepScrollY(
      scroller.contentY,
      root.cellHeight,
      root.cellGap,
      scroller.contentHeight,
      scroller.height,
      delta > 0 ? 1 : -1
    )
  }

  function handleKey(event) {
    if (event.key === Qt.Key_Escape) {
      root.requestClose()
    } else if (event.key === Qt.Key_Left) {
      root.moveSelection(-1, 0)
    } else if (event.key === Qt.Key_Right) {
      root.moveSelection(1, 0)
    } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
      root.moveSelection(0, -1)
    } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
      root.moveSelection(0, 1)
    } else if (event.key === Qt.Key_PageUp) {
      root.selectedIndex = OverviewModel.pageUp(root.selectedIndex, root.workspaceIds.length)
      root.revealIndex(root.selectedIndex)
    } else if (event.key === Qt.Key_PageDown) {
      root.selectedIndex = OverviewModel.pageDown(root.selectedIndex, root.workspaceIds.length)
      root.revealIndex(root.selectedIndex)
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      root.activateSelected()
    } else if (event.text >= "0" && event.text <= "9") {
      root.focusWorkspace(OverviewModel.workspaceIdFromDigit(event.text))
    } else {
      return
    }
    event.accepted = true
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (!root.opened)
        return
      var screens = Quickshell.screens || []
      if (!root.targetScreen || screens.indexOf(root.targetScreen) === -1) {
        root.targetScreen = root.targetScreenForOpen()
        if (!root.targetScreen)
          root.requestClose()
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    screen: root.targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "mpb-workspace-overview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Color.menu.scrim
      opacity: root.mapOpacity
    }

    WheelArea {
      onActivated: root.requestClose()
      onWheelMoved: function (pixelY, angleY) { root.scrollByWheel(pixelY, angleY) }
    }

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      opacity: root.mapOpacity
      scale: root.mapScale
      transformOrigin: Item.Center

      Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }
      Behavior on scale {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
      }

      Keys.onPressed: root.handleKey

      Item {
        id: scroller
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.mapMargin
        anchors.rightMargin: root.mapMargin
        anchors.topMargin: root.mapMargin
        height: root.mapHeight
        clip: true

        property real contentY: 0
        readonly property real contentHeight: Math.max(
          height,
          OverviewModel.mapContentHeight(root.workspaceIds.length, root.cellHeight, root.cellGap)
        )

        Behavior on contentY {
          NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        Item {
          width: parent.width
          height: scroller.contentHeight
          y: -scroller.contentY

          Grid {
            width: parent.width
            columns: OverviewModel.GRID_COLUMNS
            columnSpacing: root.cellGap
            rowSpacing: root.cellGap

            Repeater {
              model: root.workspaceIds

              WorkspaceTile {
                required property int modelData
                required property int index
                width: root.cellWidth
                height: root.cellHeight
                cell: root.cellForWorkspace(modelData)
                selected: root.selectedIndex === index
                live: root.opened
                overlayMonitorName: root.targetScreen ? String(root.targetScreen.name || "") : ""
                onActivateWorkspace: root.focusWorkspace(modelData)
                onActivateWindow: function (address) { root.focusWindow(address) }
                onWheelMoved: function (pixelY, angleY) { root.scrollByWheel(pixelY, angleY) }
              }
            }
          }
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(14)
        text: root.workspaceIds.length > OverviewModel.pageSize()
          ? "1–0 go  ·  scroll for more  ·  Esc close"
          : "1–0 go  ·  arrows move  ·  Esc close"
        color: Color.menu.text
        opacity: 0.42
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
