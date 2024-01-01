package main

import "core:math/rand"
import rl "vendor:raylib"

import "game"
import "game/grid"
import "ngui"

draw_gui :: proc(camera: ^rl.Camera2D, cursor: rl.Vector2) {
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

Gui :: struct {
    dragging: bool,
    drag_mouse_start: rl.Vector2,
}

gui : Gui

gui_drag :: proc(cursor: rl.Vector2) {
    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
        gui.dragging = true
        gui.drag_mouse_start = cursor
        return
    }

    if !gui.dragging do return
    // Here be draggin'

    if rl.IsMouseButtonPressed(.RIGHT) {
        gui.dragging = false
        return // What a drag, I'm outta here
    }

    // The grid square the mouse hovered when dragging started. Pick the corner based on drag direction.
    d_mouse := gui.drag_mouse_start
    start_x := grid.snap_up(i32(d_mouse.x)) if cursor.x < d_mouse.x else grid.snap_down(i32(d_mouse.x))
    start_y := grid.snap_up(i32(d_mouse.y)) if cursor.y < d_mouse.y else grid.snap_down(i32(d_mouse.y))
    start := rl.Vector2{f32(start_x), f32(start_y)}

    // The grid square the mouse is currently hovering. Again, the corner is based on drag direction.
    end_x := grid.snap_up(i32(cursor.x)) if cursor.x > d_mouse.x else grid.snap_down(i32(cursor.x))
    end_y := grid.snap_up(i32(cursor.y)) if cursor.y > d_mouse.y else grid.snap_down(i32(cursor.y))
    end := rl.Vector2{f32(end_x), f32(end_y)}

    drag_rect := normalize_rect(start, end)
    rl.DrawRectangleRec(drag_rect, rl.GREEN - {0, 0, 0, 100})

    if rl.IsMouseButtonReleased(.LEFT) {
        gui.dragging = false
        append(&game.walls, game.Wall{ drag_rect, rand_color() })
    }
}

gui_delete_wall :: proc(cursor: rl.Vector2) {
    for wall, i in game.walls do if rl.CheckCollisionPointRec(cursor, wall.rect) {
        rl.DrawRectangleRec(wall.rect, {255, 255, 255, 80})

        if rl.IsMouseButtonPressed(.RIGHT) {
            unordered_remove(&game.walls, i)
        }

        return // Can only hover one rect at a time.
    }
}

normalize_rect :: proc(start, end: rl.Vector2) -> rl.Rectangle {
    return {
        min(start.x, end.x),
        min(start.y, end.y),
        abs(end.x - start.x),
        abs(end.y - start.y),
    }
}

rand_color :: proc(low := rl.BLACK, high := rl.WHITE) -> rl.Color {
    rand_u8 :: proc(low, high: u8) -> u8 {
        if low == high do return low

        r := rand.int_max(int(high - low))
        return u8(r) + low
    }

    return {
        rand_u8(low.r, high.r),
        rand_u8(low.g, high.g),
        rand_u8(low.b, high.b),
        rand_u8(low.a, high.a),
    }
}