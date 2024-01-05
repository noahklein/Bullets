package physics

import "core:math/linalg"
import rl "vendor:raylib"

GRAVITY :: rl.Vector2{0, 9}
DT :: 1.0 / 240.0

World :: struct {
    dynamics, walls: [dynamic]Body,
    dt_acc: f32,
}

@(require_results)
init :: proc() -> World {
    return World{}
}

deinit :: proc(w: World) {
    delete(w.walls)
    delete(w.dynamics)
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
    for &body in w.dynamics {
        body.vel += GRAVITY * DT
        body_move(&body, body.vel * DT)
    }

    for &body in w.dynamics {
        for wall in w.walls {
            hit := collision_check(body, wall) or_continue
            body_move(&body, -hit.depth * hit.normal)
            body.vel -= -2 * linalg.dot(-body.vel, hit.normal) * hit.normal // Bounce
        }
    }

    for &body, i in w.dynamics[:len(w.dynamics) - 1] {
        for &other in w.dynamics[i+1:] {
            hit := collision_check(body, other) or_continue

            delta_p := hit.depth * hit.normal
            body_move(&body, -delta_p / 2)
            body_move(&other, delta_p / 2)


            rel_vel := other.vel - body.vel

            delta_v := -2 * linalg.dot(rel_vel, hit.normal) * hit.normal
            body.vel  -= delta_v / 2
            other.vel += delta_v / 2
        }
    }
}

new_wall_body :: proc(r: rl.Rectangle) -> Body {
    poly := polygon_init(
        {r.x, r.y},
        {r.x + r.width, r.y},
        {r.x + r.width, r.y + r.height},
        {r.x, r.y + r.height},
    )

    return Body{
        pos = {r.x + r.width/2, r.y + r.height/2},
        aabb = r,
        shape = poly,
    }
}
