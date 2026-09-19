import QtQuick

// Pointer target that both clicks and scrolls. Layer-shell overlays need a
// real MouseArea under the cursor; WheelHandler alone is not enough.
MouseArea {
  id: root

  signal activated()
  signal wheelMoved(real pixelY, real angleY)

  anchors.fill: parent
  hoverEnabled: true

  onClicked: function (mouse) {
    root.activated()
    mouse.accepted = true
  }

  onWheel: function (wheel) {
    root.wheelMoved(
      wheel.pixelDelta ? wheel.pixelDelta.y : 0,
      wheel.angleDelta ? wheel.angleDelta.y : 0
    )
    wheel.accepted = true
  }
}
