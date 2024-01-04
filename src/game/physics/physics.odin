package physics

import rl "vendor:raylib"

GRAVITY :: rl.Vector2{0, 10}
DT :: 1.0 / 240.0

World :: struct {
    ball: Body,
    walls: [dynamic]Body,
    collisions: [dynamic]Hit,

    dt_acc: f32,
}

@(require_results)
init :: proc() -> World {
    return World{}
}

deinit :: proc(w: World) {
    delete(w.collisions)
    delete(w.walls)
}

update :: proc(world: ^World, dt: f32) {
    world.dt_acc += dt
    for world.dt_acc >= DT {
        world.dt_acc -= DT
        fixed_update(world)
    }
}

@(private)
fixed_update :: proc(w: ^World) {
    w.ball.vel += GRAVITY * DT
    w.ball.pos += w.ball.vel * DT
    w.ball.aabb = get_aabb(w.ball)

    clear(&w.collisions)
    for &wall in w.walls {
        hit := collision_check(&w.ball, &wall) or_continue
        append(&w.collisions, hit)
    }

    for hit in w.collisions {
        w.ball.pos -= hit.depth * hit.normal
    }
}

new_wall_body :: proc(r: rl.Rectangle) -> Body {
    return Body{
        pos = {r.x, r.y},
        aabb = r,
        shape = polygon_init(
            {r.x, r.y},
            {r.x + r.width, r.y},
            {r.x + r.width, r.y + r.height},
            {r.x, r.y + r.height},
        ),
    }
}
