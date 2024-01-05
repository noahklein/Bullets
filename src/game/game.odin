package game

import "core:math/linalg"

import rl "vendor:raylib"

import "grid"
import "physics"
import "../ngui"

ACTOR_SIZE :: rl.Vector2{2*grid.CELL, 4*grid.CELL}
BALL_LAUNCH_SPEED :: 100

EDIT_WALL_POINT_RADIUS :: 2

mode: GameMode = .AimBall
// mode: GameMode = .EditWalls
GameMode :: enum {
    AimBall,
    LaunchBall,
    EditWalls,
}

world : physics.World
future: physics.World


bullet_path : [dynamic]rl.Vector2
player_path : [dynamic]rl.Vector2

Wall :: struct{
    rect: rl.Rectangle,
    color: rl.Color,
}

Team :: enum u8 { None, Blue, Red }

init :: proc(size: int) {
    world = physics.init()
    ball := physics.Body{shape = physics.Circle{grid.CELL}}
    append(&world.dynamics,  ball)
    append(&future.dynamics, ball)


    body_1 := physics.new_wall_body({0, 0, ACTOR_SIZE.x, ACTOR_SIZE.y})
    append(&world.dynamics, body_1)
    append(&future.dynamics, body_1)

    reserve(&bullet_path, 100)
    reserve(&player_path, 100)
}

deinit :: proc() {
    delete(bullet_path)
    delete(player_path)

    physics.deinit(world)
    physics.deinit(future)
}

update :: proc(dt: f32, cursor: rl.Vector2) {
    if rl.IsKeyPressed(.F3) {
        mode = .AimBall if mode == .EditWalls else .EditWalls
    }

    switch mode {
    case .AimBall:
        update_aim_ball(cursor)
        // Fire!
        if rl.IsMouseButtonPressed(.MIDDLE) {
            mode = .LaunchBall

            ball := &world.dynamics[0]
            ball.vel = linalg.normalize(cursor - ball.pos) * BALL_LAUNCH_SPEED

            player := &world.dynamics[1]
            player.vel = -ball.vel
        }
    case .LaunchBall: update_launch_ball(dt)
    case .EditWalls: update_edit_walls(cursor)
    }
}

update_aim_ball :: proc(cursor: rl.Vector2) {
    pad_rect :: proc(rect: rl.Rectangle, pad: rl.Vector2) -> rl.Rectangle {
        return {
            rect.x - pad.x/2,    rect.y - pad.y/2,
            rect.width  + pad.x, rect.height + pad.y,
        }
    }

    // Update ball position to aim towards cursor.
    player_padded_rect := pad_rect(world.dynamics[1].aabb, 2.25*grid.CELL)
    world.dynamics[0].pos = nearest_point_on_rect(cursor, player_padded_rect)

    if rl.GetMouseDelta() != 0 {
        for body, i in world.dynamics do future.dynamics[i] = body

        ball := &future.dynamics[0]
        ball.vel = linalg.normalize(cursor - ball.pos) * BALL_LAUNCH_SPEED

        player := &future.dynamics[1]
        player.vel = -ball.vel

        clear(&bullet_path)
        clear(&player_path)
        for _ in 0..<100 {
            physics.update(&future, 0.1)
            append(&bullet_path, ball.pos)
            append(&player_path, player.pos)
        }
    }
}

launch_ball_dt_acc: f32
update_launch_ball :: proc(dt: f32) {
    launch_ball_dt_acc += dt
    if launch_ball_dt_acc > 10 {
        launch_ball_dt_acc = 0
        mode = .AimBall
        return
    }
    physics.update(&world, dt)
}

update_edit_walls :: proc(cursor: rl.Vector2) {
    @(static) dragging_wall := -1
    @(static) dragging_vert := -1

    if rl.IsMouseButtonUp(.LEFT) {
        dragging_wall = -1
        dragging_vert = -1
        return
    }


    if rl.IsMouseButtonPressed(.LEFT) {
        dragging_wall, dragging_vert = edit_walls_hovered(cursor)
    }
    if dragging_wall == -1 || dragging_vert == -1 {
        return
    }

    wall := &world.walls[dragging_wall]
    polygon := &wall.shape.(physics.Polygon)
    polygon.vertices[dragging_vert] = cursor // Move cursor.
    wall.aabb = physics.body_get_aabb(wall^) // Polygon changed, re-calculate aabb.

    future.walls[dragging_wall] = wall^
}

edit_walls_hovered :: proc(cursor: rl.Vector2) -> (wall_i, vert_i: int){
    for &wall, wall_i in world.walls {
        poly := &wall.shape.(physics.Polygon)
        for vi in 0..<poly.count do if rl.CheckCollisionPointCircle(cursor, poly.vertices[vi], EDIT_WALL_POINT_RADIUS) {
            return wall_i, vi
        }
    }
    return -1, -1
}

draw :: proc(cursor: rl.Vector2) {
    for wall in world.walls {
        polygon := wall.shape.(physics.Polygon)
        physics.polygon_draw(polygon, rl.SKYBLUE)
        physics.polygon_draw_lines(polygon, rl.WHITE)

        if mode == .EditWalls do for i in 0..<polygon.count {
            v := polygon.vertices[i]

            color := rl.WHITE - {0, 0, 0, 100}
            if rl.CheckCollisionPointCircle(cursor, v, EDIT_WALL_POINT_RADIUS) {
                color.a += 100
            }
            rl.DrawCircleV(v, EDIT_WALL_POINT_RADIUS, color)
        }
    }

    if len(bullet_path) <= 1 {
        rl.DrawLineV(world.dynamics[0].pos, cursor, rl.WHITE)
    } else {
        for va, i in bullet_path[:len(bullet_path) - 1] {
            vb := bullet_path[i + 1]

            pct := f32(i + 1) / f32(len(bullet_path))
            color := ngui.lerp_color({30, 30, 30, 255}, rl.WHITE, pct)
            rl.DrawLineV(va, vb, color)
        }

        for va, i in player_path[:len(player_path) - 1] {
            vb := player_path[i + 1]

            pct := f32(i + 1) / f32(len(player_path))
            color := ngui.lerp_color({30, 30, 30, 255}, rl.WHITE, pct)
            rl.DrawLineV(va, vb, color)
        }
    }

    draw_world(world, 0)
    draw_world(future, 100)
}

draw_world :: proc(w: physics.World, $subtract_alpha: u8) {
    color_mod :: rl.Color{0, 0, 0, subtract_alpha}

    for body in w.dynamics do switch s in body.shape {
        case physics.Polygon:
            physics.polygon_draw(s, rl.YELLOW - color_mod)
            physics.polygon_draw_lines(s, rl.WHITE - color_mod)
        case physics.Circle:
            rl.DrawCircleV(body.pos, s.radius, rl.GREEN - color_mod)
    }
}

@(require_results)
nearest_point_on_rect :: proc(point: rl.Vector2, rect: rl.Rectangle) -> (cp: rl.Vector2) {
    cp.x = clamp(point.x, rect.x, rect.x+rect.width)
    cp.y = clamp(point.y, rect.y, rect.y+rect.height)
    return
}