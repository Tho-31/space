"""Space Invaders amélioré avec un meilleur design et un contraste fort."""

from __future__ import annotations

import math
import random
import time
import turtle

# ---------------------- Configuration ----------------------
WINDOW_TITLE = "Space Invador+"
WIDTH_RATIO = 0.7
HEIGHT_RATIO = 0.8

PLAYER_SPEED = 28
LASER_SPEED = 18
LASER_LENGTH = 18
ALIEN_DROP = 20
ALIEN_STEP = 18
ALIEN_SPAWN_INTERVAL = 1.2

MAX_LIVES = 3
STAR_COUNT = 60

# Couleurs à fort contraste
COLOR_BG = "#0A0E2A"  # bleu très foncé
COLOR_GRID = "#15204B"
COLOR_TEXT = "#F8F8F2"  # blanc cassé
COLOR_ACCENT = "#FFB703"  # orange lumineux
COLOR_PLAYER = "#00E5FF"  # cyan
COLOR_LASER = "#F72585"  # magenta
COLOR_ALIEN = "#9BFF56"  # vert néon

# ---------------------- Fenêtre ----------------------
window = turtle.Screen()
window.tracer(0)
window.setup(WIDTH_RATIO, HEIGHT_RATIO)
window.bgcolor(COLOR_BG)
window.title(WINDOW_TITLE)

LEFT = -window.window_width() / 2
RIGHT = window.window_width() / 2
TOP = window.window_height() / 2
BOTTOM = -window.window_height() / 2
FLOOR_LEVEL = BOTTOM + 60
GUTTER = 30

# ---------------------- Dessins de décor ----------------------
background = turtle.Turtle()
background.hideturtle()
background.speed(0)
background.penup()
background.color(COLOR_GRID)


def draw_grid():
    background.clear()
    background.pensize(1)
    background.setposition(LEFT + 10, TOP - 30)
    for _ in range(6):
        background.pendown()
        background.forward(RIGHT - LEFT - 20)
        background.penup()
        background.sety(background.ycor() - 70)
        background.setx(LEFT + 10)


stars = []


def create_stars():
    for _ in range(STAR_COUNT):
        star = turtle.Turtle()
        star.hideturtle()
        star.penup()
        star.color(COLOR_TEXT)
        star.setposition(
            random.randint(int(LEFT) + 10, int(RIGHT) - 10),
            random.randint(int(FLOOR_LEVEL) + 20, int(TOP) - 20),
        )
        star.dot(random.randint(2, 4))
        stars.append(star)


# ---------------------- HUD ----------------------
score = 0
lives = MAX_LIVES
level = 1

hud = turtle.Turtle()
hud.hideturtle()
hud.penup()
hud.color(COLOR_TEXT)


def update_hud():
    hud.clear()
    hud.setposition(LEFT + 20, TOP - 40)
    hud.write(
        f"Score: {score}    Vies: {lives}    Niveau: {level}",
        font=("Courier", 18, "bold"),
    )


message = turtle.Turtle()
message.hideturtle()
message.penup()
message.color(COLOR_ACCENT)


def show_message(text: str, size: int = 32):
    message.clear()
    message.setposition(0, 0)
    message.write(text, align="center", font=("Courier", size, "bold"))


# ---------------------- Joueur ----------------------
player = turtle.Turtle()
player.penup()
player.color(COLOR_PLAYER)
player.shape("triangle")
player.shapesize(1.4, 1.4)
player.setheading(90)
player.setposition(0, FLOOR_LEVEL)


# ---------------------- Aliens & Lasers ----------------------
lasers: list[turtle.Turtle] = []
aliens: list[turtle.Turtle] = []


class AlienFormation:
    def __init__(self) -> None:
        self.direction = 1
        self.speed = 1.0

    def update(self) -> None:
        shift = ALIEN_STEP * self.direction
        edge_hit = False
        for alien in aliens:
            alien.setx(alien.xcor() + shift)
            if alien.xcor() > RIGHT - GUTTER or alien.xcor() < LEFT + GUTTER:
                edge_hit = True
        if edge_hit:
            self.direction *= -1
            for alien in aliens:
                alien.sety(alien.ycor() - ALIEN_DROP)


formation = AlienFormation()


def spawn_wave() -> None:
    rows = 3 + level
    cols = 7
    start_x = LEFT + 80
    start_y = TOP - 120
    spacing_x = 70
    spacing_y = 50
    for row in range(rows):
        for col in range(cols):
            alien = turtle.Turtle()
            alien.penup()
            alien.shape("circle")
            alien.color(COLOR_ALIEN)
            alien.shapesize(1.2, 1.2)
            alien.setposition(start_x + col * spacing_x, start_y - row * spacing_y)
            aliens.append(alien)


def shoot_laser() -> None:
    laser = turtle.Turtle()
    laser.hideturtle()
    laser.penup()
    laser.color(COLOR_LASER)
    laser.setposition(player.xcor(), player.ycor() + 10)
    laser.setheading(90)
    laser.pendown()
    laser.pensize(4)
    lasers.append(laser)


def move_lasers() -> None:
    for laser in lasers[:]:
        laser.clear()
        laser.forward(LASER_SPEED)
        laser.forward(LASER_LENGTH)
        laser.forward(-LASER_LENGTH)
        if laser.ycor() > TOP:
            laser.clear()
            laser.hideturtle()
            lasers.remove(laser)


def remove_alien(alien: turtle.Turtle) -> None:
    alien.hideturtle()
    aliens.remove(alien)


# ---------------------- Contrôles ----------------------

def move_left():
    new_x = player.xcor() - PLAYER_SPEED
    if new_x > LEFT + GUTTER:
        player.setx(new_x)


def move_right():
    new_x = player.xcor() + PLAYER_SPEED
    if new_x < RIGHT - GUTTER:
        player.setx(new_x)


def quit_game():
    global running
    running = False


window.listen()
window.onkeypress(move_left, "Left")
window.onkeypress(move_right, "Right")
window.onkeypress(shoot_laser, "space")
window.onkeypress(quit_game, "q")

# ---------------------- Boucle de jeu ----------------------
create_stars()
draw_grid()
update_hud()
spawn_wave()

last_spawn = time.time()
clock = time.time()

running = True
show_message("Prêt ?", size=28)

while running:
    window.update()
    if time.time() - clock > 0.6:
        message.clear()

    move_lasers()

    # Déplacement des aliens
    formation.update()

    # Collision lasers/aliens
    for laser in lasers[:]:
        for alien in aliens[:]:
            if laser.distance(alien) < 20:
                laser.clear()
                laser.hideturtle()
                if laser in lasers:
                    lasers.remove(laser)
                remove_alien(alien)
                score += 10
                update_hud()
                break

    # Nouvel étage si aliens finis
    if not aliens:
        level += 1
        update_hud()
        spawn_wave()

    # Vérifie si les aliens touchent le sol
    for alien in aliens:
        if alien.ycor() < FLOOR_LEVEL + 10:
            lives -= 1
            update_hud()
            for a in aliens:
                a.hideturtle()
            aliens.clear()
            if lives <= 0:
                running = False
                break
            spawn_wave()
            break

    # Spawn optionnel d'une étoile scintillante
    if time.time() - last_spawn > ALIEN_SPAWN_INTERVAL:
        last_spawn = time.time()
        for star in stars:
            star.clear()
        for star in stars:
            size = random.randint(2, 4)
            star.dot(size)

    time.sleep(0.01)

show_message("GAME OVER", size=40)
window.update()
time.sleep(2)
window.bye()
