import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "model/OverviewModel.js" as OverviewModel

// Fullscreen 2x2 workspace map. Trackpad opens it; number keys leave it.
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

  readonly property real mapScale: root.opened && !root.entering ? 1 : 1.12
  readonly property real mapOpacity: root.opened && !root.entering ? 1 : 0
  readonly property int hintHeight: Style.space(36)
  readonly property real mapMargin: Style.space(36)
  readonly property real cellGap: Style.space(18)

  function pluginId() {
    return (root.manifest && root.manifest.id) ? root.manifest.id : "mpb.workspace-overview"
  }

  function canvasFromMonitor(monitor) {
    if (!monitor)
      return { x: 0, y: 0, width: 0, height: 0 }
    var ipc = monitor.lastIpcObject || {}
    var width = Number(monitor.width !== undefined ? monitor.width : ipc.width) || 0
    var height = Number(monitor.height !== undefined ? monitor.height : ipc.height) || 0
    if (width <= 0 || height <= 0) {
      width = Number(ipc.width) || 0
      height = Number(ipc.height) || 0
    }
    return {
      x: Number(monitor.x !== undefined ? monitor.x : ipc.x) || 0,
      y: Number(monitor.y !== undefined ? monitor.y : ipc.y) || 0,
      width: width,
      height: height
    }
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

  readonly property var workspaceCells: {
    var workspaces = Hyprland.workspaces ? Hyprland.workspaces.values : []
    var raw = []
    var byId = {}
    for (var i = 0; i < workspaces.length; i++) {
      var workspace = workspaces[i]
      if (!workspace)
        continue
      var toplevels = workspace.toplevels ? workspace.toplevels.values : []
      raw.push({ id: workspace.id, windowCount: toplevels.length })
      byId[workspace.id] = { workspace: workspace, toplevels: toplevels }
    }

    var ids = OverviewModel.occupiedWorkspaceIds(raw)
    var cells = []
    for (var j = 0; j < ids.length; j++) {
      var pack = byId[ids[j]]
      var windows = []
      for (var k = 0; k < pack.toplevels.length; k++) {
        var toplevel = pack.toplevels[k]
        var parsed = OverviewModel.windowFromIpc(toplevel && toplevel.lastIpcObject ? toplevel.lastIpcObject : null)
        if (!parsed && toplevel)
          parsed = OverviewModel.windowFromIpc({
            address: toplevel.address,
            at: [0, 0],
            size: [1, 1],
            title: toplevel.title
          })
        if (parsed)
          windows.push(parsed)
      }
      var monitor = pack.workspace.monitor
      cells.push({
        workspaceId: ids[j],
        focused: !!pack.workspace.focused,
        monitorName: monitor ? String(monitor.name || "") : "",
        canvas: root.canvasFromMonitor(monitor),
        toplevels: pack.toplevels,
        windows: windows
      })
    }
    return cells
  }

  function indexOfFocused() {
    for (var i = 0; i < root.workspaceCells.length; i++) {
      if (root.workspaceCells[i].focused)
        return i
    }
    return root.workspaceCells.length > 0 ? 0 : -1
  }

  function open(payloadJson) {
    root.targetScreen = root.targetScreenForOpen()
    root.entering = true
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.selectedIndex = root.indexOfFocused()
    root.opened = true
    Qt.callLater(function () {
      root.entering = false
      if (root.opened)
        keyCatcher.forceActiveFocus()
      root.revealIndex(root.selectedIndex)
    })
  }

  function close() {
    root.closingFromHost = true
    root.opened = false
    root.entering = false
    root.targetScreen = null
    root.selectedIndex = -1
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
    if (root.selectedIndex < 0 || root.selectedIndex >= root.workspaceCells.length)
      return
    root.focusWorkspace(root.workspaceCells[root.selectedIndex].workspaceId)
  }

  function moveSelection(dx, dy) {
    root.selectedIndex = OverviewModel.moveIndex(root.selectedIndex, dx, dy, root.workspaceCells.length)
    root.revealIndex(root.selectedIndex)
  }

  function revealIndex(index) {
    if (!scroller || index < 0)
      return
    var row = Math.floor(index / OverviewModel.GRID_COLUMNS)
    var rowHeight = cellHeight + root.cellGap
    var top = row * rowHeight
    var bottom = top + cellHeight
    if (top < scroller.contentY)
      scroller.contentY = Math.max(0, top)
    else if (bottom > scroller.contentY + scroller.height)
      scroller.contentY = Math.max(0, bottom - scroller.height)
  }

  readonly property real mapWidth: Math.max(1, panel.width - root.mapMargin * 2)
  readonly property real mapHeight: Math.max(1, panel.height - root.mapMargin * 2 - root.hintHeight)
  readonly property real cellWidth: (mapWidth - root.cellGap) / OverviewModel.GRID_COLUMNS
  readonly property real cellHeight: (mapHeight - root.cellGap) / OverviewModel.VISIBLE_ROWS

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

    MouseArea {
      anchors.fill: parent
      onClicked: root.requestClose()
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

      Keys.onPressed: function (event) {
        if (event.key === Qt.Key_Escape) {
          root.requestClose()
          event.accepted = true
        } else if (event.key === Qt.Key_Left) {
          root.moveSelection(-1, 0)
          event.accepted = true
        } else if (event.key === Qt.Key_Right) {
          root.moveSelection(1, 0)
          event.accepted = true
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
          root.moveSelection(0, -1)
          event.accepted = true
        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
          root.moveSelection(0, 1)
          event.accepted = true
        } else if (event.key === Qt.Key_PageUp) {
          root.selectedIndex = OverviewModel.pageUp(root.selectedIndex, root.workspaceCells.length)
          root.revealIndex(root.selectedIndex)
          event.accepted = true
        } else if (event.key === Qt.Key_PageDown) {
          root.selectedIndex = OverviewModel.pageDown(root.selectedIndex, root.workspaceCells.length)
          root.revealIndex(root.selectedIndex)
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          root.activateSelected()
          event.accepted = true
        } else if (event.text >= "0" && event.text <= "9") {
          var workspaceId = OverviewModel.workspaceIdFromDigit(event.text)
          root.focusWorkspace(workspaceId)
          event.accepted = true
        }
      }

      Flickable {
        id: scroller
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.mapMargin
        anchors.rightMargin: root.mapMargin
        anchors.topMargin: root.mapMargin
        height: root.mapHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3500
        interactive: root.workspaceCells.length > OverviewModel.pageSize()
        contentWidth: width
        contentHeight: Math.max(
          height,
          Math.ceil(root.workspaceCells.length / OverviewModel.GRID_COLUMNS) * (root.cellHeight + root.cellGap) - root.cellGap
        )

        Grid {
          id: workspaceGrid
          width: parent.width
          columns: OverviewModel.GRID_COLUMNS
          columnSpacing: root.cellGap
          rowSpacing: root.cellGap

          Repeater {
            model: root.workspaceCells

            WorkspaceTile {
              required property var modelData
              required property int index
              width: root.cellWidth
              height: root.cellHeight
              cell: modelData
              selected: root.selectedIndex === index
              live: root.opened
              overlayMonitorName: root.targetScreen ? String(root.targetScreen.name || "") : ""
              onActivateWorkspace: root.focusWorkspace(modelData.workspaceId)
              onActivateWindow: function (address) { root.focusWindow(address) }
            }
          }
        }

        onMovementEnded: {
          var rowHeight = root.cellHeight + root.cellGap
          if (rowHeight <= 0)
            return
          var row = Math.round(scroller.contentY / rowHeight)
          var maxY = Math.max(0, scroller.contentHeight - scroller.height)
          scroller.contentY = Math.max(0, Math.min(maxY, row * rowHeight))
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Style.space(14)
        text: "1–0 go  ·  arrows move  ·  Esc close"
        color: Color.menu.text
        opacity: 0.42
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
  }
}
