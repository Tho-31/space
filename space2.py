"""Space Invaders 2.0 - Version améliorée avec power-ups, boss, sons et effets visuels."""

from __future__ import annotations

import math
import os
import random
import struct
import subprocess
import tempfile
import time
import turtle
import wave

# ---------------------- Configuration ----------------------
WINDOW_TITLE = "Space Invaders 2.0"
WIDTH_RATIO = 0.8
HEIGHT_RATIO = 0.9

PLAYER_SPEED = 28
LASER_SPEED = 20
LASER_LENGTH = 20
ALIEN_DROP = 22
ALIEN_STEP = 1.5
ALIEN_SHOOT_CHANCE = 0.006

MAX_LIVES = 5
STAR_COUNT = 80

# Couleurs
COLOR_BG = "#0A0E2A"
COLOR_GRID = "#15204B"
COLOR_TEXT = "#F8F8F2"
COLOR_ACCENT = "#FFB703"
COLOR_PLAYER = "#00E5FF"
COLOR_PLAYER_SHIELD = "#00FF88"
COLOR_LASER = "#F72585"
COLOR_LASER_POWERED = "#FFD700"
COLOR_ENEMY_LASER = "#FF4444"
COLOR_BOSS = "#FF00FF"

# Couleurs aliens
ALIEN_COLORS = ["#9BFF56", "#FF6B35", "#F7B32B", "#4ECDC4", "#FF3366"]

# ---------------------- Sons ----------------------
SOUND_ENABLED = True
TEMP_DIR = tempfile.gettempdir()


def create_wav_file(filename: str, frequency: float, duration: float, envelope: str = "none"):
    """Crée un fichier WAV avec une fréquence et durée données."""
    sample_rate = 22050
    num_samples = int(sample_rate * duration)

    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)

        for i in range(num_samples):
            t = i / sample_rate

            if envelope == "sweep_down":
                freq = frequency - (frequency * 0.7 * t / duration)
                value = math.sin(2 * math.pi * freq * t)
                value *= math.exp(-t * 10)
            elif envelope == "sweep_up":
                freq = frequency + (frequency * 0.5 * t / duration)
                value = math.sin(2 * math.pi * freq * t)
                value *= math.exp(-t * 8)
            elif envelope == "noise":
                value = random.uniform(-1, 1)
                value *= math.exp(-t * 8)
            elif envelope == "game_over":
                freq = frequency - (frequency * 0.5 * t / duration)
                value = math.sin(2 * math.pi * freq * t)
                value *= math.exp(-t * 3)
            elif envelope == "powerup":
                freq = frequency + (frequency * t / duration)
                value = math.sin(2 * math.pi * freq * t)
                value *= 1 - (t / duration)
            elif envelope == "boss":
                value = math.sin(2 * math.pi * frequency * t)
                value += 0.5 * math.sin(2 * math.pi * frequency * 1.5 * t)
                value *= math.exp(-t * 5)
            elif envelope == "level_up":
                freq = frequency * (1 + t / duration)
                value = math.sin(2 * math.pi * freq * t)
                value *= 1 - (t / duration) * 0.5
            else:
                value = math.sin(2 * math.pi * frequency * t)

            data = int(value * 32767 * 0.5)
            data = max(-32767, min(32767, data))
            wav_file.writeframes(struct.pack('<h', data))


# Créer les fichiers sons
sound_files = {}
try:
    sound_files['laser'] = os.path.join(TEMP_DIR, "laser.wav")
    sound_files['explosion'] = os.path.join(TEMP_DIR, "explosion.wav")
    sound_files['game_over'] = os.path.join(TEMP_DIR, "game_over.wav")
    sound_files['powerup'] = os.path.join(TEMP_DIR, "powerup.wav")
    sound_files['boss_hit'] = os.path.join(TEMP_DIR, "boss_hit.wav")
    sound_files['level_up'] = os.path.join(TEMP_DIR, "level_up.wav")
    sound_files['shield'] = os.path.join(TEMP_DIR, "shield.wav")

    create_wav_file(sound_files['laser'], 800, 0.1, "sweep_down")
    create_wav_file(sound_files['explosion'], 200, 0.25, "noise")
    create_wav_file(sound_files['game_over'], 300, 0.8, "game_over")
    create_wav_file(sound_files['powerup'], 600, 0.3, "powerup")
    create_wav_file(sound_files['boss_hit'], 150, 0.2, "boss")
    create_wav_file(sound_files['level_up'], 500, 0.5, "level_up")
    create_wav_file(sound_files['shield'], 400, 0.15, "sweep_up")
except Exception as e:
    print(f"Erreur lors de la création des sons: {e}")
    SOUND_ENABLED = False


def play_sound(sound_type: str):
    """Joue un son selon le type."""
    if not SOUND_ENABLED or sound_type not in sound_files:
        return
    try:
        subprocess.Popen(["afplay", sound_files[sound_type]],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


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
FLOOR_LEVEL = BOTTOM + 80
GUTTER = 40

# ---------------------- État du jeu ----------------------
score = 0
high_score = 0
lives = MAX_LIVES
level = 1
combo = 0
combo_timer = 0
game_state = "menu"

# Power-ups actifs
shield_active = False
shield_timer = 0
rapid_fire = False
rapid_timer = 0
triple_shot = False
triple_timer = 0

# Listes d'objets
lasers = []
enemy_lasers = []
aliens = []
explosions = []
powerups = []
stars = []

boss = None
alien_direction = 1
last_shot_time = 0

# ---------------------- Formes personnalisées ----------------------

def create_alien_shapes():
    """Crée des formes personnalisées pour les aliens."""
    alien1 = (
        (-10, 8), (-8, 12), (-6, 12), (-4, 8), (-2, 12), (2, 12), (4, 8),
        (6, 12), (8, 12), (10, 8), (12, 4), (10, 0), (12, -4), (8, -8),
        (4, -4), (2, -8), (-2, -8), (-4, -4), (-8, -8), (-12, -4),
        (-10, 0), (-12, 4)
    )
    window.register_shape("alien1", alien1)

    alien2 = (
        (-8, 10), (-4, 12), (0, 12), (4, 12), (8, 10), (10, 6), (10, 2),
        (8, -2), (10, -6), (8, -10), (6, -8), (4, -12), (2, -8), (0, -6),
        (-2, -8), (-4, -12), (-6, -8), (-8, -10), (-10, -6), (-8, -2),
        (-10, 2), (-10, 6)
    )
    window.register_shape("alien2", alien2)

    alien3 = (
        (0, 12), (4, 8), (8, 8), (10, 4), (12, 0), (10, -4), (6, -8),
        (2, -8), (0, -12), (-2, -8), (-6, -8), (-10, -4), (-12, 0),
        (-10, 4), (-8, 8), (-4, 8)
    )
    window.register_shape("alien3", alien3)

    # Forme du boss
    boss_shape = (
        (0, 25), (15, 20), (25, 10), (30, 0), (25, -10), (20, -20),
        (10, -25), (5, -20), (0, -25), (-5, -20), (-10, -25), (-20, -20),
        (-25, -10), (-30, 0), (-25, 10), (-15, 20)
    )
    window.register_shape("boss_shape", boss_shape)

    # Forme power-up
    powerup_shape = (
        (0, 10), (3, 3), (10, 0), (3, -3), (0, -10), (-3, -3), (-10, 0), (-3, 3)
    )
    window.register_shape("powerup_shape", powerup_shape)


# ---------------------- Étoiles ----------------------

def create_stars():
    global stars
    stars = []
    for _ in range(STAR_COUNT):
        star = turtle.Turtle()
        star.hideturtle()
        star.penup()
        star.color(COLOR_TEXT)
        x = random.randint(int(LEFT) + 10, int(RIGHT) - 10)
        y = random.randint(int(FLOOR_LEVEL) + 20, int(TOP) - 20)
        star.setposition(x, y)
        star.size = random.randint(1, 3)
        star.brightness = random.random()
        star.speed_mult = random.uniform(0.5, 2)
        stars.append(star)


def update_stars():
    for star in stars:
        star.clear()
        star.brightness += math.sin(time.time() * star.speed_mult * 3) * 0.03
        star.brightness = max(0.2, min(1.0, star.brightness))
        brightness = int(star.brightness * 255)
        color = f"#{brightness:02x}{brightness:02x}{brightness:02x}"
        star.dot(star.size, color)


# ---------------------- Grille ----------------------
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


# ---------------------- HUD ----------------------
hud = turtle.Turtle()
hud.hideturtle()
hud.penup()
hud.color(COLOR_TEXT)

message = turtle.Turtle()
message.hideturtle()
message.penup()
message.color(COLOR_ACCENT)


def update_hud():
    hud.clear()

    # Score
    hud.setposition(LEFT + 20, TOP - 40)
    hud.color(COLOR_TEXT)
    hud.write(f"Score: {score}", font=("Courier", 16, "bold"))

    # High Score
    hud.setposition(LEFT + 20, TOP - 62)
    hud.color(COLOR_ACCENT)
    hud.write(f"High: {high_score}", font=("Courier", 12, "normal"))

    # Niveau
    hud.setposition(0, TOP - 40)
    hud.color(COLOR_TEXT)
    hud.write(f"Niveau {level}", align="center", font=("Courier", 16, "bold"))

    # Combo
    if combo > 1:
        hud.setposition(0, TOP - 62)
        hud.color("#FFD700")
        hud.write(f"x{combo} COMBO!", align="center", font=("Courier", 14, "bold"))

    # Vies
    hud.setposition(RIGHT - 180, TOP - 40)
    hud.color("#FF6B6B")
    hearts = "❤ " * lives + "♡ " * (MAX_LIVES - lives)
    hud.write(hearts, font=("Courier", 14, "normal"))

    # Power-ups actifs
    y_offset = TOP - 65
    if shield_active:
        hud.setposition(RIGHT - 180, y_offset)
        hud.color(COLOR_PLAYER_SHIELD)
        hud.write(f"🛡 {shield_timer // 60}s", font=("Courier", 11, "normal"))
        y_offset -= 18
    if rapid_fire:
        hud.setposition(RIGHT - 180, y_offset)
        hud.color("#FF00FF")
        hud.write(f"⚡ {rapid_timer // 60}s", font=("Courier", 11, "normal"))
        y_offset -= 18
    if triple_shot:
        hud.setposition(RIGHT - 180, y_offset)
        hud.color("#FFD700")
        hud.write(f"🔱 {triple_timer // 60}s", font=("Courier", 11, "normal"))


def show_message(text: str, size: int = 32, color: str = COLOR_ACCENT):
    message.clear()
    message.setposition(0, 0)
    message.color(color)
    message.write(text, align="center", font=("Courier", size, "bold"))


def show_menu():
    message.clear()
    message.color(COLOR_ACCENT)
    message.setposition(0, 120)
    message.write("SPACE INVADERS 2.0", align="center", font=("Courier", 42, "bold"))

    message.color(COLOR_TEXT)
    message.setposition(0, 50)
    message.write("Appuie sur ESPACE pour jouer", align="center", font=("Courier", 18, "normal"))

    message.setposition(0, 10)
    message.write("← → : Déplacer  |  ESPACE : Tirer  |  A : Atomic", align="center", font=("Courier", 12, "normal"))

    message.setposition(0, -20)
    message.write("P : Pause  |  Q : Quitter", align="center", font=("Courier", 12, "normal"))

    message.color("#9BFF56")
    message.setposition(0, -70)
    message.write("Power-ups:", align="center", font=("Courier", 14, "bold"))

    message.color(COLOR_TEXT)
    message.setposition(0, -100)
    message.write("🛡 Bouclier   ⚡ Tir rapide   🔱 Triple tir", align="center", font=("Courier", 11, "normal"))

    message.setposition(0, -125)
    message.write("❤ Vie extra   💣 Bombe atomique", align="center", font=("Courier", 11, "normal"))


# ---------------------- Joueur ----------------------
player = turtle.Turtle()
player.penup()
player.color(COLOR_PLAYER)
player.shape("triangle")
player.shapesize(1.6, 1.6)
player.setheading(90)
player.setposition(0, FLOOR_LEVEL)

shield_visual = turtle.Turtle()
shield_visual.hideturtle()
shield_visual.penup()
shield_visual.pensize(2)


def draw_player_effects():
    shield_visual.clear()
    if shield_active:
        shield_visual.setposition(player.xcor(), player.ycor() - 25)
        shield_visual.color(COLOR_PLAYER_SHIELD)
        shield_visual.pendown()
        shield_visual.circle(25 + 3 * math.sin(time.time() * 8))
        shield_visual.penup()


# ---------------------- Explosions ----------------------

def create_explosion(x: float, y: float, color: str, count: int = 12):
    """Crée une explosion avec des particules."""
    particles = []
    for i in range(count):
        particle = turtle.Turtle()
        particle.hideturtle()
        particle.penup()
        particle.color(color)
        particle.setposition(x, y)
        particle.pensize(random.randint(2, 4))
        angle = (360 / count) * i + random.uniform(-15, 15)
        particle.setheading(angle)
        particle.speed_val = random.uniform(3, 6)
        particles.append(particle)

    flash = turtle.Turtle()
    flash.hideturtle()
    flash.penup()
    flash.setposition(x, y)
    flash.color("#FFFFFF")

    explosion = {
        "particles": particles,
        "flash": flash,
        "life": 18,
        "color": color
    }
    explosions.append(explosion)


def animate_explosions():
    for explosion in explosions[:]:
        explosion["life"] -= 1
        if explosion["life"] <= 0:
            for particle in explosion["particles"]:
                particle.clear()
            explosion["flash"].clear()
            explosions.remove(explosion)
        else:
            if explosion["life"] > 12:
                flash_size = (explosion["life"] - 12) * 5
                explosion["flash"].clear()
                explosion["flash"].dot(flash_size)

            for particle in explosion["particles"]:
                particle.clear()
                particle.pendown()
                particle.forward(particle.speed_val)
                particle.dot(max(1, explosion["life"] // 3))
                particle.penup()
                particle.speed_val *= 0.92


# ---------------------- Power-ups ----------------------

class PowerUp:
    TYPES = ['shield', 'rapid', 'triple', 'life', 'bomb']
    COLORS = {
        'shield': '#00FF88',
        'rapid': '#FF00FF',
        'triple': '#FFD700',
        'life': '#FF6B6B',
        'bomb': '#FF4500'
    }

    def __init__(self, x: float, y: float):
        self.t = turtle.Turtle()
        self.t.penup()
        self.t.shape("powerup_shape")
        self.type = random.choice(self.TYPES)
        self.t.color(self.COLORS[self.type])
        self.t.shapesize(1.2, 1.2)
        self.t.setposition(x, y)
        self.speed = 2.5
        self.angle = 0

    def update(self) -> bool:
        self.t.sety(self.t.ycor() - self.speed)
        self.angle += 5
        self.t.setheading(self.angle)
        return self.t.ycor() > FLOOR_LEVEL - 30

    def destroy(self):
        self.t.hideturtle()


def apply_powerup(powerup_type: str):
    global shield_active, shield_timer, rapid_fire, rapid_timer
    global triple_shot, triple_timer, lives

    play_sound("powerup")

    if powerup_type == 'shield':
        shield_active = True
        shield_timer = 600
    elif powerup_type == 'rapid':
        rapid_fire = True
        rapid_timer = 480
    elif powerup_type == 'triple':
        triple_shot = True
        triple_timer = 420
    elif powerup_type == 'life':
        lives = min(lives + 1, MAX_LIVES)
    elif powerup_type == 'bomb':
        atomic_explosion()


def update_powerup_timers():
    global shield_active, shield_timer, rapid_fire, rapid_timer
    global triple_shot, triple_timer

    if shield_active:
        shield_timer -= 1
        if shield_timer <= 0:
            shield_active = False

    if rapid_fire:
        rapid_timer -= 1
        if rapid_timer <= 0:
            rapid_fire = False

    if triple_shot:
        triple_timer -= 1
        if triple_timer <= 0:
            triple_shot = False


# ---------------------- Boss ----------------------

class Boss:
    def __init__(self, y: float):
        self.t = turtle.Turtle()
        self.t.penup()
        self.t.shape("boss_shape")
        self.t.color(COLOR_BOSS)
        self.t.shapesize(2, 2)
        self.t.setposition(0, y)
        self.health = 30 + level * 10
        self.max_health = self.health
        self.direction = 1
        self.speed = 3
        self.shoot_timer = 0
        self.active = True

        self.health_bar = turtle.Turtle()
        self.health_bar.hideturtle()
        self.health_bar.penup()
        self.health_bar.pensize(1)

    def update(self):
        if not self.active:
            return

        new_x = self.t.xcor() + self.speed * self.direction
        if new_x > RIGHT - 80 or new_x < LEFT + 80:
            self.direction *= -1
        self.t.setx(new_x)

        scale = 1.8 + 0.3 * math.sin(time.time() * 4)
        self.t.shapesize(scale, scale)
        self.t.color(COLOR_BOSS)

        self.draw_health_bar()

    def draw_health_bar(self):
        self.health_bar.clear()
        bar_width = 150
        bar_height = 12
        x = self.t.xcor() - bar_width / 2
        y = self.t.ycor() + 50

        self.health_bar.setposition(x, y)
        self.health_bar.pendown()
        self.health_bar.color("#333333")
        self.health_bar.begin_fill()
        for _ in range(2):
            self.health_bar.forward(bar_width)
            self.health_bar.left(90)
            self.health_bar.forward(bar_height)
            self.health_bar.left(90)
        self.health_bar.end_fill()
        self.health_bar.penup()

        health_width = max(0, (self.health / self.max_health) * bar_width)
        self.health_bar.setposition(x, y)
        health_color = "#00FF00" if self.health > self.max_health * 0.5 else "#FFFF00" if self.health > self.max_health * 0.25 else "#FF0000"
        self.health_bar.pendown()
        self.health_bar.color(health_color)
        self.health_bar.begin_fill()
        for _ in range(2):
            self.health_bar.forward(health_width)
            self.health_bar.left(90)
            self.health_bar.forward(bar_height)
            self.health_bar.left(90)
        self.health_bar.end_fill()
        self.health_bar.penup()

    def hit(self, damage: int = 1) -> bool:
        self.health -= damage
        self.t.color("white")
        play_sound("boss_hit")
        if self.health <= 0:
            self.active = False
            return True
        return False

    def should_shoot(self) -> bool:
        self.shoot_timer += 1
        if self.shoot_timer > 25:
            self.shoot_timer = 0
            return random.random() < 0.6
        return False

    def destroy(self):
        self.t.hideturtle()
        self.health_bar.clear()


# ---------------------- Aliens ----------------------

class AlienFormation:
    def __init__(self):
        self.direction = 1
        self.speed = 1.0

    def update(self):
        global alien_direction
        if boss and boss.active:
            return

        shift = ALIEN_STEP * self.direction * (1 + level * 0.08)
        edge_hit = False

        for alien in aliens:
            alien['turtle'].setx(alien['turtle'].xcor() + shift)
            if alien['turtle'].xcor() > RIGHT - GUTTER or alien['turtle'].xcor() < LEFT + GUTTER:
                edge_hit = True

        if edge_hit:
            self.direction *= -1
            for alien in aliens:
                alien['turtle'].sety(alien['turtle'].ycor() - ALIEN_DROP)


formation = AlienFormation()


def spawn_wave():
    global aliens, boss

    for alien in aliens:
        alien['turtle'].hideturtle()
    aliens = []
    boss = None

    if level % 5 == 0:
        boss = Boss(TOP - 150)
        return

    rows = min(3 + level // 2, 6)
    cols = min(6 + level // 3, 9)
    start_x = LEFT + 90
    start_y = TOP - 130
    spacing_x = 68
    spacing_y = 52

    shapes = ["alien1", "alien2", "alien3"]

    for row in range(rows):
        for col in range(cols):
            alien_t = turtle.Turtle()
            alien_t.penup()
            alien_t.shape(shapes[row % 3])
            alien_t.color(ALIEN_COLORS[row % len(ALIEN_COLORS)])
            alien_t.shapesize(1.0, 1.0)
            alien_t.setposition(start_x + col * spacing_x, start_y - row * spacing_y)

            alien = {
                'turtle': alien_t,
                'health': 1 + row // 2,
                'points': 10 * (row + 1),
                'color': ALIEN_COLORS[row % len(ALIEN_COLORS)]
            }
            aliens.append(alien)


def remove_alien(alien: dict):
    create_explosion(alien['turtle'].xcor(), alien['turtle'].ycor(), alien['color'])
    play_sound("explosion")
    alien['turtle'].hideturtle()
    aliens.remove(alien)

    if random.random() < 0.12:
        powerups.append(PowerUp(alien['turtle'].xcor(), alien['turtle'].ycor()))


def alien_shoot():
    if not aliens:
        return

    for alien in aliens:
        if random.random() < ALIEN_SHOOT_CHANCE * (1 + level * 0.05):
            laser = turtle.Turtle()
            laser.hideturtle()
            laser.penup()
            laser.color(COLOR_ENEMY_LASER)
            laser.setposition(alien['turtle'].xcor(), alien['turtle'].ycor() - 15)
            laser.setheading(270)
            laser.pendown()
            laser.pensize(3)
            enemy_lasers.append(laser)

    if boss and boss.active and boss.should_shoot():
        for offset in [-25, 0, 25]:
            laser = turtle.Turtle()
            laser.hideturtle()
            laser.penup()
            laser.color(COLOR_ENEMY_LASER)
            laser.setposition(boss.t.xcor() + offset, boss.t.ycor() - 40)
            laser.setheading(270)
            laser.pendown()
            laser.pensize(4)
            enemy_lasers.append(laser)


# ---------------------- Lasers ----------------------

def shoot_laser():
    global last_shot_time, game_state

    if game_state == "menu":
        start_game()
        return

    if game_state != "playing":
        return

    cooldown = 120 if rapid_fire else 250
    current_time = time.time() * 1000
    if current_time - last_shot_time < cooldown:
        return

    last_shot_time = current_time
    play_sound("laser")

    positions = [0]
    if triple_shot:
        positions = [-18, 0, 18]

    for offset in positions:
        laser = turtle.Turtle()
        laser.hideturtle()
        laser.penup()
        laser.color(COLOR_LASER_POWERED if rapid_fire else COLOR_LASER)
        laser.setposition(player.xcor() + offset, player.ycor() + 15)
        laser.setheading(90)
        laser.pendown()
        laser.pensize(5 if rapid_fire else 4)
        laser.damage = 2 if rapid_fire else 1
        lasers.append(laser)


def move_lasers():
    for laser in lasers[:]:
        laser.clear()
        laser.forward(LASER_SPEED)
        laser.forward(LASER_LENGTH)
        laser.forward(-LASER_LENGTH)
        if laser.ycor() > TOP:
            laser.clear()
            laser.hideturtle()
            lasers.remove(laser)

    for laser in enemy_lasers[:]:
        laser.clear()
        laser.forward(12)
        laser.forward(15)
        laser.forward(-15)
        if laser.ycor() < FLOOR_LEVEL - 20:
            laser.clear()
            laser.hideturtle()
            enemy_lasers.remove(laser)


def atomic():
    """Tire des lasers sur toute la largeur."""
    if game_state != "playing":
        return
    atomic_explosion()


def atomic_explosion():
    """Déclenche une explosion atomique."""
    cursor = LEFT + 20
    step = 25
    while cursor < RIGHT - 20:
        laser = turtle.Turtle()
        laser.hideturtle()
        laser.penup()
        laser.color(COLOR_LASER_POWERED)
        laser.setposition(cursor, FLOOR_LEVEL + 15)
        laser.setheading(90)
        laser.pendown()
        laser.pensize(3)
        laser.damage = 1
        lasers.append(laser)
        cursor += step
    play_sound("laser")


# ---------------------- Collisions ----------------------

def check_collisions():
    global score, combo, combo_timer, lives, shield_active, high_score

    # Lasers joueur vs boss
    if boss and boss.active:
        for laser in lasers[:]:
            if laser.distance(boss.t) < 50:
                damage = getattr(laser, 'damage', 1)
                laser.clear()
                laser.hideturtle()
                if laser in lasers:
                    lasers.remove(laser)
                if boss.hit(damage):
                    create_explosion(boss.t.xcor(), boss.t.ycor(), COLOR_BOSS, 25)
                    score += 500 * level
                    boss.destroy()
                else:
                    create_explosion(laser.xcor(), laser.ycor(), COLOR_BOSS, 5)

    # Lasers joueur vs aliens
    for laser in lasers[:]:
        for alien in aliens[:]:
            if laser.distance(alien['turtle']) < 22:
                damage = getattr(laser, 'damage', 1)
                laser.clear()
                laser.hideturtle()
                if laser in lasers:
                    lasers.remove(laser)

                alien['health'] -= damage
                if alien['health'] <= 0:
                    combo += 1
                    combo_timer = 60
                    score += alien['points'] * combo
                    remove_alien(alien)
                else:
                    alien['turtle'].color("white")
                break

    # Restaurer couleurs aliens
    for alien in aliens:
        alien['turtle'].color(alien['color'])

    # Lasers ennemis vs joueur
    for laser in enemy_lasers[:]:
        if laser.distance(player) < 22:
            laser.clear()
            laser.hideturtle()
            enemy_lasers.remove(laser)

            if shield_active:
                play_sound("shield")
                create_explosion(player.xcor(), player.ycor(), COLOR_PLAYER_SHIELD, 8)
            else:
                lives -= 1
                create_explosion(player.xcor(), player.ycor(), COLOR_PLAYER, 15)
                if lives <= 0:
                    return "gameover"

    # Power-ups vs joueur
    for powerup in powerups[:]:
        if powerup.t.distance(player) < 28:
            apply_powerup(powerup.type)
            powerup.destroy()
            powerups.remove(powerup)

    # Aliens touchent le sol
    for alien in aliens:
        if alien['turtle'].ycor() < FLOOR_LEVEL + 25:
            if not shield_active:
                lives -= 1
            for a in aliens:
                a['turtle'].hideturtle()
            aliens.clear()
            if lives <= 0:
                return "gameover"
            spawn_wave()
            break

    if score > high_score:
        high_score = score

    return None


# ---------------------- Contrôles ----------------------

def move_left():
    if game_state != "playing":
        return
    new_x = player.xcor() - PLAYER_SPEED
    if new_x > LEFT + GUTTER:
        player.setx(new_x)


def move_right():
    if game_state != "playing":
        return
    new_x = player.xcor() + PLAYER_SPEED
    if new_x < RIGHT - GUTTER:
        player.setx(new_x)


def toggle_pause():
    global game_state
    if game_state == "playing":
        game_state = "paused"
        show_message("PAUSE\n\nAppuie sur P pour continuer", 24)
    elif game_state == "paused":
        game_state = "playing"
        message.clear()


def quit_game():
    global running
    running = False


def start_game():
    global game_state, score, lives, level, combo
    global shield_active, rapid_fire, triple_shot
    global shield_timer, rapid_timer, triple_timer

    game_state = "playing"
    score = 0
    lives = MAX_LIVES
    level = 1
    combo = 0
    shield_active = False
    rapid_fire = False
    triple_shot = False
    shield_timer = 0
    rapid_timer = 0
    triple_timer = 0

    for laser in lasers:
        laser.clear()
        laser.hideturtle()
    lasers.clear()

    for laser in enemy_lasers:
        laser.clear()
        laser.hideturtle()
    enemy_lasers.clear()

    for alien in aliens:
        alien['turtle'].hideturtle()
    aliens.clear()

    for explosion in explosions:
        for particle in explosion["particles"]:
            particle.clear()
        explosion["flash"].clear()
    explosions.clear()

    for powerup in powerups:
        powerup.destroy()
    powerups.clear()

    player.setposition(0, FLOOR_LEVEL)
    message.clear()
    spawn_wave()


def restart_game():
    global game_state
    if game_state == "gameover":
        start_game()


# ---------------------- Binding ----------------------
window.listen()
window.onkeypress(move_left, "Left")
window.onkeypress(move_right, "Right")
window.onkeypress(move_left, "a")
window.onkeypress(move_right, "d")
window.onkeypress(shoot_laser, "space")
window.onkeypress(toggle_pause, "p")
window.onkeypress(quit_game, "q")
window.onkeypress(restart_game, "r")
window.onkeypress(atomic, "w")
window.onkeypress(atomic, "W")

# ---------------------- Initialisation ----------------------
create_alien_shapes()
create_stars()
draw_grid()
show_menu()

# ---------------------- Boucle principale ----------------------
running = True
combo_timer = 0

while running:
    window.update()

    if game_state == "menu":
        update_stars()
        time.sleep(0.016)
        continue

    if game_state == "paused":
        time.sleep(0.016)
        continue

    if game_state == "gameover":
        update_stars()
        animate_explosions()
        time.sleep(0.016)
        continue

    # Jeu en cours
    update_stars()
    draw_player_effects()

    move_lasers()
    animate_explosions()

    formation.update()
    if boss:
        boss.update()

    alien_shoot()

    for powerup in powerups[:]:
        if not powerup.update():
            powerup.destroy()
            powerups.remove(powerup)

    update_powerup_timers()

    if combo_timer > 0:
        combo_timer -= 1
    else:
        combo = 0

    result = check_collisions()
    if result == "gameover":
        game_state = "gameover"
        play_sound("game_over")
        show_message(f"GAME OVER\n\nScore: {score}\nRecord: {high_score}\n\nR pour rejouer", 24, "#FF4444")

    if not aliens and (not boss or not boss.active) and game_state == "playing":
        level += 1
        play_sound("level_up")
        if boss:
            show_message(f"BOSS VAINCU!\n\nNiveau {level}", 30, "#00FF00")
        else:
            show_message(f"NIVEAU {level}", 36)
        window.update()
        time.sleep(1.5)
        message.clear()
        spawn_wave()

    update_hud()

    time.sleep(0.016)

window.bye()
