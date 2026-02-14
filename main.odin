package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import "core:reflect"
import rl "vendor:raylib"

Game_State :: struct {
	screen_width:  i32,
	screen_height: i32,
	board_left:    i32,
	board_top:     i32,
	square_length: i32,

	debug_show: bool,
	debug_line_height:   i32,
   	debug_column_width:  i32,
    debug_x: i32,
    debug_y: i32,
	dt:            f32,
	fps:           i32,
}


main :: proc() {
	gs := Game_State {
		screen_width = 1280,
		screen_height = 720,
		debug_show = true,
		debug_line_height = 20,
		debug_x = 10,
    	debug_y = 10,
	}
	using gs

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(screen_width, screen_height, "Chess")
	// rl.SetTargetFPS(60)

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		fps = rl.GetFPS()
		screen_width = rl.GetScreenWidth()
		screen_height = rl.GetScreenHeight()
		square_length = min(screen_width, screen_height) / 8
		board_left = (screen_width - 8 * square_length) / 2
		board_top = (screen_height - 8 * square_length) / 2


		// === DRAW ===

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// Board
		for r in 0..<8 {
			for c in 0..<8 {
				rl.DrawRectangle(
					board_left + i32(c) * square_length,
					board_top + i32(r) * square_length,
					square_length,
					square_length,
					rl.WHITE if (r + c) % 2 == 0 else rl.GREEN
				)
			}
		}

		// Debug text
		if debug_show {
			fields := []string{
			    fmt.tprintf("screen_width: %v", screen_width),
			    fmt.tprintf("screen_height: %v", screen_height),
			    fmt.tprintf("board_left: %v", board_left),
			    fmt.tprintf("board_top: %v", board_top),
			    fmt.tprintf("square_length: %v", square_length),
			    fmt.tprintf("dt: %v", dt),
			    fmt.tprintf("fps: %v", fps),
			}

			for field, i in fields {
			    rl.DrawText(fmt.ctprintf("%s", field), debug_x, debug_y + i32(i) * debug_line_height, 20, rl.WHITE)
			}
		}

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
