package main

import "core:fmt"
import "core:reflect"
import "core:strings"
import "core:unicode"
import rl "vendor:raylib"

Piece_Type :: enum {
	Pawn,
	Rook,
	Knight,
	Bishop,
	Queen,
	King,
}

Color :: enum {
	White,
	Black,
}

UI_State :: enum {
	Default,
	Dragging,
	// TODO: Menu, Console
}

Piece :: struct {
	active:     bool,
	piece_type: Piece_Type,
	color:      Color,
}

Bitboard :: bit_set[0 ..< 64]

Game :: struct {
	is_completed:             bool,
	// completed_reason Checkmate, Stalemate, Draw Offer, Insufficient Materials etc
	// completed_outcome (0-1, 1-0, 1/2-1/2)
	board:                    [8][8]Piece,
	active_color:             Color,
	can_castle_kingside:      [2]bool,
	can_castle_queenside:     [2]bool,
	en_passant_target_square: [2]i32,
	moves:                    [8][8]Bitboard,
}

Game_State :: struct {
	ui_state:                          UI_State,

	// Screen
	screen_width:                      i32,
	screen_height:                     i32,
	board_left:                        i32,
	board_top:                         i32,
	square_length:                     i32,
	piece_scale:                       f32,

	// Game
	using game:                        Game,
	dragging_piece_x:                  i32,
	dragging_piece_y:                  i32,

	// Input
	left_mouse_clicked:                bool,
	mouse_pos:                         [2]f32,
	mouse_board_is_valid:              bool,
	mouse_board_x:                     i32,
	mouse_board_y:                     i32,
	key_show_attacked_squares_pressed: bool,

	// Key Mapping
	key_show_attacked_squares:         rl.KeyboardKey,

	// Colors
	color_white_square:                rl.Color,
	color_black_square:                rl.Color,
	color_move_to:                     rl.Color,
	color_attacked:                    rl.Color,

	// Debug
	debug_show:                        bool,
	debug_show_attacked_squares:       bool,
	debug_line_height:                 i32,
	debug_column_width:                i32,
	debug_x:                           i32,
	debug_y:                           i32,
	dt:                                f32,
	fps:                               i32,
}

main :: proc() {
	gs := Game_State {
		screen_width              = 1280,
		screen_height             = 720,
		square_length             = 720 / 8,
		board_left                = (1280 - 720) / 2,
		board_top                 = (720 - 720) / 2,
		piece_scale               = 720.0 / 8 / 480.0,
		key_show_attacked_squares = rl.KeyboardKey.F1,
		color_white_square        = rl.GetColor(0xEBECD0FF),
		color_black_square        = rl.GetColor(0x739552FF),
		color_move_to             = rl.Fade(rl.BLUE, 0.7),
		color_attacked            = rl.Fade(rl.RED, 0.7),
		debug_show                = true,
		debug_line_height         = 20,
		debug_x                   = 10,
		debug_y                   = 10,
	}
	using gs

	if !load_fen(&gs, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") {
		fmt.println("Unable to load FEN")
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(screen_width, screen_height, "Chess")
	defer rl.CloseWindow()
	rl.SetTargetFPS(120)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	// https://freesound.org/people/180118/sounds/442887/
	sound_pickup := rl.LoadSound("assets/pickup.wav")
	sound_place := rl.LoadSound("assets/place.wav")
	sound_take := rl.LoadSound("assets/take.wav")
	sound_castle := rl.LoadSound("assets/castle.wav")
	defer rl.UnloadSound(sound_pickup)
	defer rl.UnloadSound(sound_place)
	defer rl.UnloadSound(sound_take)
	defer rl.UnloadSound(sound_castle)

	// https://gitlab.com/zulban/chesscraft-creative-commons/-/tree/master/pieces/01_classic
	pieces_textures: [2][6]rl.Texture2D
	pieces_textures[Color.White][Piece_Type.Pawn] = rl.LoadTexture("assets/w-pawn.png")
	pieces_textures[Color.White][Piece_Type.Rook] = rl.LoadTexture("assets/w-rook.png")
	pieces_textures[Color.White][Piece_Type.Knight] = rl.LoadTexture("assets/w-knight.png")
	pieces_textures[Color.White][Piece_Type.Bishop] = rl.LoadTexture("assets/w-bishop.png")
	pieces_textures[Color.White][Piece_Type.Queen] = rl.LoadTexture("assets/w-queen.png")
	pieces_textures[Color.White][Piece_Type.King] = rl.LoadTexture("assets/w-king.png")
	pieces_textures[Color.Black][Piece_Type.Pawn] = rl.LoadTexture("assets/b-pawn.png")
	pieces_textures[Color.Black][Piece_Type.Rook] = rl.LoadTexture("assets/b-rook.png")
	pieces_textures[Color.Black][Piece_Type.Knight] = rl.LoadTexture("assets/b-knight.png")
	pieces_textures[Color.Black][Piece_Type.Bishop] = rl.LoadTexture("assets/b-bishop.png")
	pieces_textures[Color.Black][Piece_Type.Queen] = rl.LoadTexture("assets/b-queen.png")
	pieces_textures[Color.Black][Piece_Type.King] = rl.LoadTexture("assets/b-king.png")
	defer for color in Color {
		for piece_type in Piece_Type {
			rl.UnloadTexture(pieces_textures[color][piece_type])
		}
	}

	for !rl.WindowShouldClose() {
		dt = rl.GetFrameTime()
		fps = rl.GetFPS()
		if rl.IsWindowResized() {
			screen_width = rl.GetScreenWidth()
			screen_height = rl.GetScreenHeight()
			square_length = min(screen_width, screen_height) / 8
			board_left = (screen_width - 8 * square_length) / 2
			board_top = (screen_height - 8 * square_length) / 2
			piece_scale = f32(square_length) / 480.0
		}


		// === INPUT ===

		left_mouse_clicked = rl.IsMouseButtonDown(.LEFT)
		mouse_pos = rl.GetMousePosition()
		mouse_board_x = i32((mouse_pos[0] - f32(board_left)) / f32(square_length))
		mouse_board_y = i32((mouse_pos[1] - f32(board_top)) / f32(square_length))
		mouse_board_is_valid =
			0 <= mouse_board_x && mouse_board_x < 8 && 0 <= mouse_board_y && mouse_board_y < 8
		key_show_attacked_squares_pressed = rl.IsKeyPressed(key_show_attacked_squares)


		// === STATE ===

		switch ui_state {
		case .Default:
			if left_mouse_clicked &&
			   mouse_board_is_valid &&
			   board[mouse_board_x][mouse_board_y].active &&
			   board[mouse_board_x][mouse_board_y].color == active_color {
				dragging_piece_x = mouse_board_x
				dragging_piece_y = mouse_board_y
				ui_state = .Dragging
				rl.PlaySound(sound_pickup)
			}


		case .Dragging:
			if !left_mouse_clicked {
				if mouse_board_is_valid &&
				   !(mouse_board_x == dragging_piece_x && mouse_board_y == dragging_piece_y) {
					if board[mouse_board_x][mouse_board_y].active {
						rl.PlaySound(sound_take)
					} else {
						rl.PlaySound(sound_place)
					}
					board[mouse_board_x][mouse_board_y] = board[dragging_piece_x][dragging_piece_y]
					board[dragging_piece_x][dragging_piece_y].active = false
					active_color = .White if active_color == .Black else .Black

					update_moves(&gs)
				}
				ui_state = .Default
			}
		}


		if key_show_attacked_squares_pressed {
			debug_show_attacked_squares = !debug_show_attacked_squares
		}


		// === DRAW ===

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		for x in 0 ..< 8 {
			for y in 0 ..< 8 {
				// Background
				rl.DrawRectangle(
					board_left + i32(x) * square_length,
					board_top + i32(y) * square_length,
					square_length,
					square_length,
					color_black_square if (x + y) % 2 == 0 else color_white_square,
				)

				// Piece
				if board[x][y].active &&
				   !(ui_state == .Dragging &&
						   i32(x) == dragging_piece_x &&
						   i32(y) == dragging_piece_y) {

					rl.DrawTextureEx(
						pieces_textures[board[x][y].color][board[x][y].piece_type],
						{
							f32(board_left + square_length * i32(x)),
							f32(board_top + square_length * i32(y)),
						},
						0,
						piece_scale,
						rl.WHITE,
					)
				}

				// Move-to dot
				if ui_state == .Dragging &&
				   (x + (y * 8)) in moves[dragging_piece_x][dragging_piece_y] {
					// if state == .Dragging {
					rl.DrawCircle(
						board_left + square_length * i32(x) + square_length / 2,
						board_top + square_length * i32(y) + square_length / 2,
						0.1 * f32(square_length) / 2,
						color_move_to,
					)
				}

				// Attacking dot
				// if ui_state == .Dragging &&
				//    (x + (y * 8)) in moves[dragging_piece_x][dragging_piece_y] {
				if debug_show_attacked_squares && is_square_attacked(game, i32(x), i32(y)) {
					rl.DrawCircle(
						board_left + square_length * i32(x) + square_length / 2,
						board_top + square_length * i32(y) + square_length / 2,
						0.1 * f32(square_length) / 2,
						color_attacked,
					)
				}
			}
		}

		// Dragged piece
		if ui_state == .Dragging {
			piece := board[dragging_piece_x][dragging_piece_y]
			rl.DrawTextureEx(
				pieces_textures[piece.color][piece.piece_type],
				{mouse_pos[0] - f32(square_length) / 2, mouse_pos[1] - f32(square_length) / 2},
				0,
				piece_scale,
				rl.WHITE,
			)
		}

		// Debug text
		if debug_show {
			names := reflect.struct_field_names(typeid_of(Game_State))
			for name, i in names {
				if name == "board" || name == "moves" || name == "game" {
					continue
				}
				val_any := reflect.struct_field_value_by_name(gs, name)

				rl.DrawText(
					fmt.ctprintf("%s: %v\n", name, val_any),
					debug_x,
					debug_y + i32(i) * debug_line_height,
					20,
					rl.WHITE,
				)
			}
		}

		rl.EndDrawing()
		// free_all(context.temp_allocator)
	}
}
