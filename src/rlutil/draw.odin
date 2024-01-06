package rlutil

import rl "vendor:raylib"

DrawPolygonLines :: proc(vertices: []rl.Vector2, color: rl.Color) {
    for v1, i in vertices {
        v2 := vertices[(i+1) % len(vertices)]

        rl.DrawLineV(v1, v2, color)
    }
}

draw_polygon :: proc(vs: []rl.Vector2, color: rl.Color) {
    // These are NOT polygons but I'll draw them for you anyway, idiot.
    switch len(vs) {
        case 0: return
        case 1: rl.DrawPixelV(vs[0], color); return
        case 2: rl.DrawLineV(vs[0], vs[1], color); return
    }

    for i := 0; i + 2 <= len(vs); i += 2 {
        rl.DrawTriangle     (vs[i], vs[i+1], vs[(i+2) % len(vs)], rl.RED)
        rl.DrawTriangleLines(vs[i], vs[i+1], vs[(i+2) % len(vs)], rl.WHITE)
    }

    for i := 0; i + 3 <= len(vs); i += 4 {
        rl.DrawTriangle     (vs[i], vs[i+2], vs[(i+4) % len(vs)], rl.BLUE)
        rl.DrawTriangleLines(vs[i], vs[i+2], vs[(i+4) % len(vs)], rl.WHITE)
    }

    for i := 0; i + 8 <= len(vs); i += 8 {
        rl.DrawTriangle     (vs[i], vs[i+4], vs[(i+8) % len(vs)], rl.PURPLE)
        rl.DrawTriangleLines(vs[i], vs[i+4], vs[(i+8) % len(vs)], rl.WHITE)
    }
}

screen_size :: #force_inline proc() -> rl.Vector2 {
    return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}