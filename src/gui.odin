package main

import rl "vendor:raylib"
import "ngui"

draw_gui :: proc(camera: ^rl.Camera2D) {
    ngui.update()

    if ngui.begin_panel("Game", {0, 0, 300, 0}) {
        if ngui.flex_row({0.2, 0.4, 0.2, 0.2}) {
            ngui.text("Camera")
            ngui.vec2(&camera.target, label = "Target")
            ngui.float(&camera.zoom, min = 0.1, max = 10, label = "Zoom")
            ngui.float(&camera.rotation, min = -360, max = 360, label = "Angle")
        }
    }
}
