package game

import rl "vendor:raylib"

import "grid"

ACTOR_SIZE :: rl.Vector2{2*grid.CELL, 4*grid.CELL}

active_actor: int
actors: [dynamic]Actor
walls : [dynamic]Wall

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
}

update :: proc(dt: f32) {}

draw :: proc(cursor: rl.Vector2) {
    for wall in walls {
        rl.DrawRectangleRec(wall.rect, wall.color)
    }

    for actor in actors {
        color := rl.BLUE if actor.team == .Blue else rl.RED
        rl.DrawRectangleV(actor.pos, ACTOR_SIZE, color)
    }
}
