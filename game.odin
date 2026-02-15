
package main

import "core:fmt"
import "core:strings"
import "core:unicode"

in_bounds :: #force_inline proc(x: i32, y: i32) -> bool {
	return x >= 0 && x < 8 && y >= 0 && y < 8
}

is_square_attacked :: proc(using game: Game, tx: i32, ty: i32) -> bool {
	by := Color(.Black if active_color == .White else .White)

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
				dir := i32(-1 if (by == .White) else 1)
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


update_moves :: proc(using game: ^Game) {
	moves = {}
	if is_completed {
		return
	}

	add_move_if_legal :: proc(using game: ^Game, from_x: i32, from_y: i32, to_x: i32, to_y: i32) {
		orig_from := board[from_x][from_y]
		orig_to := board[to_x][to_y]

		board[to_x][to_y] = orig_from
		board[from_x][from_y] = Piece{}

		is_valid := true

		// Find king of active_color
		outer: for x in 0 ..< 8 {
			for y in 0 ..< 8 {
				p := board[x][y]
				if p.active && p.color == active_color && p.piece_type == .King {
					if is_square_attacked(game^, i32(x), i32(y)) {
						is_valid = false
					}
					break outer
				}
			}
		}

		// Restore board
		board[from_x][from_y] = orig_from
		board[to_x][to_y] = orig_to

		if is_valid {
			idx := to_x + to_y * 8
			moves[from_x][from_y] += Bitboard{int(idx)}
		}
	}

	for x in 0 ..< 8 {
		for y in 0 ..< 8 {
			p := board[x][y]
			if !p.active || p.color != active_color {
				continue
			}

			ix := i32(x)
			iy := i32(y)

			switch p.piece_type {

			case .Pawn:
				dir := i32(-1 if active_color == .White else 1)
				start_rank := i32(6 if active_color == .White else 1)

				// forward 1
				nx, ny := ix, iy + dir
				if in_bounds(nx, ny) && !board[nx][ny].active {
					add_move_if_legal(game, ix, iy, nx, ny)

					// forward 2
					if iy == start_rank {
						ny2 := iy + 2 * dir
						if in_bounds(nx, ny2) && !board[nx][ny2].active {
							add_move_if_legal(game, ix, iy, nx, ny2)
						}
					}
				}

				// captures
				for dx in ([]i32{-1, 1}) {
					nx = ix + dx
					ny = iy + dir
					if in_bounds(nx, ny) {
						t := board[nx][ny]
						if (t.active && t.color != active_color) ||
						   (en_passant_target_square == {nx, ny}) {
							add_move_if_legal(game, ix, iy, nx, ny)
						}
					}
				}

			case .Knight:
				offsets := [8][2]i32 {
					{1, 2},
					{2, 1},
					{2, -1},
					{1, -2},
					{-1, -2},
					{-2, -1},
					{-2, 1},
					{-1, 2},
				}
				for o in offsets {
					nx := ix + o[0]
					ny := iy + o[1]
					if in_bounds(nx, ny) {
						t := board[nx][ny]
						if !t.active || t.color != active_color {
							add_move_if_legal(game, ix, iy, nx, ny)
						}
					}
				}

			case .Bishop, .Rook, .Queen:
				dirs: [8][2]i32
				count := 0

				if p.piece_type == .Bishop || p.piece_type == .Queen {
					dirs[count] = {1, 1}; count += 1
					dirs[count] = {1, -1}; count += 1
					dirs[count] = {-1, 1}; count += 1
					dirs[count] = {-1, -1}; count += 1
				}
				if p.piece_type == .Rook || p.piece_type == .Queen {
					dirs[count] = {1, 0}; count += 1
					dirs[count] = {-1, 0}; count += 1
					dirs[count] = {0, 1}; count += 1
					dirs[count] = {0, -1}; count += 1
				}

				for i in 0 ..< count {
					dx := dirs[i][0]
					dy := dirs[i][1]
					nx := ix + dx
					ny := iy + dy
					for in_bounds(nx, ny) {
						t := board[nx][ny]
						if t.active {
							if t.color != active_color {
								add_move_if_legal(game, ix, iy, nx, ny)
							}
							break
						}
						add_move_if_legal(game, ix, iy, nx, ny)
						nx += dx
						ny += dy
					}
				}

			case .King:
				for dx in -1 ..= 1 {
					for dy in -1 ..= 1 {
						if dx == 0 && dy == 0 {continue}
						nx := ix + i32(dx)
						ny := iy + i32(dy)
						if in_bounds(nx, ny) {
							t := board[nx][ny]
							if !t.active || t.color != active_color {
								add_move_if_legal(game, ix, iy, nx, ny)
							}
						}
					}
				}
				king_row := i32(0 if active_color == .Black else 7)
				if can_castle_kingside[active_color] &&
				   !in_check &&
				   !board[5][king_row].active &&
				   !board[6][king_row].active &&
				   !is_square_attacked(game^, 5, king_row) &&
				   !is_square_attacked(game^, 6, king_row) {
					add_move_if_legal(game, ix, iy, 6, king_row)
				}
				if can_castle_queenside[active_color] &&
				   !in_check &&
				   !board[1][king_row].active &&
				   !board[2][king_row].active &&
				   !board[3][king_row].active &&
				   !is_square_attacked(game^, 2, king_row) &&
				   !is_square_attacked(game^, 3, king_row) {
					add_move_if_legal(game, ix, iy, 2, king_row)
				}
			}
		}
	}

	// Check for completion (mate or stalemate)
	has_move := false
	for x in 0 ..< 8 {
		for y in 0 ..< 8 {
			if moves[x][y] != {} {
				has_move = true
				break
			}
		}
		if has_move {break}
	}

	if !has_move {
		// find king
		for x in 0 ..< 8 {
			for y in 0 ..< 8 {
				p := board[x][y]
				if p.active && p.color == active_color && p.piece_type == .King {
					if is_square_attacked(game^, i32(x), i32(y)) {
						is_completed = true
						completed_reason = .Checkmate
						completed_outcome = .Black_Win if active_color == .White else .White_Win
					} else {
						is_completed = true
						completed_reason = .Stalemate
						completed_outcome = .Draw
					}
					return
				}
			}
		}
	}
}

make_move :: proc(using game: ^Game, from_x: i32, from_y: i32, to_x: i32, to_y: i32) {
	// Assumes move is valid
	in_check = false
	last_move_was_capture = false
	last_move_was_castle = false

	if board[to_x][to_y].active {
		last_move_was_capture = true
	}

	// Castling
	// TODO: Move rook on castling
	if can_castle_kingside[active_color] &&
	   board[from_x][from_y].piece_type == .King &&
	   to_x == 2 {
		board[0][from_y].active = false
		board[3][from_y] = {true, .Rook, active_color}
		last_move_was_castle = true
	}
	if can_castle_queenside[active_color] &&
	   board[from_x][from_y].piece_type == .King &&
	   to_x == 6 {
		board[7][from_y].active = false
		board[5][from_y] = {true, .Rook, active_color}
		last_move_was_castle = true
	}
	if board[from_x][from_y].piece_type == .King {
		can_castle_kingside[active_color] = false
		can_castle_queenside[active_color] = false
	}
	if from_x == 0 && from_y == (0 if active_color == .Black else 7) {
		can_castle_queenside[active_color] = false
	}
	if from_x == 7 && from_y == (0 if active_color == .Black else 7) {
		can_castle_kingside[active_color] = false
	}

	// En Passant
	if board[from_x][from_y].piece_type == .Pawn && en_passant_target_square == {to_x, to_y} {
		board[to_x][from_y].active = false
		last_move_was_capture = true
	}
	en_passant_target_square = {-1, -1}
	if board[from_x][from_y].piece_type == .Pawn && abs(from_y - to_y) > 1 {
		en_passant_target_square = {from_x, (from_y + to_y) / 2}
	}

	board[to_x][to_y] = board[from_x][from_y]
	board[from_x][from_y].active = false
	active_color = .White if active_color == .Black else .Black

	outer: for x in 0 ..< 8 {
		for y in 0 ..< 8 {
			p := board[x][y]
			if p.active && p.color == active_color && p.piece_type == .King {
				if is_square_attacked(game^, i32(x), i32(y)) {
					in_check = true
				}
				break outer
			}
		}
	}

	update_moves(game)
}

reset_game :: proc(game: ^Game) {
	load_fen(game, "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
}

load_fen :: proc(game: ^Game, fen: string) -> bool {
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
	tmp_can_castle_k: [Color]bool
	tmp_can_castle_q: [Color]bool
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
	game.board = tmp_board
	game.can_castle_kingside = tmp_can_castle_k
	game.can_castle_queenside = tmp_can_castle_q
	game.en_passant_target_square = tmp_ep
	game.active_color = tmp_active_color

	game.is_completed = false

	update_moves(game)

	return true
}
