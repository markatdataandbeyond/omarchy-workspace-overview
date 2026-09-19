import QtQuick
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var toplevel: null
  property bool live: false
  property bool showTitle: false

  signal activated()
  signal wheelMoved(real pixelY, real angleY)

  clip: true

  ScreencopyView {
    anchors.fill: parent
    captureSource: root.toplevel && root.toplevel.wayland ? root.toplevel.wayland : null
    live: root.live
    constraintSize: Qt.size(width, height)
  }

  Rectangle {
    anchors.fill: parent
    visible: !(root.toplevel && root.toplevel.wayland)
    color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.06)
    border.width: 1
    border.color: Qt.rgba(Color.menu.text.r, Color.menu.text.g, Color.menu.text.b, 0.14)
  }

  Rectangle {
    visible: root.showTitle && titleText.text !== ""
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: titleText.implicitHeight + Style.space(4)
    color: Qt.rgba(Color.background.r, Color.background.g, Color.background.b, 0.62)

    Text {
      id: titleText
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      text: root.toplevel ? String(root.toplevel.title || "") : ""
      color: Color.menu.text
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
    }
  }

  WheelArea {
    onActivated: root.activated()
    onWheelMoved: function (pixelY, angleY) { root.wheelMoved(pixelY, angleY) }
  }
}
