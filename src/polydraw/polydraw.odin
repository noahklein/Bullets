package polydraw

import "core:fmt"
import "core:math/linalg"
import rl "vendor:raylib"

import "../game/grid"
import "../ngui"
import "../rlutil"

polygon: [dynamic]rl.Vector2
hovered: rl.Vector2

dragging: bool
dragging_point := -1

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

    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.RIGHT) do dragging = true
    if rl.IsMouseButtonReleased(.RIGHT) do dragging = false
    if dragging {
        mouse_delta := rl.GetMouseDelta()
        camera.target += -rl.GetMouseDelta() / camera.zoom
    }

    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
        for point, i in polygon do if rl.CheckCollisionPointCircle(hovered, point, point_radius(camera^)) {
            dragging_point = i
            break
        }

        if dragging_point == -1 {
            append(&polygon, hovered)
            return
        }
    }

    if rl.IsMouseButtonUp(.LEFT) do dragging_point = -1

    if dragging_point != -1 do polygon[dragging_point] = cursor

}

draw :: proc(camera: ^rl.Camera2D) {
    POINT_RADIUS := point_radius(camera^)

    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.BLACK)

    rl.BeginMode2D(camera^)
        grid.draw(camera^)
        rl.DrawCircleV(hovered, POINT_RADIUS, rl.LIGHTGRAY)

        // rlutil.DrawPolygonLines(polygon[:], rl.YELLOW)
        rlutil.draw_polygon(polygon[:], rl.YELLOW)
        for point, i in polygon {
            color: rl.Color
            switch i {
                case 0: color = rl.BLUE
                case len(polygon) - 1: color = rl.SKYBLUE
                case: color = rl.GREEN
            }
            rl.DrawCircleV(point, POINT_RADIUS, color)
        }

        center := rlutil.polygon_center(polygon[:])
        rl.DrawCircleV(center, POINT_RADIUS, rl.RED)
    rl.EndMode2D()

    gui_draw(camera)
}

gui_draw :: proc(camera: ^rl.Camera2D) {
    ngui.update()

    if ngui.begin_panel("Draw Polygon", {0, 0, 350, 0}) {
        if ngui.flex_row({0.2, 0.4, 0.2, 0.2}) {
            ngui.text("Camera")
            ngui.vec2(&camera.target, label = "Target")
            ngui.float(&camera.zoom, min = 0.5, max = 10, label = "Zoom")
            ngui.float(&camera.rotation, min = -360, max = 360, label = "Angle")
        }

        center := rlutil.polygon_center(polygon[:])
        if ngui.flex_row({0.25, 0.5}) {
            ngui.text("Points: %v", len(polygon))
            ngui.text("Center: %.1f", center)
        }

        if ngui.flex_row({0.2, 0.2, 0.2, 0.2, 0.2}) {
            if ngui.button("Centralize") {
                for _, i in polygon do polygon[i] -= center
            }

            if ngui.button("Shrink") || rl.IsKeyPressed(.Q) {
                for _, i in polygon do polygon[i] /= 2
            }

            if ngui.button("Grow") || rl.IsKeyPressed(.E) {
                for _, i in polygon do polygon[i] *= 2
            }

            if ngui.button("Clear") || rl.IsKeyPressed(.BACKSPACE) do clear(&polygon)

            // Pretty print polygon to console for copying into code.
            if ngui.button("Print") {
                fmt.println(" === Vertices === ")
                fmt.println("{")
                for v in polygon {
                    fmt.printf("    {{ % 6.1f, % 6.1f }},\n", v.x, v.y)
                }
                fmt.println("}")
            }
        }

        if ngui.flex_row({0.2, 0.2, 0.2}) {
            if ngui.button("Less") || rl.IsKeyDown(.A) {
                points := max(len(polygon) - 1, 0)
                gen_regular_polygon(points)
            }
            if ngui.button("More") || rl.IsKeyDown(.D) {
                gen_regular_polygon(len(polygon) + 1)
            }
        }
    }
}

gen_regular_polygon :: proc(points: int) {
    clear(&polygon)

    angle_delta := 360.0 / f32(points)
    for i in 0..<points {
        angle := -angle_delta * f32(i) * rl.DEG2RAD
        v := rl.Vector2{linalg.cos(angle), linalg.sin(angle)}

        append(&polygon, v * 4 * grid.CELL)
    }

}

point_radius :: proc(camera: rl.Camera2D) -> f32 {
    return 4 / camera.zoom
}