package game

import "core:math/linalg"

import rl "vendor:raylib"

import "grid"
import "physics"
import "../ngui"
import "../rlutil"

ACTOR_SIZE :: rl.Vector2{2*grid.CELL, 4*grid.CELL}
BALL_LAUNCH_SPEED :: 20

mode: GameMode = .AimBall
GameMode :: enum {
    AimBall,
    LaunchBall,
}

world : physics.World
future: physics.World

active_actor: int
actors: [dynamic]Actor


bullet_path : [dynamic]rl.Vector2

Actor :: struct{
    pos: rl.Vector2,
    team: Team,
}

get_actor_rect :: #force_inline proc(a: Actor) -> rl.Rectangle {
    return {a.pos.x, a.pos.y, ACTOR_SIZE.x, ACTOR_SIZE.y}
}

Wall :: struct{
    rect: rl.Rectangle,
    color: rl.Color,
}

Team :: enum u8 { None, Blue, Red }

init :: proc(size: int) {
    reserve(&actors, size)
    append(&actors,
        Actor{{0, 0}, .Blue},
        Actor{{8*grid.CELL, 0}, .Red},
        Actor{{16*grid.CELL, 0}, .Blue},
    )

    world = physics.init()
    world.ball = physics.Body{shape = physics.Circle{grid.CELL}}

    future.ball = world.ball
}

deinit :: proc() {
    delete(actors)
    delete(bullet_path)

    physics.deinit(world)
    physics.deinit(future)
}

update :: proc(dt: f32, cursor: rl.Vector2) {
    switch mode {
        case .AimBall:
            update_aim_ball(cursor)
            // Fire!
            if rl.IsMouseButtonPressed(.MIDDLE) {
                mode = .LaunchBall
                world.ball.vel = linalg.normalize(cursor - world.ball.pos) * BALL_LAUNCH_SPEED
            }
        case .LaunchBall: update_launch_ball(dt)
    }
}

update_aim_ball :: proc(cursor: rl.Vector2) {
    actor := actors[active_actor]
    my_team := actor.team

    point := actor.pos
    dir := cursor - actor.pos

    // Update ball position to aim towards cursor.
    world.ball.pos = actor.pos + linalg.normalize(dir) * grid.CELL

    if rl.GetMouseDelta() != 0 {
        future.ball.pos = world.ball.pos
        future.ball.vel = linalg.normalize(dir) * BALL_LAUNCH_SPEED

        clear(&bullet_path)
        for i in 0..<100 {
            physics.update(&future, 0.1)
            append(&bullet_path, future.ball.pos)
        }
    }
    if true do return

    clear(&bullet_path)
    append(&bullet_path, point)

    for _ in 0..<50 {
        is_my_teammate : bool // For passing

        // Get contact with lowest collision time.
        min_contact := Contact{ time = 1e19 }


        for actor, i in actors do if i != active_actor {
            contact := ray_vs_rect(point, dir, get_actor_rect(actor)) or_continue
            if contact.time >= min_contact.time do continue

            min_contact = contact
            is_my_teammate = actor.team == my_team
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

        if is_my_teammate {
            break // Pass the ball to teammate.
        }
    }
}

ball_path_index: int
ball_path_timer: f32
update_launch_ball :: proc(dt: f32) {
    physics.update(&world, dt)
    if rlutil.nearly_eq_vector(world.ball.vel, 0) {
        world.ball.vel = 0
        mode = .AimBall
    }
}

draw :: proc(cursor: rl.Vector2) {
    for wall in world.walls {
        polygon := wall.shape.(physics.Polygon)
        physics.polygon_draw_lines(polygon, rl.GREEN)
    }

    for wall in future.walls {
        polygon := wall.shape.(physics.Polygon)
        physics.polygon_draw_lines(polygon, rl.GREEN - {0, 0, 0, 100})
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

    // Draw the ball over the path so that it  looks like the path is coming out of ball.
    rl.DrawCircleV(world.ball.pos, grid.CELL, rl.GREEN)
    rl.DrawCircleV(future.ball.pos, grid.CELL, rl.GREEN - {0, 0, 0, 100})
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
    if t_far <= -linalg.F32_EPSILON || t_near <= -linalg.F32_EPSILON {
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