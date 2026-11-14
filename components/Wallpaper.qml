import QtQuick
import Quickshell
import Quickshell.Wayland

WlrLayershell {
  id: wallpaperWindow
  required property var modelData
  screen: modelData
  
  layer: WlrLayershell.Layer.Background
  namespace: "wallpaper"
  
  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }
  
  keyboardFocus: WlrLayershell.KeyboardFocus.None

  Image {
    id: backgroundImage
    anchors.fill: parent
    //source: "file:///home/hervert/Pictures/Wallpapers/a_cartoon_of_a_girl_puppet.jpg" 
    //source: "file:///home/hervert/Pictures/Wallpapers/sun.png" 
    source: "file:///home/hervert/Pictures/Wallpapers/2b.jpg" 
    //source: "file:///home/hervert/Pictures/Wallpapers/momoka.png" 
    fillMode: Image.PreserveAspectCrop 
    asynchronous: true 
    z: 1
  }

  DesktopClock {
    anchors.centerIn: parent
    z: 2
  }

  Image {
    id: foregroundImage
    anchors.fill: parent
    source: "file:///home/hervert/resultado.png" 
    fillMode: Image.PreserveAspectCrop 
    asynchronous: true 
    z: 3
  }
}
