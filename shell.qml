import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Window
import "./state"
import "./modules"
import "./modules/bar"
import "./components"
import Quickshell.Io

ShellRoot {
  Variants {
    model: Quickshell.screens
    delegate: Wallpaper {} 
  }
  Bar {}
  ClipboardLauncher {}
  AppLauncher {}
  WallpaperPicker {}
}
