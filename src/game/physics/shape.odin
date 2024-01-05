package physics

import "core:math/linalg"
import rl "vendor:raylib"

MAX_VERTICES :: 4

Circle  :: struct{ radius: f32 }
Polygon :: struct{ vertices: [MAX_VERTICES]rl.Vector2, count: int }

polygon_move :: #force_inline proc(p: ^Polygon, delta: rl.Vector2) {
    for i in 0..<p.count do p.vertices[i] += delta
}

polygon_init :: proc(vertices: ..rl.Vector2) -> (p: Polygon) {
    p.count = len(vertices)
    for v, i in vertices do p.vertices[i] = v
    return
}

polygon_draw_lines :: proc(p: Polygon, color: rl.Color) {
    for i in 0..<p.count {
        va := p.vertices[i]
        vb := p.vertices[(i+1) % p.count]

        rl.DrawLineV(va, vb, color)
    }
}

polygon_draw :: proc(p: Polygon, color: rl.Color) {
    rl.DrawTriangle(p.vertices[0], p.vertices[2], p.vertices[1], color)
    rl.DrawTriangle(p.vertices[0], p.vertices[3], p.vertices[2], color)
}

body_move :: proc(b: ^Body, delta: rl.Vector2) {
    b.pos += delta

    if polygon, ok := &b.shape.(Polygon); ok {
        polygon_move(polygon, delta)
    }

    b.aabb = body_get_aabb(b^)
}

// Axis-aligned bounding box, for fast broad-phase filtering.
body_get_aabb :: proc(b: Body) -> rl.Rectangle {
    rmin: rl.Vector2 = 1e9
    rmax: rl.Vector2 = -1e9
    switch &s in b.shape {
        case Circle:
            rmin = b.pos - s.radius
            rmax = b.pos + s.radius
        case Polygon:
            for i in 0..<s.count {
                v := s.vertices[i]
                rmin = linalg.min(rmin, v)
                rmax = linalg.max(rmax, v)
            }
    }

    return {rmin.x, rmin.y, rmax.x - rmin.x, rmax.y - rmin.y}
}