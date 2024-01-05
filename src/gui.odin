package main

import "core:time"
import "core:math/rand"
import rl "vendor:raylib"

import "game"
import "game/grid"
import "game/physics"
import "ngui"
import "rlutil"

draw_gui :: proc(camera: ^rl.Camera2D, cursor: rl.Vector2) {
    ngui.update()

    if ngui.begin_panel("Game", {0, 0, 300, 0}) {
        if ngui.flex_row({0.2, 0.4, 0.2, 0.2}) {
            ngui.text("Camera")
            ngui.vec2(&camera.target, label = "Target")
            ngui.float(&camera.zoom, min = 0.5, max = 10, label = "Zoom")
            ngui.float(&camera.rotation, min = -360, max = 360, label = "Angle")
        }

        if ngui.flex_row({0.2, 0.25}) {
            ngui.text("Ball")
            ngui.arrow(&game.world.dynamics[0].vel, "Velocity")
        }

        dur :: proc(prof: rlutil.Profile) -> f32 {
            return f32(time.stopwatch_duration(prof.stopwatch))
        }

        if ngui.flex_row({1}) {
            if ngui.graph_begin("Time", 256, lower = 0, upper = f32(time.Second) / 120) {
                update := rlutil.profile_get("update")
                draw   := rlutil.profile_get("draw")
                ngui.graph_line("Update", dur(update), rl.BLUE)
                ngui.graph_line("Draw", dur(draw), rl.RED)

            }
        }
    }
}

Gui :: struct {
    dragging, show_grid: bool,
    drag_mouse_start: rl.Vector2,
    color: rl.Color,
}

gui : Gui

gui_drag :: proc(cursor: rl.Vector2) {
    if game.mode == .EditWalls do return

    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
        gui.dragging = true
        gui.drag_mouse_start = cursor
        gui.color = rand_color()
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
    rl.DrawRectangleRec(drag_rect, gui.color - {0, 0, 0, 100})

    if rl.IsMouseButtonReleased(.LEFT) {
        gui.dragging = false
        wall := physics.new_wall_body(drag_rect)
        append(&game.world.walls,  wall)
        append(&game.future.walls, wall)
    }
}

gui_delete_wall :: proc(cursor: rl.Vector2) {
    // TODO: polygon point collision on cursor.
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