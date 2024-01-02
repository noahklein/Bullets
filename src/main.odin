package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

import "game"
import "game/grid"

import "ngui"
import "rlutil"

// mode : MainMode = .Game
mode : MainMode = .DrawPolygon
MainMode :: enum { Game, DrawPolygon }

camera: rl.Camera2D

main :: proc() {
    when ODIN_DEBUG {
        track: mem.Tracking_Allocator
        mem.tracking_allocator_init(&track, context.allocator)
        context.allocator = mem.tracking_allocator(&track)

        defer {
            if len(track.allocation_map) > 0 {
                fmt.eprintf("=== %v allocations not freed: ===\n", len(track.allocation_map))
                for _, entry in track.allocation_map {
                    fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
                }
            }
            if len(track.bad_free_array) > 0 {
                fmt.eprintf("=== %v incorrect frees: ===\n", len(track.bad_free_array))
                for entry in track.bad_free_array {
                    fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
                }
            }
            mem.tracking_allocator_destroy(&track)
        }
    }
    defer free_all(context.temp_allocator)

    rl.SetTraceLogLevel(.ALL if ODIN_DEBUG else .WARNING)
    rl.InitWindow(1600, 900, "Terminalia")
    defer rl.CloseWindow()

    rl.rlEnableSmoothLines()

    // Before we do anything, clear the screen to avoid transparent windows.
    rl.BeginDrawing()
        rl.ClearBackground(rl.BLACK)
    rl.EndDrawing()

    camera = rl.Camera2D{ zoom = 2, offset = rlutil.screen_size() / 2 }

    ngui.init()
    defer ngui.deinit()

    rlutil.profile_init(2)
    defer rlutil.profile_deinit()

    reserve(&polygon, 8)
    defer delete(polygon)

    game.init(2)
    defer game.deinit()

    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := rl.GetFrameTime()

        camera.zoom += rl.GetMouseWheelMove()
        camera.zoom = clamp(camera.zoom, 0.5, 10)

        switch {
        case rl.IsKeyPressed(.F1): mode = .Game
        case rl.IsKeyPressed(.F2): mode = .DrawPolygon
        }

        switch mode {
            case .Game: mode_game(dt)
            case .DrawPolygon: mode_draw_polygon(dt)
        }
    }
}

mode_game :: proc(dt: f32) {
    cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

    if rlutil.profile_begin("update") {
        game.update(dt, cursor)
    }

    if rl.IsKeyPressed(.G) do gui.show_grid = !gui.show_grid

    // Draw
    rlutil.profile_begin("draw")
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.BLACK)

    rl.BeginMode2D(camera)
        game.draw(cursor)
    rl.EndMode2D()

    when ODIN_DEBUG {
        rl.DrawFPS(rl.GetScreenWidth() - 80, 0)
        hovered, ok := grid.hovered_cell(cursor)
        if ok {
            rl.BeginMode2D(camera)
                if gui.show_grid do grid.draw(camera)
                rl.DrawRectangleV(hovered, grid.CELL, {255, 255, 255, 100})
                gui_drag(cursor)
                gui_delete_wall(cursor)
            rl.EndMode2D()
        }

        draw_gui(&camera, cursor)
    }
}

polygon : [dynamic]rl.Vector2

mode_draw_polygon :: proc(dt: f32) {
    cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)
    hovered, _ := grid.hovered_cell(cursor)

    if rl.IsKeyDown(.LEFT_SHIFT) {
        hovered = cursor
    }

    if !ngui.want_mouse() && rl.IsMouseButtonPressed(.LEFT) {
        already_exists: bool
        for point in polygon do if rlutil.nearly_eq(point, hovered) {
            already_exists = true
            break
        }
        if !already_exists do append(&polygon, hovered)
    }

    rlutil.profile_begin("draw")
    rl.BeginDrawing()
    defer rl.EndDrawing()
    rl.ClearBackground(rl.DARKGRAY)

    rl.BeginMode2D(camera)
        grid.draw(camera)
        rl.DrawPixelV(hovered, rl.BLACK)

        rlutil.DrawPolygonLines(polygon[:], rl.YELLOW)

        for point in polygon do rl.DrawPixelV(point, rl.GREEN)
    rl.EndMode2D()

    gui_draw_polygon()
}

