
package main

import "core:fmt"
import "core:strings"
import "core:unicode"

in_bounds :: #force_inline proc(x: i32, y: i32) -> bool {
	return x >= 0 && x < 8 && y >= 0 && y < 8
}

is_square_attacked :: proc(g: Game, tx: i32, ty: i32, by: Color) -> bool {
	using g
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


update_moves :: proc(g: ^Game) {
	// state:                    State,
	// board:                    [8][8]Piece,
	// active_color:             Color,
	// can_castle_kingside:      [2]bool,
	// can_castle_queenside:     [2]bool,
	// en_passant_target_square: [2]i32,
	// moves:                    [8][8]Bitboard,
	// dragging_piece_x:         i32,
	// dragging_piece_y:         i32,
	using g

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

load_fen :: proc(g: ^Game, fen: string) -> bool {
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
	g.board = tmp_board
	g.can_castle_kingside = tmp_can_castle_k
	g.can_castle_queenside = tmp_can_castle_q
	g.en_passant_target_square = tmp_ep
	g.active_color = tmp_active_color
	// gs.ui_state = .Default

	update_moves(g)

	return true
}
