package physics

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