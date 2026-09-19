import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "model/OverviewModel.js" as OverviewModel

BorderSurface {
  id: root

  required property var cell
  required property bool selected
  required property bool live
  required property string overlayMonitorName

  signal activateWorkspace()
  signal activateWindow(string address)
  signal wheelMoved(real pixelY, real angleY)

  readonly property string backgroundPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/background"

  radius: Style.cornerRadius
  color: Color.menu.background
  borderSpec: Border.surfaceSpec(
    "menu",
    "border",
    root.selected || (root.cell && root.cell.focused) ? Color.accent : Color.menu.border,
    root.selected ? Math.max(2, Style.space(2)) : Math.max(1, Style.space(1))
  )

  readonly property var laidOut: {
    if (!root.cell || stage.width <= 0 || stage.height <= 0)
      return []
    return OverviewModel.layoutWindows(root.cell.windows, root.cell.canvas, {
      width: stage.width,
      height: stage.height
    })
  }

  function toplevelFor(address) {
    if (!root.cell || !root.cell.toplevels)
      return null
    for (var i = 0; i < root.cell.toplevels.length; i++) {
      var toplevel = root.cell.toplevels[i]
      if (toplevel && OverviewModel.ensure0x(toplevel.address) === address)
        return toplevel
    }
    return null
  }

  WheelArea {
    onActivated: root.activateWorkspace()
    onWheelMoved: function (pixelY, angleY) { root.wheelMoved(pixelY, angleY) }
  }

  Item {
    id: chrome
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: Style.space(14)
    anchors.leftMargin: Style.space(22)
    anchors.rightMargin: Style.space(14)
    height: deskLabel.implicitHeight
    z: 2

    Text {
      id: deskLabel
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: {
        if (!root.cell)
          return ""
        return String(root.cell.workspaceId === 10 ? 0 : root.cell.workspaceId)
      }
      color: root.cell && root.cell.focused ? Color.accent : Color.menu.text
      opacity: 0.5
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.bold: true
    }

    Text {
      visible: !!(root.cell && root.cell.monitorName && root.cell.monitorName !== root.overlayMonitorName)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: root.cell ? String(root.cell.monitorName || "") : ""
      color: Color.menu.text
      opacity: 0.45
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
  }

  Item {
    id: stage
    anchors.fill: parent
    anchors.margins: Style.space(14)
    clip: true

    Image {
      anchors.fill: parent
      source: Util.fileUrl(root.backgroundPath)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
    }

    Repeater {
      model: root.laidOut

      WindowThumb {
        required property var modelData
        x: modelData.x
        y: modelData.y
        width: Math.max(1, modelData.width)
        height: Math.max(1, modelData.height)
        toplevel: root.toplevelFor(modelData.address)
        live: root.live
        showTitle: root.selected
        onActivated: root.activateWindow(modelData.address)
        onWheelMoved: function (pixelY, angleY) { root.wheelMoved(pixelY, angleY) }
      }
    }
  }
}
