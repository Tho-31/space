import random
import time
import turtle
import pdb

#python3 -m pdb space.py
#n execute une ligne
#s entre dans une fonction
#c continue jusqu'au procahin point d'arret
#l liste le code autour de la ligne actuelle
#p <variable> affiche une variable
#q quitter

CANNON_STEP = 30
LASER_LENGTH = 20
LASER_SPEED = 20
ALIEN_SPAWN_INTERVAL = 0.5 #temps en secondes
ALIEN_SPEED = 0.8

window = turtle.Screen()
window.tracer(0)
window.setup(0.5, 0.75)
window.bgcolor(0, 0, 0)
window.title("Space Invader")

LEFT = -window.window_width() / 2
RIGHT = window.window_width() / 2
TOP = window.window_height() / 2
BOTTOM = -window.window_height() / 2
FLOOR_LEVEL = 0.9 * BOTTOM
GUTTER = 0.025 * window.window_width()

#créé le canon
cannon = turtle.Turtle()
cannon.penup()
cannon.color(1, 1, 1)
cannon.shape("square")
cannon.setposition(0, FLOOR_LEVEL)

#crée un objet texte pour afficher du texte
text = turtle.Turtle()
text.penup()
text.hideturtle()
text.setposition(LEFT * 0.8, TOP * 0.8)
text.color(1, 1, 1)

#Dessine le cannon

lasers = []
aliens = []
remove_list = []

def draw_cannon():
    cannon.clear()
    cannon.turtlesize(1, 4)
    cannon.stamp()
    cannon.sety(FLOOR_LEVEL + 10)
    cannon.turtlesize(1, 1.5)

    cannon.stamp()
    cannon.sety(FLOOR_LEVEL + 20)
    cannon.turtlesize(0.8, 0.3)

    cannon.stamp()
    cannon.sety(FLOOR_LEVEL)

def create_alien():
    alien = turtle.Turtle()
    alien.penup()
    alien.turtlesize(1.5)
    alien.setposition(random.randint(int(LEFT + GUTTER), int(RIGHT - GUTTER), ), TOP, )
    alien.shape("turtle")
    alien.setheading(-90)
    alien.color(random.random(), random.random(), random.random())
    aliens.append(alien)


#Deplacement

def move_left():
    new_x = cannon.xcor() - CANNON_STEP
    if new_x >= LEFT + GUTTER:
        cannon.setx(new_x)
        draw_cannon()

def move_right():
    new_x = cannon.xcor() + CANNON_STEP
    if new_x <= RIGHT - GUTTER:
        cannon.setx(new_x)
        draw_cannon()

def create_lasers():
    laser = turtle.Turtle()
    laser.penup()
    laser.color(1, 0, 0)
    laser.hideturtle()
    laser.setposition(cannon.xcor(), cannon.ycor())
    laser.setheading(90)
    laser.forward(20)
    laser.pendown()
    laser.pensize(5)

    lasers.append(laser)

def create_lasers2(x, y):
    laser = turtle.Turtle()
    laser.penup()
    laser.color(1, 0, 0)
    laser.hideturtle()
    laser.setposition(x, y)
    laser.setheading(90)
    laser.forward(20)
    laser.pendown()
    laser.pensize(5)

    lasers.append(laser)

def move_laser(laser):
    laser.clear()
    laser.forward(LASER_SPEED)
    laser.forward(LASER_LENGTH)
    laser.forward(-LASER_LENGTH)
        
def remove_sprite(sprite, sprite_list):
    sprite.clear()
    sprite.hideturtle()
    #window.update()
    sprite_list.remove(sprite)
    #turtle.turtles().remove(sprite)
    remove_list.append(sprite)

def atomic():
    #envoie des lasers sur toute la largeure de l'ecrant tout les x pixels
    cursor = LEFT
    while cursor < RIGHT :
        cursor += 10
        create_lasers2(cursor, FLOOR_LEVEL)

def quit_game():
    global game_running, exit_app
    game_running = False
    exit_app = True

window.onkeypress(move_left, "Left")
window.onkeypress(move_right, "Right")
window.onkeypress(create_lasers, "space")
window.onkeypress(quit_game, "q")
window.onkeypress(atomic, "a")
window.listen()

draw_cannon()
#boucle de jeu
#pdb.set_trace() #le programe s'arret ici, c'est un break point
alien_timer = 0
score = 0
tic = 0
game_timer = time.time()
game_running = True
exit_app = False
while game_running:
    tic += 1
    time_elapsed = time.time() - game_timer
    text.clear()
    text.write(f"Time: {time_elapsed:5.1f}s\nScore: {score:5}", font=("Courier", 20, "bold"), )
    for laser in lasers.copy() :
        move_laser(laser)
        if laser.ycor() > TOP:
            #pdb.set_trace()
            remove_sprite(laser, lasers)
            #break
        else:
#verification de collision avec les aliens        
            for alien in aliens.copy():
                if laser.distance(alien) < 20:
                    #pdb.set_trace()
                    remove_sprite(laser, lasers)
                    remove_sprite(alien, aliens)
                    score += 1

    if time.time() - alien_timer > ALIEN_SPAWN_INTERVAL :
        create_alien()
        alien_timer = time.time()

    for alien in aliens:
        alien.forward(ALIEN_SPEED)
        if alien.ycor() < FLOOR_LEVEL :
            game_running = False
            break    
    window.update()
    for sprite in remove_list:
        turtle.turtles().remove(sprite)
    remove_list.clear()
    time.sleep(0.01)

print(tic)    
splash_text = turtle.Turtle()
splash_text.hideturtle()
splash_text.color(1, 1, 1)
splash_text.write("GAME OVER", font=("Courier", 40, "bold"), align="center")
#print("coucou")
if not exit_app:
    turtle.done()
turtle.bye()


