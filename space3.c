/*
 * Space Invaders 3.0 - Version C/SDL2 haute performance
 * Compilation: gcc -o space3 space3.c $(sdl2-config --cflags --libs) -lm
 */

#include <SDL2/SDL.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

// ==================== CONFIGURATION ====================
#define WINDOW_WIDTH 900
#define WINDOW_HEIGHT 700
#define FPS 60
#define FRAME_DELAY (1000 / FPS)

#define MAX_LASERS 50
#define MAX_ENEMY_LASERS 100
#define MAX_ALIENS 80
#define MAX_PARTICLES 500
#define MAX_POWERUPS 10
#define MAX_STARS 150

#define PLAYER_SPEED 8
#define LASER_SPEED 12
#define ENEMY_LASER_SPEED 6
#define ALIEN_SPEED_BASE 1.0f
#define ALIEN_DROP 25

#define MAX_LIVES 5

// ==================== COULEURS ====================
#define COLOR_BG_R 10
#define COLOR_BG_G 14
#define COLOR_BG_B 42

#define COLOR_PLAYER_R 0
#define COLOR_PLAYER_G 229
#define COLOR_PLAYER_B 255

#define COLOR_LASER_R 247
#define COLOR_LASER_G 37
#define COLOR_LASER_B 133

#define COLOR_ENEMY_LASER_R 255
#define COLOR_ENEMY_LASER_G 68
#define COLOR_ENEMY_LASER_B 68

// ==================== STRUCTURES ====================

typedef struct {
    float x, y;
    float vx, vy;
    int life;
    Uint8 r, g, b;
} Particle;

typedef struct {
    float x, y;
    bool active;
    int damage;
    bool powered;
} Laser;

typedef struct {
    float x, y;
    bool active;
} EnemyLaser;

typedef struct {
    float x, y;
    int health;
    int max_health;
    int points;
    int type;
    Uint8 r, g, b;
    bool active;
} Alien;

typedef struct {
    float x, y;
    int type; // 0=shield, 1=rapid, 2=triple, 3=life, 4=bomb
    float angle;
    bool active;
} PowerUp;

typedef struct {
    float x, y;
    float brightness;
    float speed;
    int size;
} Star;

typedef struct {
    float x, y;
    int health;
    int max_health;
    int direction;
    float shoot_timer;
    bool active;
} Boss;

typedef struct {
    float x, y;
    int width, height;
} Player;

// ==================== VARIABLES GLOBALES ====================

SDL_Window *window = NULL;
SDL_Renderer *renderer = NULL;
bool running = true;

Player player;
Laser lasers[MAX_LASERS];
EnemyLaser enemy_lasers[MAX_ENEMY_LASERS];
Alien aliens[MAX_ALIENS];
Particle particles[MAX_PARTICLES];
PowerUp powerups[MAX_POWERUPS];
Star stars[MAX_STARS];
Boss boss;

int score = 0;
int high_score = 0;
int lives = MAX_LIVES;
int level = 1;
int combo = 0;
int combo_timer = 0;

bool shield_active = false;
int shield_timer = 0;
bool rapid_fire = false;
int rapid_timer = 0;
bool triple_shot = false;
int triple_timer = 0;

int alien_direction = 1;
float alien_speed_mult = 1.0f;
Uint32 last_shot_time = 0;

typedef enum {
    STATE_MENU,
    STATE_PLAYING,
    STATE_PAUSED,
    STATE_GAMEOVER
} GameState;

GameState game_state = STATE_MENU;

// Couleurs des aliens
Uint8 alien_colors[][3] = {
    {155, 255, 86},   // Vert
    {255, 107, 53},   // Orange
    {247, 179, 43},   // Jaune
    {78, 205, 196},   // Cyan
    {255, 51, 102}    // Rose
};

// ==================== FONCTIONS UTILITAIRES ====================

float randf() {
    return (float)rand() / RAND_MAX;
}

int randi(int min, int max) {
    return min + rand() % (max - min + 1);
}

void set_color(Uint8 r, Uint8 g, Uint8 b, Uint8 a) {
    SDL_SetRenderDrawColor(renderer, r, g, b, a);
}

// ==================== PARTICULES ====================

void spawn_particle(float x, float y, Uint8 r, Uint8 g, Uint8 b) {
    for (int i = 0; i < MAX_PARTICLES; i++) {
        if (particles[i].life <= 0) {
            particles[i].x = x;
            particles[i].y = y;
            particles[i].vx = (randf() - 0.5f) * 10.0f;
            particles[i].vy = (randf() - 0.5f) * 10.0f;
            particles[i].life = randi(20, 40);
            particles[i].r = r;
            particles[i].g = g;
            particles[i].b = b;
            return;
        }
    }
}

void spawn_explosion(float x, float y, Uint8 r, Uint8 g, Uint8 b, int count) {
    for (int i = 0; i < count; i++) {
        spawn_particle(x, y, r, g, b);
    }
}

void update_particles() {
    for (int i = 0; i < MAX_PARTICLES; i++) {
        if (particles[i].life > 0) {
            particles[i].x += particles[i].vx;
            particles[i].y += particles[i].vy;
            particles[i].vy += 0.2f; // Gravité
            particles[i].life--;
        }
    }
}

void draw_particles() {
    for (int i = 0; i < MAX_PARTICLES; i++) {
        if (particles[i].life > 0) {
            int alpha = (particles[i].life * 255) / 40;
            int size = 2 + particles[i].life / 10;
            set_color(particles[i].r, particles[i].g, particles[i].b, alpha);
            SDL_Rect rect = {(int)particles[i].x - size/2, (int)particles[i].y - size/2, size, size};
            SDL_RenderFillRect(renderer, &rect);
        }
    }
}

// ==================== ÉTOILES ====================

void init_stars() {
    for (int i = 0; i < MAX_STARS; i++) {
        stars[i].x = randf() * WINDOW_WIDTH;
        stars[i].y = randf() * WINDOW_HEIGHT;
        stars[i].brightness = randf();
        stars[i].speed = 0.5f + randf() * 2.0f;
        stars[i].size = randi(1, 3);
    }
}

void update_stars() {
    for (int i = 0; i < MAX_STARS; i++) {
        stars[i].brightness += sinf(SDL_GetTicks() * 0.001f * stars[i].speed) * 0.02f;
        if (stars[i].brightness < 0.2f) stars[i].brightness = 0.2f;
        if (stars[i].brightness > 1.0f) stars[i].brightness = 1.0f;
    }
}

void draw_stars() {
    for (int i = 0; i < MAX_STARS; i++) {
        int brightness = (int)(stars[i].brightness * 255);
        set_color(brightness, brightness, brightness, 255);
        SDL_Rect rect = {(int)stars[i].x, (int)stars[i].y, stars[i].size, stars[i].size};
        SDL_RenderFillRect(renderer, &rect);
    }
}

// ==================== JOUEUR ====================

void init_player() {
    player.x = WINDOW_WIDTH / 2;
    player.y = WINDOW_HEIGHT - 60;
    player.width = 40;
    player.height = 30;
}

void draw_player() {
    // Bouclier
    if (shield_active) {
        int shield_radius = 30 + (int)(5.0f * sinf(SDL_GetTicks() * 0.01f));
        set_color(0, 255, 136, 100);
        for (int r = shield_radius - 2; r <= shield_radius + 2; r++) {
            for (int angle = 0; angle < 360; angle += 5) {
                float rad = angle * M_PI / 180.0f;
                int px = (int)(player.x + cosf(rad) * r);
                int py = (int)(player.y + sinf(rad) * r);
                SDL_RenderDrawPoint(renderer, px, py);
            }
        }
    }

    // Vaisseau (triangle)
    set_color(COLOR_PLAYER_R, COLOR_PLAYER_G, COLOR_PLAYER_B, 255);

    // Corps principal
    SDL_Point points[4] = {
        {(int)player.x, (int)player.y - 20},
        {(int)player.x - 18, (int)player.y + 15},
        {(int)player.x + 18, (int)player.y + 15},
        {(int)player.x, (int)player.y - 20}
    };
    SDL_RenderDrawLines(renderer, points, 4);

    // Remplir le triangle
    for (int y = (int)player.y - 20; y <= (int)player.y + 15; y++) {
        float progress = (float)(y - (player.y - 20)) / 35.0f;
        int half_width = (int)(18 * progress);
        SDL_RenderDrawLine(renderer, (int)player.x - half_width, y, (int)player.x + half_width, y);
    }

    // Cockpit
    set_color(255, 255, 255, 255);
    SDL_Rect cockpit = {(int)player.x - 4, (int)player.y - 5, 8, 8};
    SDL_RenderFillRect(renderer, &cockpit);

    // Propulseur
    if (SDL_GetTicks() % 100 < 50) {
        set_color(255, 150, 0, 255);
        SDL_Rect flame = {(int)player.x - 5, (int)player.y + 15, 10, 8};
        SDL_RenderFillRect(renderer, &flame);
    }
}

void move_player(int dx) {
    player.x += dx * PLAYER_SPEED;
    if (player.x < 30) player.x = 30;
    if (player.x > WINDOW_WIDTH - 30) player.x = WINDOW_WIDTH - 30;
}

// ==================== LASERS ====================

void shoot_laser() {
    Uint32 now = SDL_GetTicks();
    Uint32 cooldown = rapid_fire ? 100 : 200;

    if (now - last_shot_time < cooldown) return;
    last_shot_time = now;

    int offsets[3] = {0, 0, 0};
    int num_shots = 1;

    if (triple_shot) {
        offsets[0] = -15;
        offsets[1] = 0;
        offsets[2] = 15;
        num_shots = 3;
    }

    for (int s = 0; s < num_shots; s++) {
        for (int i = 0; i < MAX_LASERS; i++) {
            if (!lasers[i].active) {
                lasers[i].x = player.x + offsets[s];
                lasers[i].y = player.y - 25;
                lasers[i].active = true;
                lasers[i].damage = rapid_fire ? 2 : 1;
                lasers[i].powered = rapid_fire;
                break;
            }
        }
    }
}

void update_lasers() {
    for (int i = 0; i < MAX_LASERS; i++) {
        if (lasers[i].active) {
            lasers[i].y -= LASER_SPEED;
            if (lasers[i].y < -20) {
                lasers[i].active = false;
            }
        }
    }

    for (int i = 0; i < MAX_ENEMY_LASERS; i++) {
        if (enemy_lasers[i].active) {
            enemy_lasers[i].y += ENEMY_LASER_SPEED;
            if (enemy_lasers[i].y > WINDOW_HEIGHT + 20) {
                enemy_lasers[i].active = false;
            }
        }
    }
}

void draw_lasers() {
    for (int i = 0; i < MAX_LASERS; i++) {
        if (lasers[i].active) {
            if (lasers[i].powered) {
                set_color(255, 215, 0, 255);
            } else {
                set_color(COLOR_LASER_R, COLOR_LASER_G, COLOR_LASER_B, 255);
            }
            SDL_Rect rect = {(int)lasers[i].x - 2, (int)lasers[i].y, 4, 18};
            SDL_RenderFillRect(renderer, &rect);

            // Glow
            set_color(255, 255, 255, 100);
            SDL_Rect glow = {(int)lasers[i].x - 4, (int)lasers[i].y - 2, 8, 22};
            SDL_RenderDrawRect(renderer, &glow);
        }
    }

    for (int i = 0; i < MAX_ENEMY_LASERS; i++) {
        if (enemy_lasers[i].active) {
            set_color(COLOR_ENEMY_LASER_R, COLOR_ENEMY_LASER_G, COLOR_ENEMY_LASER_B, 255);
            SDL_Rect rect = {(int)enemy_lasers[i].x - 2, (int)enemy_lasers[i].y, 4, 15};
            SDL_RenderFillRect(renderer, &rect);
        }
    }
}

void atomic_blast() {
    for (float x = 20; x < WINDOW_WIDTH - 20; x += 25) {
        for (int i = 0; i < MAX_LASERS; i++) {
            if (!lasers[i].active) {
                lasers[i].x = x;
                lasers[i].y = player.y - 25;
                lasers[i].active = true;
                lasers[i].damage = 1;
                lasers[i].powered = false;
                break;
            }
        }
    }
}

// ==================== ALIENS ====================

void spawn_alien_wave() {
    // Reset aliens
    for (int i = 0; i < MAX_ALIENS; i++) {
        aliens[i].active = false;
    }

    boss.active = false;
    alien_direction = 1;
    alien_speed_mult = 1.0f + level * 0.1f;

    // Boss tous les 5 niveaux
    if (level % 5 == 0) {
        boss.x = WINDOW_WIDTH / 2;
        boss.y = 100;
        boss.health = 30 + level * 10;
        boss.max_health = boss.health;
        boss.direction = 1;
        boss.shoot_timer = 0;
        boss.active = true;
        return;
    }

    int rows = 3 + level / 2;
    if (rows > 6) rows = 6;
    int cols = 6 + level / 3;
    if (cols > 9) cols = 9;

    int spacing_x = 65;
    int spacing_y = 50;
    int start_x = (WINDOW_WIDTH - (cols - 1) * spacing_x) / 2;
    int start_y = 80;

    int idx = 0;
    for (int row = 0; row < rows && idx < MAX_ALIENS; row++) {
        for (int col = 0; col < cols && idx < MAX_ALIENS; col++) {
            aliens[idx].x = start_x + col * spacing_x;
            aliens[idx].y = start_y + row * spacing_y;
            aliens[idx].health = 1 + row / 2;
            aliens[idx].max_health = aliens[idx].health;
            aliens[idx].points = 10 * (row + 1);
            aliens[idx].type = row % 3;
            aliens[idx].r = alien_colors[row % 5][0];
            aliens[idx].g = alien_colors[row % 5][1];
            aliens[idx].b = alien_colors[row % 5][2];
            aliens[idx].active = true;
            idx++;
        }
    }
}

void update_aliens() {
    if (boss.active) {
        boss.x += 4 * boss.direction;
        if (boss.x > WINDOW_WIDTH - 80 || boss.x < 80) {
            boss.direction *= -1;
        }

        boss.shoot_timer += 1.0f / FPS;
        if (boss.shoot_timer > 0.5f && randf() < 0.03f) {
            boss.shoot_timer = 0;
            for (int offset = -25; offset <= 25; offset += 25) {
                for (int i = 0; i < MAX_ENEMY_LASERS; i++) {
                    if (!enemy_lasers[i].active) {
                        enemy_lasers[i].x = boss.x + offset;
                        enemy_lasers[i].y = boss.y + 40;
                        enemy_lasers[i].active = true;
                        break;
                    }
                }
            }
        }
        return;
    }

    bool edge_hit = false;
    float shift = ALIEN_SPEED_BASE * alien_speed_mult * alien_direction;

    for (int i = 0; i < MAX_ALIENS; i++) {
        if (aliens[i].active) {
            aliens[i].x += shift;
            if (aliens[i].x > WINDOW_WIDTH - 40 || aliens[i].x < 40) {
                edge_hit = true;
            }
        }
    }

    if (edge_hit) {
        alien_direction *= -1;
        for (int i = 0; i < MAX_ALIENS; i++) {
            if (aliens[i].active) {
                aliens[i].y += ALIEN_DROP;
            }
        }
    }

    // Tir aléatoire des aliens
    for (int i = 0; i < MAX_ALIENS; i++) {
        if (aliens[i].active && randf() < 0.001f * (1 + level * 0.1f)) {
            for (int j = 0; j < MAX_ENEMY_LASERS; j++) {
                if (!enemy_lasers[j].active) {
                    enemy_lasers[j].x = aliens[i].x;
                    enemy_lasers[j].y = aliens[i].y + 15;
                    enemy_lasers[j].active = true;
                    break;
                }
            }
        }
    }
}

void draw_aliens() {
    for (int i = 0; i < MAX_ALIENS; i++) {
        if (aliens[i].active) {
            set_color(aliens[i].r, aliens[i].g, aliens[i].b, 255);

            int cx = (int)aliens[i].x;
            int cy = (int)aliens[i].y;
            int size = 12 + aliens[i].type * 2;

            // Forme selon le type
            if (aliens[i].type == 0) {
                // Cercle
                for (int r = size - 2; r <= size; r++) {
                    for (int angle = 0; angle < 360; angle += 10) {
                        float rad = angle * M_PI / 180.0f;
                        int px = cx + (int)(cosf(rad) * r);
                        int py = cy + (int)(sinf(rad) * r);
                        SDL_RenderDrawPoint(renderer, px, py);
                    }
                }
                // Yeux
                set_color(0, 0, 0, 255);
                SDL_Rect eye1 = {cx - 5, cy - 3, 4, 4};
                SDL_Rect eye2 = {cx + 2, cy - 3, 4, 4};
                SDL_RenderFillRect(renderer, &eye1);
                SDL_RenderFillRect(renderer, &eye2);
            } else if (aliens[i].type == 1) {
                // Carré
                SDL_Rect rect = {cx - size, cy - size, size * 2, size * 2};
                SDL_RenderFillRect(renderer, &rect);
                set_color(0, 0, 0, 255);
                SDL_Rect eye1 = {cx - 6, cy - 5, 5, 5};
                SDL_Rect eye2 = {cx + 2, cy - 5, 5, 5};
                SDL_RenderFillRect(renderer, &eye1);
                SDL_RenderFillRect(renderer, &eye2);
            } else {
                // Triangle
                set_color(aliens[i].r, aliens[i].g, aliens[i].b, 255);
                for (int y = cy - size; y <= cy + size; y++) {
                    float progress = (float)(y - (cy - size)) / (size * 2);
                    int half_width = (int)(size * progress);
                    SDL_RenderDrawLine(renderer, cx - half_width, y, cx + half_width, y);
                }
            }
        }
    }

    // Boss
    if (boss.active) {
        // Corps
        set_color(255, 0, 255, 255);
        for (int r = 35; r <= 40; r++) {
            for (int angle = 0; angle < 360; angle += 3) {
                float rad = angle * M_PI / 180.0f;
                int px = (int)boss.x + (int)(cosf(rad) * r);
                int py = (int)boss.y + (int)(sinf(rad) * r * 0.7f);
                SDL_RenderDrawPoint(renderer, px, py);
            }
        }

        // Remplir
        for (int y = (int)boss.y - 28; y <= (int)boss.y + 28; y++) {
            float fy = (float)(y - boss.y) / 28.0f;
            int half_width = (int)(40 * sqrtf(1 - fy * fy));
            SDL_RenderDrawLine(renderer, (int)boss.x - half_width, y, (int)boss.x + half_width, y);
        }

        // Yeux
        set_color(255, 255, 0, 255);
        SDL_Rect eye1 = {(int)boss.x - 15, (int)boss.y - 10, 10, 10};
        SDL_Rect eye2 = {(int)boss.x + 5, (int)boss.y - 10, 10, 10};
        SDL_RenderFillRect(renderer, &eye1);
        SDL_RenderFillRect(renderer, &eye2);

        // Barre de vie
        int bar_width = 120;
        int bar_height = 10;
        int bar_x = (int)boss.x - bar_width / 2;
        int bar_y = (int)boss.y - 55;

        set_color(50, 50, 50, 255);
        SDL_Rect bg = {bar_x, bar_y, bar_width, bar_height};
        SDL_RenderFillRect(renderer, &bg);

        float health_pct = (float)boss.health / boss.max_health;
        int health_width = (int)(bar_width * health_pct);

        if (health_pct > 0.5f) set_color(0, 255, 0, 255);
        else if (health_pct > 0.25f) set_color(255, 255, 0, 255);
        else set_color(255, 0, 0, 255);

        SDL_Rect health_bar = {bar_x, bar_y, health_width, bar_height};
        SDL_RenderFillRect(renderer, &health_bar);
    }
}

// ==================== POWER-UPS ====================

void spawn_powerup(float x, float y) {
    for (int i = 0; i < MAX_POWERUPS; i++) {
        if (!powerups[i].active) {
            powerups[i].x = x;
            powerups[i].y = y;
            powerups[i].type = randi(0, 4);
            powerups[i].angle = 0;
            powerups[i].active = true;
            return;
        }
    }
}

void update_powerups() {
    for (int i = 0; i < MAX_POWERUPS; i++) {
        if (powerups[i].active) {
            powerups[i].y += 2;
            powerups[i].angle += 3;
            if (powerups[i].y > WINDOW_HEIGHT + 20) {
                powerups[i].active = false;
            }
        }
    }
}

void draw_powerups() {
    Uint8 colors[][3] = {
        {0, 255, 136},   // shield
        {255, 0, 255},   // rapid
        {255, 215, 0},   // triple
        {255, 107, 107}, // life
        {255, 69, 0}     // bomb
    };

    for (int i = 0; i < MAX_POWERUPS; i++) {
        if (powerups[i].active) {
            set_color(colors[powerups[i].type][0], colors[powerups[i].type][1], colors[powerups[i].type][2], 255);

            int cx = (int)powerups[i].x;
            int cy = (int)powerups[i].y;

            // Étoile rotative
            for (int p = 0; p < 8; p++) {
                float angle = (powerups[i].angle + p * 45) * M_PI / 180.0f;
                int r = (p % 2 == 0) ? 12 : 6;
                int px = cx + (int)(cosf(angle) * r);
                int py = cy + (int)(sinf(angle) * r);
                SDL_RenderDrawLine(renderer, cx, cy, px, py);
            }
        }
    }
}

void apply_powerup(int type) {
    switch (type) {
        case 0: // Shield
            shield_active = true;
            shield_timer = 600;
            break;
        case 1: // Rapid
            rapid_fire = true;
            rapid_timer = 480;
            break;
        case 2: // Triple
            triple_shot = true;
            triple_timer = 420;
            break;
        case 3: // Life
            if (lives < MAX_LIVES) lives++;
            break;
        case 4: // Bomb
            atomic_blast();
            break;
    }
}

void update_powerup_timers() {
    if (shield_active) {
        shield_timer--;
        if (shield_timer <= 0) shield_active = false;
    }
    if (rapid_fire) {
        rapid_timer--;
        if (rapid_timer <= 0) rapid_fire = false;
    }
    if (triple_shot) {
        triple_timer--;
        if (triple_timer <= 0) triple_shot = false;
    }
}

// ==================== COLLISIONS ====================

float distance(float x1, float y1, float x2, float y2) {
    float dx = x2 - x1;
    float dy = y2 - y1;
    return sqrtf(dx * dx + dy * dy);
}

void check_collisions() {
    // Lasers vs Boss
    if (boss.active) {
        for (int i = 0; i < MAX_LASERS; i++) {
            if (lasers[i].active && distance(lasers[i].x, lasers[i].y, boss.x, boss.y) < 45) {
                boss.health -= lasers[i].damage;
                lasers[i].active = false;
                spawn_explosion(lasers[i].x, lasers[i].y, 255, 0, 255, 5);

                if (boss.health <= 0) {
                    spawn_explosion(boss.x, boss.y, 255, 0, 255, 50);
                    score += 500 * level;
                    boss.active = false;
                }
            }
        }
    }

    // Lasers vs Aliens
    for (int i = 0; i < MAX_LASERS; i++) {
        if (!lasers[i].active) continue;

        for (int j = 0; j < MAX_ALIENS; j++) {
            if (!aliens[j].active) continue;

            if (distance(lasers[i].x, lasers[i].y, aliens[j].x, aliens[j].y) < 20) {
                aliens[j].health -= lasers[i].damage;
                lasers[i].active = false;

                if (aliens[j].health <= 0) {
                    spawn_explosion(aliens[j].x, aliens[j].y, aliens[j].r, aliens[j].g, aliens[j].b, 15);

                    combo++;
                    combo_timer = 60;
                    score += aliens[j].points * combo;

                    if (randf() < 0.12f) {
                        spawn_powerup(aliens[j].x, aliens[j].y);
                    }

                    aliens[j].active = false;
                }
                break;
            }
        }
    }

    // Enemy lasers vs Player
    for (int i = 0; i < MAX_ENEMY_LASERS; i++) {
        if (enemy_lasers[i].active && distance(enemy_lasers[i].x, enemy_lasers[i].y, player.x, player.y) < 20) {
            enemy_lasers[i].active = false;

            if (shield_active) {
                spawn_explosion(player.x, player.y, 0, 255, 136, 10);
            } else {
                lives--;
                spawn_explosion(player.x, player.y, COLOR_PLAYER_R, COLOR_PLAYER_G, COLOR_PLAYER_B, 20);
                if (lives <= 0) {
                    game_state = STATE_GAMEOVER;
                }
            }
        }
    }

    // Powerups vs Player
    for (int i = 0; i < MAX_POWERUPS; i++) {
        if (powerups[i].active && distance(powerups[i].x, powerups[i].y, player.x, player.y) < 25) {
            apply_powerup(powerups[i].type);
            powerups[i].active = false;
        }
    }

    // Aliens reaching bottom
    for (int i = 0; i < MAX_ALIENS; i++) {
        if (aliens[i].active && aliens[i].y > WINDOW_HEIGHT - 80) {
            if (!shield_active) lives--;
            spawn_alien_wave();
            if (lives <= 0) {
                game_state = STATE_GAMEOVER;
            }
            return;
        }
    }

    // Update high score
    if (score > high_score) high_score = score;
}

// ==================== HUD ====================

void draw_text(const char *text, int x, int y, Uint8 r, Uint8 g, Uint8 b) {
    // Simple text rendering using rectangles (basic)
    set_color(r, g, b, 255);
    int cx = x;
    for (const char *c = text; *c; c++) {
        // Just draw dots for each character position
        SDL_Rect rect = {cx, y, 8, 12};
        SDL_RenderDrawRect(renderer, &rect);
        cx += 10;
    }
}

void draw_hud() {
    // Score
    set_color(248, 248, 242, 255);
    char score_text[64];
    sprintf(score_text, "Score: %d", score);
    // Simplified text display
    SDL_Rect score_bg = {10, 10, 150, 25};
    SDL_RenderDrawRect(renderer, &score_bg);

    // High score
    set_color(255, 183, 3, 255);
    SDL_Rect high_bg = {10, 40, 130, 20};
    SDL_RenderDrawRect(renderer, &high_bg);

    // Level
    set_color(248, 248, 242, 255);
    SDL_Rect level_bg = {WINDOW_WIDTH/2 - 50, 10, 100, 25};
    SDL_RenderDrawRect(renderer, &level_bg);

    // Lives (hearts)
    for (int i = 0; i < MAX_LIVES; i++) {
        if (i < lives) {
            set_color(255, 107, 107, 255);
        } else {
            set_color(100, 100, 100, 255);
        }
        SDL_Rect heart = {WINDOW_WIDTH - 180 + i * 30, 15, 20, 20};
        SDL_RenderFillRect(renderer, &heart);
    }

    // Combo
    if (combo > 1) {
        set_color(255, 215, 0, 255);
        SDL_Rect combo_bg = {WINDOW_WIDTH/2 - 40, 40, 80, 20};
        SDL_RenderFillRect(renderer, &combo_bg);
    }

    // Power-up timers
    int y_offset = 70;
    if (shield_active) {
        set_color(0, 255, 136, 255);
        SDL_Rect timer = {WINDOW_WIDTH - 100, y_offset, shield_timer / 6, 10};
        SDL_RenderFillRect(renderer, &timer);
        y_offset += 15;
    }
    if (rapid_fire) {
        set_color(255, 0, 255, 255);
        SDL_Rect timer = {WINDOW_WIDTH - 100, y_offset, rapid_timer / 5, 10};
        SDL_RenderFillRect(renderer, &timer);
        y_offset += 15;
    }
    if (triple_shot) {
        set_color(255, 215, 0, 255);
        SDL_Rect timer = {WINDOW_WIDTH - 100, y_offset, triple_timer / 4, 10};
        SDL_RenderFillRect(renderer, &timer);
    }

    // Score et level en texte simple
    set_color(255, 255, 255, 255);
    // On dessine les chiffres du score
    int sx = 20;
    int temp_score = score;
    char digits[20];
    sprintf(digits, "SCORE:%d", score);
    for (int i = 0; digits[i]; i++) {
        SDL_Rect digit = {sx + i * 12, 15, 10, 15};
        SDL_RenderDrawRect(renderer, &digit);
    }

    // Level
    sprintf(digits, "LVL:%d", level);
    for (int i = 0; digits[i]; i++) {
        SDL_Rect digit = {WINDOW_WIDTH/2 - 30 + i * 12, 15, 10, 15};
        SDL_RenderDrawRect(renderer, &digit);
    }
}

void draw_menu() {
    // Titre
    set_color(255, 183, 3, 255);
    SDL_Rect title = {WINDOW_WIDTH/2 - 180, 150, 360, 60};
    SDL_RenderDrawRect(renderer, &title);
    SDL_RenderDrawRect(renderer, &(SDL_Rect){title.x+2, title.y+2, title.w-4, title.h-4});

    // Instructions
    set_color(248, 248, 242, 255);
    SDL_Rect instr = {WINDOW_WIDTH/2 - 150, 280, 300, 30};
    SDL_RenderDrawRect(renderer, &instr);

    // Contrôles
    set_color(155, 255, 86, 255);
    SDL_Rect ctrl1 = {WINDOW_WIDTH/2 - 120, 350, 240, 25};
    SDL_Rect ctrl2 = {WINDOW_WIDTH/2 - 100, 380, 200, 25};
    SDL_RenderDrawRect(renderer, &ctrl1);
    SDL_RenderDrawRect(renderer, &ctrl2);

    // "SPACE INVADERS 3.0" et "PRESS SPACE" en gros
    set_color(255, 183, 3, 255);
    for (int i = 0; i < 16; i++) {
        SDL_Rect letter = {WINDOW_WIDTH/2 - 160 + i * 20, 165, 15, 30};
        SDL_RenderFillRect(renderer, &letter);
    }

    set_color(255, 255, 255, 255);
    for (int i = 0; i < 11; i++) {
        SDL_Rect letter = {WINDOW_WIDTH/2 - 100 + i * 18, 285, 12, 20};
        SDL_RenderFillRect(renderer, &letter);
    }
}

void draw_gameover() {
    set_color(255, 68, 68, 255);
    SDL_Rect title = {WINDOW_WIDTH/2 - 120, 200, 240, 50};
    SDL_RenderFillRect(renderer, &title);

    set_color(248, 248, 242, 255);
    SDL_Rect score_box = {WINDOW_WIDTH/2 - 100, 280, 200, 30};
    SDL_RenderDrawRect(renderer, &score_box);

    SDL_Rect high_box = {WINDOW_WIDTH/2 - 100, 320, 200, 30};
    SDL_RenderDrawRect(renderer, &high_box);

    set_color(155, 255, 86, 255);
    SDL_Rect restart = {WINDOW_WIDTH/2 - 80, 400, 160, 30};
    SDL_RenderDrawRect(renderer, &restart);
}

void draw_pause() {
    set_color(0, 0, 0, 180);
    SDL_Rect overlay = {0, 0, WINDOW_WIDTH, WINDOW_HEIGHT};
    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
    SDL_RenderFillRect(renderer, &overlay);

    set_color(255, 183, 3, 255);
    SDL_Rect title = {WINDOW_WIDTH/2 - 80, WINDOW_HEIGHT/2 - 30, 160, 60};
    SDL_RenderFillRect(renderer, &title);
}

// ==================== GAME LOGIC ====================

void start_game() {
    game_state = STATE_PLAYING;
    score = 0;
    lives = MAX_LIVES;
    level = 1;
    combo = 0;
    shield_active = false;
    rapid_fire = false;
    triple_shot = false;

    for (int i = 0; i < MAX_LASERS; i++) lasers[i].active = false;
    for (int i = 0; i < MAX_ENEMY_LASERS; i++) enemy_lasers[i].active = false;
    for (int i = 0; i < MAX_PARTICLES; i++) particles[i].life = 0;
    for (int i = 0; i < MAX_POWERUPS; i++) powerups[i].active = false;

    init_player();
    spawn_alien_wave();
}

void check_level_complete() {
    if (boss.active) return;

    bool any_active = false;
    for (int i = 0; i < MAX_ALIENS; i++) {
        if (aliens[i].active) {
            any_active = true;
            break;
        }
    }

    if (!any_active) {
        level++;
        spawn_alien_wave();
    }
}

// ==================== MAIN ====================

int main(int argc, char *argv[]) {
    srand((unsigned int)time(NULL));

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        printf("SDL init failed: %s\n", SDL_GetError());
        return 1;
    }

    window = SDL_CreateWindow(
        "Space Invaders 3.0 - C/SDL2",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        WINDOW_WIDTH, WINDOW_HEIGHT,
        SDL_WINDOW_SHOWN
    );

    if (!window) {
        printf("Window creation failed: %s\n", SDL_GetError());
        SDL_Quit();
        return 1;
    }

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
        printf("Renderer creation failed: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);

    // Initialisation
    init_stars();
    init_player();

    SDL_Event event;
    Uint32 frame_start;
    int frame_time;

    const Uint8 *keyboard = SDL_GetKeyboardState(NULL);

    while (running) {
        frame_start = SDL_GetTicks();

        // Events
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_QUIT) {
                running = false;
            }
            if (event.type == SDL_KEYDOWN) {
                switch (event.key.keysym.sym) {
                    case SDLK_ESCAPE:
                    case SDLK_q:
                        running = false;
                        break;
                    case SDLK_SPACE:
                        if (game_state == STATE_MENU) {
                            start_game();
                        } else if (game_state == STATE_PLAYING) {
                            shoot_laser();
                        }
                        break;
                    case SDLK_p:
                        if (game_state == STATE_PLAYING) {
                            game_state = STATE_PAUSED;
                        } else if (game_state == STATE_PAUSED) {
                            game_state = STATE_PLAYING;
                        }
                        break;
                    case SDLK_r:
                        if (game_state == STATE_GAMEOVER) {
                            start_game();
                        }
                        break;
                    case SDLK_w:
                    case SDLK_a:
                        if (game_state == STATE_PLAYING) {
                            atomic_blast();
                        }
                        break;
                }
            }
        }

        // Continuous input
        if (game_state == STATE_PLAYING) {
            if (keyboard[SDL_SCANCODE_LEFT]) move_player(-1);
            if (keyboard[SDL_SCANCODE_RIGHT]) move_player(1);
        }

        // Update
        update_stars();

        if (game_state == STATE_PLAYING) {
            update_lasers();
            update_aliens();
            update_particles();
            update_powerups();
            update_powerup_timers();
            check_collisions();
            check_level_complete();

            if (combo_timer > 0) combo_timer--;
            else combo = 0;
        } else if (game_state == STATE_GAMEOVER) {
            update_particles();
        }

        // Render
        set_color(COLOR_BG_R, COLOR_BG_G, COLOR_BG_B, 255);
        SDL_RenderClear(renderer);

        draw_stars();

        if (game_state == STATE_MENU) {
            draw_menu();
        } else if (game_state == STATE_PLAYING || game_state == STATE_PAUSED) {
            draw_lasers();
            draw_aliens();
            draw_player();
            draw_particles();
            draw_powerups();
            draw_hud();

            if (game_state == STATE_PAUSED) {
                draw_pause();
            }
        } else if (game_state == STATE_GAMEOVER) {
            draw_lasers();
            draw_aliens();
            draw_particles();
            draw_hud();
            draw_gameover();
        }

        SDL_RenderPresent(renderer);

        // Frame rate control
        frame_time = SDL_GetTicks() - frame_start;
        if (frame_time < FRAME_DELAY) {
            SDL_Delay(FRAME_DELAY - frame_time);
        }
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();

    return 0;
}
