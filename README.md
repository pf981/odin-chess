# Odin Chess

A **chess game implemented in [Odin](https://odin-lang.org)** with a graphical interface using **raylib**.

## 🧩 Requirements

This project requires [Odin](https://odin-lang.org/).

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
<img width="834" height="861" alt="Screenshot 2026-02-17 at 10 59 53 pm" src="https://github.com/user-attachments/assets/b525ab1e-a9e8-419b-9fbd-fd57d2ba76c6" />

