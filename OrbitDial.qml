import QtQuick
import qs.Commons

Item {
  id: root
  property real progress: 0
  property bool running: false
  property bool animate: false
  property string timeText: "25:00"
  property string phaseText: "READY TO FOCUS"
  property color accent: Color.accent
  property color foreground: Color.popups.text
  readonly property color track: Util.alpha(foreground, 0.2)
  property real spin: 0
  implicitWidth: 186
  implicitHeight: 186

  NumberAnimation on spin {
    from: 0; to: 360; duration: 60000; loops: Animation.Infinite
    running: root.animate && root.running
  }
  onProgressChanged: dial.requestPaint()
  onAccentChanged: dial.requestPaint()
  onForegroundChanged: dial.requestPaint()
  onTrackChanged: dial.requestPaint()
  Canvas {
    id: dial
    anchors.fill: parent
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
      var c = getContext("2d"), w = width, h = height, r = Math.min(w,h)*0.415
      c.reset(); c.translate(w/2,h/2)
      // Fine instrument ticks encode elapsed time without stealing the readout.
      for (var i=0; i<60; i++) {
        var a = i*Math.PI/30 - Math.PI/2
        c.strokeStyle = i/60 < root.progress ? root.accent : root.track
        c.lineWidth = i%5===0 ? 2 : 1
        var len = i%5===0 ? 10 : 5
        c.beginPath(); c.moveTo(Math.cos(a)*r,Math.sin(a)*r)
        c.lineTo(Math.cos(a)*(r-len),Math.sin(a)*(r-len)); c.stroke()
      }
      c.lineWidth=1; c.strokeStyle=root.track
      c.beginPath(); c.arc(0,0,r-22,0,Math.PI*2); c.stroke()
      if (root.progress>0) {
        c.strokeStyle=root.accent; c.lineWidth=3; c.lineCap="round"
        c.beginPath(); c.arc(0,0,r-22,-Math.PI/2,-Math.PI/2+root.progress*Math.PI*2); c.stroke()
      }
    }
  }
  Item {
    anchors.fill: parent
    rotation: root.spin - 32
    Rectangle {
      x: parent.width/2 - 4
      y: parent.height*0.085 - 4
      width: 8; height: 8; radius: 4; color: root.accent
      Rectangle { anchors.centerIn: parent; width: 20; height: 20; radius: 10; color: root.accent; opacity: 0.10 }
    }
  }
  Column {
    anchors.centerIn: parent
    spacing: 9
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.phaseText; color: Util.alpha(root.foreground,0.75)
      font.family: Style.font.family; font.pixelSize: 10; font.letterSpacing: 2
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: root.timeText; color: root.foreground
      font.family: Style.font.family; font.pixelSize: Math.min(root.width*(root.timeText.length > 5 ? 0.17 : 0.22), 48)
      font.letterSpacing: -1
    }
  }
}
