# Odin Chess

A **chess game implemented in [Odin](https://odin-lang.org)** with a graphical interface using **raylib**.

*Play chess from your terminal — or drag pieces with the mouse in a GUI window.*

---

## 💡 Features

✔ Full playable chess game with all standard rules
✔ Drag-and-drop piece movement and visual move highlights
✔ Move legality checks (including castling, en-passant)
✔ FEN loading via console command (`loadfen …`)
✔ On-screen console for commands during play
✔ Debug view showing attacked squares and internal state
✔ Sound effects for moves, captures, check, castle, etc.
✔ Detects game over conditions (checkmate, stalemate, etc.)

---

## 🧩 Requirements

This project requires [Odin](https://odin-lang.org/).

---

## ▶️ Build & Run

Clone the repo:

```bash
git clone https://github.com/pf981/odin-chess.git
cd odin-chess
```

Run with Odin:

```bash
odin run . --debug
```

---

## 🎮 Controls

| Action                | Input                       |
| --------------------- | --------------------------- |
| Drag piece            | Mouse click + drag          |
| Show attacked squares | `F1`                        |
| Toggle debug info     | `F2`                        |
| Open console          | `` ` `` (backtick)          |
| Load FEN              | In console: `loadfen <FEN>` |
| Reset game            | In console: `new`           |
| Change FPS            | In console: `fps <number>`  |

---

## 📦 Project Structure

```
odin-chess/
├── assets/              # Textures & sound effects
├── main.odin            # Game + UI loop
├── game.odin            # Chess logic (moves, rules, FEN, history)
├── todo.md              # Development notes
└── .gitignore
```

---

## 📸 Screenshots

