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

    get_color :: proc(x: int) -> rl.Color {
        switch x {
            case   2: return rl.RED
            case   4: return rl.ORANGE
            case   8: return rl.YELLOW
            case  16: return rl.GREEN
            case  32: return rl.BLUE
            case  64: return {75, 0, 130, 255} // Indigo
            case 128: return rl.VIOLET
            case    : return rl.LIGHTGRAY
        }
    }

    triangle_count : int
    for x := 2; x <= len(vs); x *= 2 {
        color := get_color(x)
        for i := 0; i + x/2 < len(vs) ; i += x {
            final := i+x if i+x < len(vs) else 0
            rl.DrawTriangle     (vs[i], vs[i+x/2], vs[final], color)
            rl.DrawTriangleLines(vs[i], vs[i+x/2], vs[final], rl.WHITE)

            triangle_count += 1
        }
    }
}

screen_size :: #force_inline proc() -> rl.Vector2 {
    return { f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight()) }
}