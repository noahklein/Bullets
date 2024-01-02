package rlutil

import "core:intrinsics"
import rl "vendor:raylib"

nearly_eq :: proc{
    nearly_eq_scalar,
    nearly_eq_vector,
}

nearly_eq_scalar :: proc(a, b: f32, precision: f32 = 0.0001) -> bool {
    return abs(a - b) < precision
}

nearly_eq_vector :: proc(a, b: $A/[$N]f32, precision: f32 = 0.0001) -> bool #no_bounds_check {
    for i in 0..<N {
        if !nearly_eq_scalar(a[i], b[i], precision) do return false
    }
    return true
}

// A polygon's center is the arithmetic mean of the vertices.
polygon_center :: #force_inline proc(verts: []rl.Vector2) -> (mean: rl.Vector2) {
    for v in verts do mean += v
    return mean / f32(len(verts))
}