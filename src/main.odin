package main

import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

import "game"
import "game/grid"

import "ngui"
import "rlutil"

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

    camera := rl.Camera2D{ zoom = 2, offset = rlutil.screen_size() / 2 }

    ngui.init()
    defer ngui.deinit()

    game.init(2)
    defer game.deinit()

    rl.SetTargetFPS(60)
    for !rl.WindowShouldClose() {
        defer free_all(context.temp_allocator)

        dt := rl.GetFrameTime()
        game.update(dt)

        cursor := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera)

        // Draw
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
                    grid.draw(camera)
                    rl.DrawRectangleV(hovered, grid.CELL, {255, 255, 255, 100})
                    gui_drag(cursor)
                    gui_delete_wall(cursor)
                rl.EndMode2D()
            }

            draw_gui(&camera, cursor)
        }
    }
}