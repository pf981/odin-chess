package main

import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
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

Piece :: struct {
	active:     bool,
	piece_type: Piece_Type,
	color:      Color,
	board_x:    i32,
	board_y:    i32,
	rect:       rl.Rectangle,
}

Game_State :: struct {
	screen_width:             i32,
	screen_height:            i32,
	board_left:               i32,
	board_top:                i32,
	square_length:            i32,
	piece_scale:              f32,
	pieces:                   [64]Piece,
	can_castle_kingside:      [2]bool,
	can_castle_queenside:     [2]bool,
	en_passant_target_square: [2]i32,
	debug_show:               bool,
	debug_line_height:        i32,
	debug_column_width:       i32,
	debug_x:                  i32,
	debug_y:                  i32,
	dt:                       f32,
	fps:                      i32,
}

main :: proc() {
	gs := Game_State {
		screen_width      = 1280,
		screen_height     = 720,
		square_length     = 720 / 8,
		board_left        = (1280 - 720) / 2,
		board_top         = (720 - 720) / 2,
		piece_scale       = 720.0 / 480.0,
		debug_show        = true,
		debug_line_height = 20,
		debug_x           = 10,
		debug_y           = 10,
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
	defer {
		for color in Color {
			for piece_type in Piece_Type {
				rl.UnloadTexture(pieces_textures[color][piece_type])
			}
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


		// === DRAW ===

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		// Board
		for r in 0 ..< 8 {
			for c in 0 ..< 8 {
				rl.DrawRectangle(
					board_left + i32(c) * square_length,
					board_top + i32(r) * square_length,
					square_length,
					square_length,
					rl.WHITE if (r + c) % 2 == 0 else rl.GREEN,
				)
			}
		}

		// Pieces
		for piece in pieces {
			if !piece.active {
				continue
			}
			rl.DrawTextureEx(pieces_textures[1][1], 0, 0, piece_scale, rl.WHITE)
		}

		// Debug text
		if debug_show {
			fields := []string {
				fmt.tprintf("screen_width: %v", screen_width),
				fmt.tprintf("screen_height: %v", screen_height),
				fmt.tprintf("board_left: %v", board_left),
				fmt.tprintf("board_top: %v", board_top),
				fmt.tprintf("square_length: %v", square_length),
				fmt.tprintf("dt: %v", dt),
				fmt.tprintf("fps: %v", fps),
			}

			for field, i in fields {
				rl.DrawText(
					fmt.ctprintf("%s", field),
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

load_fen :: proc(gs: ^Game_State, fen: string) -> bool {
	parts := strings.split(fen, " ")
	if len(parts) < 4 {
		fmt.println("Too few parts")
		return false
	}

	placement := parts[0]
	castling := parts[2]
	enpassant := parts[3]

	tmp_pieces: [64]Piece
	tmp_can_castle_k: [2]bool
	tmp_can_castle_q: [2]bool
	tmp_ep: [2]i32 = {-1, -1}

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

			index := rank * 8 + file

			rect := rl.Rectangle {
				x      = f32(gs.board_left + file * gs.square_length),
				y      = f32(gs.board_top + rank * gs.square_length),
				width  = f32(gs.square_length),
				height = f32(gs.square_length),
			}

			tmp_pieces[index] = Piece {
				active     = true,
				piece_type = pt,
				color      = color,
				board_x    = file,
				board_y    = rank,
				rect       = rect,
			}

			file += 1
			squares_in_rank += 1
		}
	}

	if rank != 7 || squares_in_rank != 8 {
		fmt.println("Unexpected rank or squares in rank")
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
	gs.pieces = tmp_pieces
	gs.can_castle_kingside = tmp_can_castle_k
	gs.can_castle_queenside = tmp_can_castle_q
	gs.en_passant_target_square = tmp_ep

	return true
}
