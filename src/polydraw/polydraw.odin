package polydraw

import "core:fmt"
import rl "vendor:raylib"

import "../game/grid"
import "../ngui"
import "../rlutil"

polygon: [dynamic]rl.Vector2
hovered: rl.Vector2

mouse_drag_start: rl.Vector2
cam_target_drag_start: rl.Vector2

init   :: proc(size: int) { reserve(&polygon, size) }
deinit :: proc() { delete(polygon) }

update :: proc(camera: ^rl.Camera2D) {
    cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera^)
    hovered, _ = grid.hovered_cell(cursor)

    if rl.IsKeyDown(.LEFT_SHIFT) {
        hovered = cursor // Hold left shift to not snap to grid.
    }

    if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.Z) && len(polygon) > 0 {
        pop(&polygon)
    }

    if !ngui.want_mouse() && rl.IsMouseButtonDown(.RIGHT) {
        mouse_delta := rl.GetMouseDelta()
        camera.target += -rl.GetMouseDelta() / camera.zoom
    }

    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
        already_exists: bool
        for point in polygon do if rlutil.nearly_eq(point, hovered) {
            already_exists = true
            break
        }
        if !already_exists do append(&polygon, hovered)
    }
}

draw :: proc(camera: rl.Camera2D) {
    POINT_RADIUS := 3 / camera.zoom

    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.DARKGRAY)

    rl.BeginMode2D(camera)
        grid.draw(camera)
        rl.DrawCircleV(hovered, POINT_RADIUS, rl.BLACK)

        rlutil.DrawPolygonLines(polygon[:], rl.YELLOW)
        for point in polygon do rl.DrawCircleV(point, POINT_RADIUS, rl.GREEN)

        center := rlutil.polygon_center(polygon[:])
        rl.DrawCircleV(center, POINT_RADIUS, rl.RED)
    rl.EndMode2D()

    gui_draw()
}

gui_draw :: proc() {
    ngui.update()

    if ngui.begin_panel("Draw Polygon", {0, 0, 300, 0}) {
        center := rlutil.polygon_center(polygon[:])

        if ngui.flex_row({0.25, 0.5}) {
            ngui.text("Points: %v", len(polygon))
            ngui.text("Center: %v", center)
        }

        if ngui.flex_row({0.25, 0.25, 0.25, 0.25}) {
            if ngui.button("Centralize") {
                for va, i in polygon do polygon[i] = va - center
            }

            if ngui.button("Normalize") {
                for va, i in polygon do polygon[i] /= grid.CELL
            }

            // Pretty print polygon to console for copying into code.
            if ngui.button("Print") {
                fmt.println(" === Vertices === ")
                fmt.println("{")
                for v in polygon {
                    fmt.printf("    {{ % 6.1f, % 6.1f }},\n", v.x, v.y)
                }
                fmt.println("}")
            }

            if ngui.button("Clear") || rl.IsKeyPressed(.C) do clear(&polygon)
        }
    }
}