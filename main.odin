#+feature using-stmt

package main

import "core:fmt"
import "core:math"
import "core:reflect"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Fixed_Cstring :: struct($Capacity: int) {
	buffer: [Capacity]byte,
	length: int,
}

append :: proc(ch: byte, s: ^Fixed_Cstring($Capacity)) -> bool {
	if s.length >= Capacity - 1 {
		return false
	}
	s.buffer[s.length] = ch
	s.length += 1
	s.buffer[s.length] = 0
	return true
}

truncate :: proc(s: ^Fixed_Cstring($Capacity)) {
	s.length = 0
	s.buffer[s.length] = 0
}

pop :: proc(s: ^Fixed_Cstring($Capacity)) {
	if s.length == 0 {return}
	s.length -= 1
	s.buffer[s.length] = 0
}

to_cstring :: proc(s: ^Fixed_Cstring($Capacity)) -> cstring {
	return cstring(&s.buffer[0])
}


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
	Console,
	Game_Over,
}

Piece :: struct {
	active:     bool,
	piece_type: Piece_Type,
	color:      Color,
}

Bitboard :: bit_set[0 ..< 64]


Game :: struct {
	is_completed:             bool,
	completed_reason:         enum {
		Checkmate,
		Stalemate,
		// TODO: Draw Offer, Insufficient Materials, Resignation, 50 moves, Three fold etc
	},
	completed_outcome:        enum {
		White_Win,
		Black_Win,
		Draw,
	},
	board:                    [8][8]Piece,
	active_color:             Color,
	can_castle_kingside:      [Color]bool,
	can_castle_queenside:     [Color]bool,
	en_passant_target_square: [2]i32,
	moves:                    [8][8]Bitboard,
	fen:                      string,
	fen_buffer:               Fixed_Cstring(128),

	// For sounds
	in_check:                 bool,
	last_move_was_capture:    bool,
	last_move_was_castle:     bool,
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
	key_show_debug_pressed:            bool,
	key_show_console_pressed:          bool,
	key_backspace_pressed:             bool,
	key_enter_pressed:                 bool,
	key_ctrl_v_pressed:                bool,
	key_last_char_pressed:             u8,

	// Key Mapping
	key_show_attacked_squares:         rl.KeyboardKey,
	key_show_debug:                    rl.KeyboardKey,
	key_show_console:                  rl.KeyboardKey,

	// Colors
	color_white_square:                rl.Color,
	color_black_square:                rl.Color,
	color_move_to:                     rl.Color,
	color_attacked:                    rl.Color,
	color_console_bg:                  rl.Color,
	color_console_font:                rl.Color,

	// Console
	console_font_size:                 f32,
	console_input_buffer:              Fixed_Cstring(256),

	// Debug
	debug_show:                        bool,
	debug_show_attacked_squares:       bool,
	debug_line_height:                 f32,
	debug_x:                           f32,
	debug_y:                           f32,
	dt:                                f32,
	fps:                               i32,
}

main :: proc() {
	using gs := Game_State {
		screen_width              = 1920,
		screen_height             = 1080,
		square_length             = 1080 / 8,
		board_left                = (1920 - 1080) / 2,
		board_top                 = (1080 - 1080) / 2,
		piece_scale               = 1080.0 / 8 / 480.0,
		key_show_attacked_squares = rl.KeyboardKey.F1,
		key_show_debug            = rl.KeyboardKey.F2,
		key_show_console          = rl.KeyboardKey.GRAVE,
		color_white_square        = rl.GetColor(0xEBECD0FF),
		color_black_square        = rl.GetColor(0x739552FF),
		color_move_to             = rl.Fade(rl.BLUE, 0.7),
		color_attacked            = rl.Fade(rl.RED, 0.7),
		color_console_bg          = rl.Fade(rl.GetColor(0x232627FF), 0.95),
		color_console_font        = rl.WHITE,
		console_font_size         = 20,
		debug_show                = true,
		debug_line_height         = 20,
		debug_x                   = 10,
		debug_y                   = 10,
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
	sound_check := rl.LoadSound("assets/check.wav")
	// https://pixabay.com/sound-effects/film-special-effects-board-game-pieces-59039/
	sound_start := rl.LoadSound("assets/start.wav")
	defer {
		rl.UnloadSound(sound_pickup)
		rl.UnloadSound(sound_place)
		rl.UnloadSound(sound_take)
		rl.UnloadSound(sound_castle)
		rl.UnloadSound(sound_check)
		rl.UnloadSound(sound_start)
	}

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

	font := rl.LoadFontEx("assets/FiraMonoNerdFontMono-Regular.otf", 64, nil, 0)
	rl.SetTextureFilter(font.texture, .BILINEAR)
	defer rl.UnloadFont(font)

	reset_game(&gs.game)
	rl.PlaySound(sound_start)

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
		mouse_board_x = i32(math.floor((mouse_pos[0] - f32(board_left)) / f32(square_length)))
		mouse_board_y = i32(math.floor((mouse_pos[1] - f32(board_top)) / f32(square_length)))
		mouse_board_is_valid =
			0 <= mouse_board_x && mouse_board_x < 8 && 0 <= mouse_board_y && mouse_board_y < 8
		key_show_attacked_squares_pressed = rl.IsKeyPressed(key_show_attacked_squares)
		key_show_debug_pressed = rl.IsKeyPressed(key_show_debug)
		key_show_console_pressed = rl.IsKeyPressed(key_show_console)
		key_backspace_pressed = rl.IsKeyPressed(rl.KeyboardKey.BACKSPACE)
		key_enter_pressed = rl.IsKeyPressed(rl.KeyboardKey.ENTER)
		key_ctrl_v_pressed =
			rl.IsKeyPressed(.V) && (rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL))

		last_key_pressed := rl.GetCharPressed()
		key_last_char_pressed = {}
		if last_key_pressed >= 32 && last_key_pressed < 127 && !key_show_console_pressed {
			key_last_char_pressed = u8(last_key_pressed)
			if last_key_pressed == 'v' {
				last_key_pressed = {}
			}
		}


		// === STATE ===

		if is_completed && ui_state != .Console {
			ui_state = .Game_Over
		}

		if key_show_attacked_squares_pressed {
			debug_show_attacked_squares = !debug_show_attacked_squares
		}
		if key_show_debug_pressed {
			debug_show = !debug_show
		}
		if key_show_console_pressed {
			ui_state = .Console if ui_state != .Console else .Default
			truncate(&console_input_buffer)
		}

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
				   int(mouse_board_x + 8 * mouse_board_y) in
					   moves[dragging_piece_x][dragging_piece_y] {
					make_move(
						&game,
						dragging_piece_x,
						dragging_piece_y,
						mouse_board_x,
						mouse_board_y,
					)

					if in_check {
						rl.PlaySound(sound_check)
					} else if last_move_was_capture {
						rl.PlaySound(sound_take)
					} else if last_move_was_castle {
						rl.PlaySound(sound_castle)
					} else {
						rl.PlaySound(sound_place)
					}
				}
				ui_state = .Default
			}

		case .Console:
			if key_ctrl_v_pressed {
				for c in string(rl.GetClipboardText()) {
					append(byte(c), &console_input_buffer)
				}
			}
			if key_last_char_pressed != 0 {
				append(key_last_char_pressed, &console_input_buffer)
			}
			if key_backspace_pressed {
				pop(&console_input_buffer)
			}
			if key_enter_pressed {
				ui_state = .Default
				command := string(to_cstring(&console_input_buffer))
				parts := strings.split_n(command, " ", 2)
				op := parts[0]

				if op == "new" {
					gs.ui_state = .Default
					reset_game(&gs.game)
					rl.PlaySound(sound_start)
				} else if op == "loadfen" && len(parts) == 2 {
					gs.ui_state = .Default
					if !load_fen(&gs.game, parts[1]) {
						fmt.println("Unable to load FEN")
					} else {
						rl.PlaySound(sound_start)
					}
				} else if op == "fps" && len(parts) == 2 {
					if target_fps, ok := strconv.parse_int(parts[1]); ok {
						rl.SetTargetFPS(i32(target_fps))
					}
				} else {
					fmt.printfln("Unable to process command '%s'", command)
				}

				truncate(&console_input_buffer)
			}

		case .Game_Over:
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
					rl.DrawCircle(
						board_left + square_length * i32(x) + square_length / 2,
						board_top + square_length * i32(y) + square_length / 2,
						0.1 * f32(square_length) / 2,
						color_move_to,
					)
				}

				// Attacking dot
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

		// Row and column annotation
		for y in 0 ..< 8 {
			rl.DrawTextEx(
				font,
				fmt.ctprintf("%d", 8 - y),
				{
					f32(board_left + square_length * i32(0)) + f32(square_length) * 0.05,
					f32(board_top + square_length * i32(y)) + f32(square_length) * 0.05,
				},
				30 * f32(square_length) / 135,
				1,
				color_black_square if y % 2 == 1 else color_white_square,
			)
		}
		for c, x in 'a' ..= 'h' {
			rl.DrawTextEx(
				font,
				fmt.ctprintf("%c", c),
				{
					f32(board_left + square_length * i32(x)) + f32(square_length) * 0.85,
					f32(board_top + square_length * i32(7)) + f32(square_length) * 0.8,
				},
				30 * f32(square_length) / 135,
				1,
				color_black_square if x % 2 == 0 else color_white_square,
			)
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
			row := 0
			for name in names {
				if name == "game" || name == "console_input_buffer" {
					continue
				}
				val_any := reflect.struct_field_value_by_name(gs, name)

				rl.DrawTextEx(
					font,
					fmt.ctprintf("%s: %v\n", name, val_any),
					{debug_x, debug_y + f32(row) * debug_line_height},
					18,
					1,
					rl.WHITE,
				)
				row += 1
			}

			row += 1

			names = reflect.struct_field_names(typeid_of(Game))
			for name in names {
				if name == "board" || name == "moves" {
					continue
				}
				val_any := reflect.struct_field_value_by_name(game, name)

				rl.DrawTextEx(
					font,
					fmt.ctprintf("%s: %v\n", name, val_any),
					{debug_x, debug_y + f32(row) * debug_line_height},
					18,
					1,
					rl.WHITE,
				)
				row += 1
			}
		}

		// Console
		if ui_state == .Console {
			console_y := 0.5 * f32(screen_height)
			if console_y < 100 {
				console_y = f32(screen_height)
			}

			rl.DrawRectangle(0, i32(console_y - 50), screen_width, 50, color_console_bg)

			dimensions := rl.MeasureTextEx(
				font,
				to_cstring(&console_input_buffer),
				console_font_size,
				1,
			)

			rl.DrawTextEx(
				font,
				to_cstring(&console_input_buffer),
				{
					(f32(screen_width) / 2) - (dimensions[0] / 2),
					console_y - 50 / 2 - (dimensions[1] / 2),
				},
				console_font_size,
				1,
				color_console_font,
			)
		}

		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}
