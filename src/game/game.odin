package game

import "core:math/linalg"

import rl "vendor:raylib"

import "grid"
import "../ngui"

ACTOR_SIZE :: rl.Vector2{2*grid.CELL, 4*grid.CELL}

active_actor: int
actors: [dynamic]Actor
walls : [dynamic]Wall

bullet_path : [dynamic]rl.Vector2

Actor :: struct{
    pos: rl.Vector2,
    team: Team,
}

Wall :: struct{
    rect: rl.Rectangle,
    color: rl.Color,
}

Team :: enum u8 { None, Blue, Red }

init :: proc(size: int) {
    reserve(&actors, size)
    append(&actors, Actor{{0, 0}, .Blue}, Actor{{8*grid.CELL, 0}, .Red})
}

deinit :: proc() {
    delete(actors)
    delete(walls)
    delete(bullet_path)
}

update :: proc(dt: f32, cursor: rl.Vector2) {
    actor := actors[active_actor]

    point := actor.pos
    dir := cursor - actor.pos

    clear(&bullet_path)
    append(&bullet_path, point)
    for _ in 0..<50 {
        // Get contact with lowest collision time.
        min_contact := Contact{ time = 1e19 }
        for wall in walls {
            contact := ray_vs_rect(point, dir, wall.rect) or_continue
            if contact.time >= min_contact.time do continue
            min_contact = contact
        }

        // No collision found, just continue the line in that direction.
        if min_contact.time > 1e18 {
            append(&bullet_path, point + dir * 100)
            break
        }

        point = min_contact.point
        if min_contact.normal.x != 0 {
            dir.x *= -1
        }
        if min_contact.normal.y != 0 {
            dir.y *= -1
        }
        append(&bullet_path, point)
    }
}

draw :: proc(cursor: rl.Vector2) {
    for wall in walls {
        rl.DrawRectangleRec(wall.rect, wall.color)
    }

    for actor in actors {
        color := rl.BLUE if actor.team == .Blue else rl.RED
        rl.DrawRectangleV(actor.pos, ACTOR_SIZE, color)
    }

    actor := actors[active_actor]

    if len(bullet_path) <= 1 {
        rl.DrawLineV(actor.pos, cursor, rl.WHITE)
    } else {
        for va, i in bullet_path[:len(bullet_path) - 1] {
            vb := bullet_path[i + 1]

            pct := f32(i + 1) / f32(len(bullet_path))
            color := ngui.lerp_color({30, 30, 30, 255}, rl.WHITE, pct)
            rl.DrawLineV(va, vb, color)
        }
    }
}

Contact :: struct {
    time: f32,
    normal: rl.Vector2,
    point: rl.Vector2,
}

ray_vs_rect :: proc(origin, dir: rl.Vector2, rect: rl.Rectangle) -> (Contact, bool) {
    rpos, rsize: rl.Vector2 = {rect.x, rect.y}, {rect.width, rect.height}

    near := (rpos - origin) / dir
    far  := (rpos + rsize - origin) / dir

    if linalg.is_nan(near.x) || linalg.is_nan(near.y) do return {}, false
    if linalg.is_nan(far.x)  || linalg.is_nan(far.y)  do return {}, false

    if near.x > far.x do near.x, far.x = far.x, near.x
    if near.y > far.y do near.y, far.y = far.y, near.y

    if near.x > far.y || near.y > far.x do return {}, false

    t_near := max(near.x, near.y)
    t_far  := min(far.x, far.y)
    if t_far < 0 || t_near <= -linalg.F32_EPSILON {
        return {}, false // Ray pointing away from rect.
    }

    contact_normal : rl.Vector2
     if near.x > near.y {
        contact_normal = {1, 0} if dir.x < 0 else {-1, 0}
    } else if near.x < near.y {
        contact_normal = {0, 1} if dir.y < 0 else {0, -1}
    } // else contact_normal is {0, 0}

    return {
        time = t_near,
        normal = contact_normal,
        point = origin + t_near * dir,
    }, true
}