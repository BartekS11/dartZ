# DartZ - Darts Scoring Web App

A modern darts scoring web application built with **Ruby on Rails 8**, **Turbo**, and **Stimulus**.

DartZ allows users to create matches, track turns, enter throws (via UI or keyboard), and automatically calculate scores following real darts rules (including busts and double-out finishes).

---

## Features

- Create 1v1 matches
- Support for registered users and guests
- Enter throws via:
  - Button grid (S/D/T 1–20)
  - Keyboard input (e.g. `20`, `d20`, `t19`, `b`, `db`)
- Automatic turn handling (3 darts per turn)
- Bust logic
- Double-out finishing
- Live score updates using Turbo Streams
- Stimulus-powered keyboard controller
- Importmap (no Node.js required)

---

## Tech Stack

- Ruby on Rails 8  
- Hotwire (Turbo + Stimulus)
- Importmap (no bundler required)
- TailwindCSS
- PostreSQL 

---

## Architecture Overview

The scoring system is structured around:

- `Match`
  - has many `Players`
  - has many `Legs`
- `Leg`
  - manages score state
- `Turn`
  - holds up to 3 throws
- `Throw`
  - segment + multiplier
  - applied through game logic

Score updates are processed server-side and returned via **Turbo Streams** to update the UI without a full page reload.

---

## Keyboard Input Format

You can enter throws using:

| Input | Meaning |
|--------|----------|
| `20`   | Single 20 |
| `d20`  | Double 20 |
| `t20`  | Triple 20 |
| `b`    | Bull (25) |
| `db`   | Double Bull (50) |

Press **Enter** to submit each throw.

Each turn allows **3 darts**.

---

## Setup

### Clone the repository:

```bash
git clone https://github.com/BartekS11/dartZ
cd dartZ 
```
### Install dependencies

```bash 
bundle install
```

### Migrate db 

``` bash
bin/rails db:create db:migrate
```

### Start development server

``` bash
bin/dev
```


