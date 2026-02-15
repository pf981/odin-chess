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
	attacked_squares:         Bitboard,
	moves:                    [8][8]Bitboard,
}

Game_State :: struct {
	ui_state:             UI_State,
	// Screen
	screen_width:         i32,
	screen_height:        i32,
	board_left:           i32,
	board_top:            i32,
	square_length:        i32,
	piece_scale:          f32,

	// Game
	using game:           Game,
	dragging_piece_x:     i32,
	dragging_piece_y:     i32,

	// Input
	left_mouse_clicked:   bool,
	mouse_pos:            [2]f32,
	mouse_board_is_valid: bool,
	mouse_board_x:        i32,
	mouse_board_y:        i32,

	// Colors
	white_square_color:   rl.Color,
	black_square_color:   rl.Color,
	move_to_color:        rl.Color,

	// Debug
	debug_show:           bool,
	debug_line_height:    i32,
	debug_column_width:   i32,
	debug_x:              i32,
	debug_y:              i32,
	dt:                   f32,
	fps:                  i32,
}

main :: proc() {
	gs := Game_State {
		screen_width       = 1280,
		screen_height      = 720,
		square_length      = 720 / 8,
		board_left         = (1280 - 720) / 2,
		board_top          = (720 - 720) / 2,
		piece_scale        = 720.0 / 8 / 480.0,
		white_square_color = rl.GetColor(0xEBECD0FF),
		black_square_color = rl.GetColor(0x739552FF),
		move_to_color      = rl.Fade(rl.BLUE, 0.3),
		debug_show         = true,
		debug_line_height  = 20,
		debug_x            = 10,
		debug_y            = 10,
	}
	using gs

	if !load_fen(&gs, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1") {
		fmt.println("Unable to load FEN")
	}

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(screen_width, screen_height, "Chess")
	defer rl.CloseWindow()

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
					black_square_color if (x + y) % 2 == 0 else white_square_color,
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
						move_to_color,
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

update_moves :: proc(gs: ^Game_State) {
	// state:                    State,
	// board:                    [8][8]Piece,
	// active_color:             Color,
	// can_castle_kingside:      [2]bool,
	// can_castle_queenside:     [2]bool,
	// en_passant_target_square: [2]i32,
	// moves:                    [8][8]Bitboard,
	// dragging_piece_x:         i32,
	// dragging_piece_y:         i32,
	using gs

	in_bounds :: #force_inline proc(x: i32, y: i32) -> bool {
		return x >= 0 && x < 8 && y >= 0 && y < 8
	}

	is_square_attacked :: proc(board: [8][8]Piece, tx: i32, ty: i32, by: Color) -> bool {
		for x in 0 ..< 8 {
			for y in 0 ..< 8 {
				p := board[x][y]
				if !p.active || p.color != by {
					continue
				}

				dx := tx - i32(x)
				dy := ty - i32(y)

				switch p.piece_type {
				case .Pawn:
					dir := i32(1 if (by == .White) else -1)
					if dy == dir && (dx == 1 || dx == -1) {
						return true
					}

				case .Knight:
					if (abs(dx) == 1 && abs(dy) == 2) || (abs(dx) == 2 && abs(dy) == 1) {
						return true
					}

				case .Bishop, .Rook, .Queen:
					step_x: i32 = 0
					step_y: i32 = 0

					if p.piece_type == .Bishop || p.piece_type == .Queen {
						if abs(dx) == abs(dy) && dx != 0 {
							step_x = dx / abs(dx)
							step_y = dy / abs(dy)
						}
					}
					if p.piece_type == .Rook || p.piece_type == .Queen {
						if dx == 0 && dy != 0 {
							step_x = 0
							step_y = dy / abs(dy)
						}
						if dy == 0 && dx != 0 {
							step_x = dx / abs(dx)
							step_y = 0
						}
					}

					if step_x != 0 || step_y != 0 {
						cx := i32(x) + step_x
						cy := i32(y) + step_y
						for in_bounds(cx, cy) {
							if cx == tx && cy == ty {
								return true
							}
							if board[cx][cy].active {
								break
							}
							cx += step_x
							cy += step_y
						}
					}

				case .King:
					if abs(dx) <= 1 && abs(dy) <= 1 {
						return true
					}
				}
			}
		}
		return false
	}

	// add_move :: proc(
	// 	board: [8][8]Piece,
	// 	active_color: Color,
	// 	x: i32,
	// 	y: i32,
	// 	nx: i32,
	// 	ny: i32,
	// 	king_x: i32,
	// 	king_y: i32,
	// ) {
	// 	board := board
	// 	if !in_bounds(nx, ny) {
	// 		return
	// 	}
	// 	target := board[nx][ny]
	// 	if target.active && target.color == active_color {
	// 		return
	// 	}

	// 	// simulate
	// 	backup_from := board[x][y]
	// 	backup_to := board[nx][ny]

	// 	board[nx][ny] = backup_from
	// 	board[x][y] = Piece{}

	// 	test_king_x := king_x
	// 	test_king_y := king_y
	// 	if p.piece_type == .King {
	// 		test_king_x = nx
	// 		test_king_y = ny
	// 	}

	// 	in_check := is_square_attacked(
	// 		test_king_x,
	// 		test_king_y,
	// 		.Black if active_color == .White else .White,
	// 	)

	// 	// restore
	// 	board[x][y] = backup_from
	// 	board[nx][ny] = backup_to

	// 	if !in_check {
	// 		moves[x][y] += Bitboard{ny * 8 + nx}
	// 	}
	// }

	king_x: i32
	king_y: i32
	outer: for x in 0 ..< 8 {
		for y in 0 ..< 8 {
			p := board[x][y]
			if p.active && p.color == active_color && p.piece_type == .King {
				king_x = i32(x)
				king_y = i32(y)
				break outer
			}
		}
	}

	// Generate candidate moves
	candidate_moves: [8][8]Bitboard
	for x in 0 ..< 8 {
		for y in 0 ..< 8 {
			p := board[x][y]
			if !p.active || p.color != active_color {continue}
			switch p.piece_type {
			case .Pawn:
			case .Rook:
			case .Knight:
			case .Bishop:
			case .Queen:
			case .King:
			}
		}
	}

	// Simulate each candidate move, determine if results in self-check. Self-check moves are excluded.

	// If there are no valid moves: if it is check then it is checkmate, if it is not check then it is stalemate.
	// moves = candidate_moves
}

/*
iterate over board to get attacked_squares bitboard
Determine if in check
moves_active 8x8 bitboards

King: Castle (avoid through check), avoid check
pawn captures, pawn double moves, enpassent, promotion
Can't move if results in check?

When in check, can block (sometimes)
When not in check, cannot move a piece resulting in discovered check on yourself
Sounds like, I have to simulate the move, check if it is check and only accept it as a candidate if it doesn't result in check

---
king_x, kingy
square_is_attacked()
*/

load_fen :: proc(gs: ^Game_State, fen: string) -> bool {
	parts := strings.split(fen, " ")
	if len(parts) < 4 {
		fmt.println("Too few parts")
		return false
	}

	placement := parts[0]
	active_color := parts[1]
	castling := parts[2]
	enpassant := parts[3]

	tmp_board: [8][8]Piece
	tmp_can_castle_k: [2]bool
	tmp_can_castle_q: [2]bool
	tmp_ep: [2]i32 = {-1, -1}
	tmp_active_color: Color

	rank: i32 = 0
	file: i32 = 0
	squares_in_rank: i32 = 0

	for ch in placement {
		switch {
		case ch == '/':
			if squares_in_rank != 8 {
				fmt.println("Too many squares in rank", squares_in_rank)
				return false
			}
			rank += 1
			file = 0
			squares_in_rank = 0
		case ch >= '1' && ch <= '8':
			empty := i32(ch - '0')
			if file + empty > 8 {
				fmt.println("Too many squares in file")
				return false
			}
			file += empty
			squares_in_rank += empty
		case:
			if rank >= 8 || file >= 8 {
				return false
			}

			color := Color.White
			if ch >= 'a' && ch <= 'z' {
				color = Color.Black
			}

			pt: Piece_Type
			switch unicode.to_lower(ch) {
			case 'p':
				pt = .Pawn
			case 'r':
				pt = .Rook
			case 'n':
				pt = .Knight
			case 'b':
				pt = .Bishop
			case 'q':
				pt = .Queen
			case 'k':
				pt = .King
			case:
				return false
			}

			tmp_board[file][rank] = Piece {
				active     = true,
				piece_type = pt,
				color      = color,
			}

			file += 1
			squares_in_rank += 1
		}
	}

	if rank != 7 || squares_in_rank != 8 {
		fmt.println("Unexpected rank or squares in rank")
		return false
	}

	switch active_color {
	case "w":
		tmp_active_color = .White
	case "b":
		tmp_active_color = .Black
	case:
		fmt.printfln("Unexpected active color")
		return false
	}

	if castling != "-" {
		for ch in castling {
			switch ch {
			case 'K':
				tmp_can_castle_k[Color.White] = true
			case 'Q':
				tmp_can_castle_q[Color.White] = true
			case 'k':
				tmp_can_castle_k[Color.Black] = true
			case 'q':
				tmp_can_castle_q[Color.Black] = true
			case:
				fmt.println("Unexpected castling")
				return false
			}
		}
	}

	if enpassant != "-" {
		if len(enpassant) != 2 {
			fmt.println("Unexpected enpassent")
			return false
		}

		file_char := enpassant[0]
		rank_char := enpassant[1]

		if file_char < 'a' || file_char > 'h' {
			fmt.println("Unexpected file char")
			return false
		}
		if rank_char < '1' || rank_char > '8' {
			fmt.println("Unexpected rank char")
			return false
		}

		x := i32(file_char - 'a')
		y := 8 - i32(rank_char - '0')

		tmp_ep = {x, y}
	}

	// Validation successful. Commit atomically.
	gs.board = tmp_board
	gs.can_castle_kingside = tmp_can_castle_k
	gs.can_castle_queenside = tmp_can_castle_q
	gs.en_passant_target_square = tmp_ep
	gs.active_color = tmp_active_color
	gs.ui_state = .Default

	update_moves(gs)

	return true
}
