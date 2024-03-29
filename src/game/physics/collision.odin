package physics

import "core:math/linalg"
import rl "vendor:raylib"
import "../../rlutil"

Body :: struct {
    pos, vel: rl.Vector2,
    rot: f32,

    aabb: rl.Rectangle,
    shape: union { Circle, Polygon },
}

Hit :: struct {
    normal: rl.Vector2, // Points from a to b.
    depth: f32,
}

collision_check :: proc(a, b: Body) -> (Hit, bool) {
    // Broad-phase check to early exit.
    if !rl.CheckCollisionRecs(a.aabb, b.aabb) {
        return {}, false
    }

    switch &as in a.shape {
    case Circle:
        switch bs in b.shape {
        case Circle: return collide_circles(a.pos, b.pos, as.radius, bs.radius)
        case Polygon:
            hit, ok := collide_polygon_circle(bs, b.pos, a.pos, as.radius)
            hit.normal = -hit.normal
            return hit, ok
        }
    case Polygon:
        switch bs in b.shape {
        case Circle:
            hit, ok := collide_polygon_circle(as, a.pos, b.pos, bs.radius)
            // hit.normal = -hit.normal
            return hit, ok

        case Polygon:
            return collide_polygons(as, bs, a.pos, b.pos)
        }
    }

    panic("Impossible: unsupported shape in collision_check")
}

collide_circles :: proc(a_center, b_center: rl.Vector2, a_radius, b_radius: f32) -> (Hit, bool) {
    dist := linalg.distance(a_center, b_center)

    radii := a_radius + b_radius
    if dist >= radii do return {}, false

    return {
        normal = linalg.normalize(b_center - a_center),
        depth = radii - dist,
    }, true
}

collide_polygon_circle :: proc(poly: Polygon, poly_center, center: rl.Vector2, radius: f32) -> (Hit, bool) {
    normal : rl.Vector2
    depth := f32(1e18)

    // Loop over every edge in polygon.
    for i in 0..<poly.count {
        v1 := poly.vertices[i]
        v2 := poly.vertices[(i + 1) % poly.count]
        edge := v2 - v1

        axis := linalg.normalize(rl.Vector2{-edge.y, edge.x}) // Normal, negative reciprical slope trick.
        a_min, a_max := project_polygon(poly, axis)
        b_min, b_max := project_circle(center, radius, axis)

        if a_min >= b_max || b_min >= a_max {
            return {}, false // There's a gap between the polygons on this axis.
        }

        axis_depth := min(b_max - a_min, a_max - b_min)
        if axis_depth < depth {
            depth  = axis_depth
            normal = axis
        }
    }

    cp := polygon_closest_point(center, poly)
    axis := linalg.normalize(cp - center)
    a_min, a_max := project_polygon(poly, axis)
    b_min, b_max := project_circle(center, radius, axis)
    if a_min >= b_max || b_min >= b_max {
        return {}, false
    }

    axis_depth := min(b_max - a_min, a_max - b_min)
    if axis_depth < depth {
        depth = axis_depth
        normal = axis
    }

    if direction := center - poly_center; linalg.dot(direction, normal) < 0 {
        normal = -normal
    }

    return {depth = depth, normal = normal}, true
}


collide_polygons :: proc(a, b: Polygon, a_center, b_center: rl.Vector2) -> (hit: Hit, ok: bool) {
    a_hit := _collide_polygons(a, b, a_center, b_center) or_return
    b_hit := _collide_polygons(b, a, b_center, a_center) or_return

    if a_hit.depth < b_hit.depth {
        return a_hit, true
    }

    b_hit.normal = -b_hit.normal
    return b_hit, true
}

@(private)
_collide_polygons :: proc(a, b: Polygon, a_center, b_center: rl.Vector2) -> (Hit, bool) {
    normal : rl.Vector2
    depth := f32(1e9)

    // Loop over every edge in polygon a.
    for i in 0..<a.count {
        v1 := a.vertices[i]
        v2 := a.vertices[(i + 1) % a.count]
        edge := v2 - v1

        axis := linalg.normalize(rl.Vector2{-edge.y, edge.x}) // Normal, negative reciprical slope trick.
        a_min, a_max := project_polygon(a, axis)
        b_min, b_max := project_polygon(b, axis)

        if a_min >= b_max || b_min >= a_max {
            return {}, false // There's a gap between the polygons on this axis.
        }

        axis_depth := min(b_max - a_min, a_max - b_min)
        if axis_depth < depth {
            depth  = axis_depth
            normal = axis
        }
    }

    if direction := b_center - a_center; linalg.dot(direction, normal) < 0 {
        normal = -normal
    }

    // No gaps found, polygons are colliding.
    return {
        depth = depth,
        normal = normal,
    }, true
}

project_polygon :: proc(p: Polygon, axis: rl.Vector2) -> (low, high: f32) {
    low = 1e18
    high = -high

    for i in 0..<p.count {
        projection := linalg.dot(p.vertices[i], axis)
        if projection < low  do low = projection
        if projection > high do high = projection
    }

    return
}

project_circle :: proc(center: rl.Vector2, radius: f32, axis: rl.Vector2) -> (low, high: f32) {
    dir := axis * radius
    low  = linalg.dot(center - dir, axis)
    high = linalg.dot(center + dir, axis)

    return min(low, high), max(low, high)
}

// A polygon's center is the arithmetic mean of the vertices.
polygon_center :: #force_inline proc(verts: []rl.Vector2) -> (mean: rl.Vector2) {
    for v in verts do mean += v
    return mean / f32(len(verts))
}

// Closest vertex on a polygon to a circle.
polygon_closest_point :: #force_inline proc(circle_center: rl.Vector2, poly: Polygon) -> (cp: rl.Vector2) {
    min_dist := f32(1e18)
    for i in 0..<poly.count {
        v := poly.vertices[i]

        if dist := linalg.distance(v, circle_center); dist < min_dist {
            min_dist = dist
            cp = v
        }
    }

    return
}

find_contact_points :: proc(a, b: ^Body) -> (contact1, contact2: rl.Vector2, count: int) {
    switch &as in a.shape {
    case Circle:
        switch &bs in b.shape {
        case Circle: return contact_point_circles(a.pos, b.pos, as.radius), {}, 1
        case Polygon:
            return contact_point_circle_polygon(a.pos, b.pos, as.radius, bs), {}, 1
        }
    case Polygon:
        switch &bs in b.shape {
        case Circle:
            return contact_point_circle_polygon(b.pos, a.pos, bs.radius, as), {}, 1
        case Polygon:
            return contact_point_polygons(a.pos, b.pos, as, bs)
        }
    }

    // panic("unsupported shape in find_contact_points")
    return {}, {}, 0
}

@(private="file")
contact_point_circles :: proc(a_center, b_center: rl.Vector2, a_radius: f32) -> rl.Vector2 {
    ab := b_center - a_center
    return a_center + a_radius*linalg.normalize(ab)
}

@(private="file")
contact_point_circle_polygon :: proc(a_center, b_center: rl.Vector2, a_radius: f32, b_poly: Polygon) -> rl.Vector2 {
    min_sq_dist := f32(1e18)
    contact: rl.Vector2

    for i in 0..<b_poly.count {
        va := b_poly.vertices[i]
        vb := b_poly.vertices[(i + 1) % b_poly.count]

        sq_dist, cp := point_segment_distance(a_center, va, vb)
        if sq_dist < min_sq_dist {
            min_sq_dist = sq_dist
            contact = cp
        }
    }

    return contact
}

@(private="file")
point_segment_distance :: proc(p, a, b: rl.Vector2) -> (sq_dist: f32, contact: rl.Vector2) {
    ab := b - a
    ap := p - a

    proj := linalg.dot(ap, ab)
    ab_sqr_len := linalg.length2(ab)

    d := proj / ab_sqr_len
    switch {
    case d <= 0: contact = a
    case d >= 1: contact = b
    case:        contact = a + ab*d
    }
    return linalg.length2(contact - p), contact
}

@(private="file")
contact_point_polygons :: proc(a_center, b_center: rl.Vector2,
                               a,  b: Polygon) -> (cp1, cp2: rl.Vector2, count: int) {
    min_sq_dist := f32(1e18)

    for i in 0..<a.count {
        p := a.vertices[i]

        for j in 0..<b.count {
            va := b.vertices[j]
            vb := b.vertices[(j+1) % b.count]

            sq_dist, contact := point_segment_distance(p, va, vb)

            switch {
            case rlutil.nearly_eq(sq_dist, min_sq_dist, 0.001):
                if !rlutil.nearly_eq(contact, cp1, 0.001) {
                    cp2 = contact
                    count = 2
                }
            case sq_dist <  min_sq_dist:
                min_sq_dist = sq_dist
                cp1 = contact
                count = 1
            }
        }
    }

    for i in 0..<b.count {
        p := b.vertices[i]

        for j in 0..<a.count {
            va := a.vertices[j]
            vb := a.vertices[(j+1) % len(a.vertices)]

            sq_dist, contact := point_segment_distance(p, va, vb)

            switch {
            case rlutil.nearly_eq(sq_dist, min_sq_dist, 0.001):
                if !rlutil.nearly_eq(contact, cp1, 0.001) {
                    cp2 = contact
                    count = 2
                }
            case sq_dist <  min_sq_dist:
                min_sq_dist = sq_dist
                cp1 = contact
                count = 1
            }
        }
    }

    return
}