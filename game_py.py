# game_py.py
# Real-time frontend for multi-enemy Verilog hardware engine
# Supports 3 enemies (enemy0, enemy1, enemy2)
# Records all actions so testbench can replay EXACT movements
# Press S -> generate snapshot_tb.v + run + open GTKWave

import pygame
import sys
import time
import random

from verilog_recorder import Recorder

# -----------------------------
# Configuration
# -----------------------------
COLS = 20
ROWS = 15
CELL_SIZE = 24
MARGIN = 4
INFO_HEIGHT = 120
FPS = 30

# bullet & enemy movement timers (Python frames)
BULLET_MOVE_FRAMES = 6
ENEMY_MOVE_FRAMES = 9

PLAYER_START_X = COLS // 2
PLAYER_ROW = ROWS - 1
FIRE_COOLDOWN_SEC = 0.25

WHITE=(255,255,255)
BLACK=(0,0,0)
GRAY=(200,200,200)
RED=(255,50,50)
BLUE=(60,60,255)
YELLOW=(255,240,0)

GRID_WIDTH = COLS * CELL_SIZE
GRID_HEIGHT = ROWS * CELL_SIZE
SCREEN_WIDTH = GRID_WIDTH + 2*MARGIN
SCREEN_HEIGHT = GRID_HEIGHT + INFO_HEIGHT + 3*MARGIN


# -----------------------------
# Game objects
# -----------------------------
class Player:
    def __init__(self,x):
        self.x=x
        self.y=PLAYER_ROW

class Bullet:
    def __init__(self):
        self.active=False
        self.x=0
        self.y=0
        self.timer=0

    def spawn(self,px,py):
        if not self.active:
            self.active=True
            self.x=px
            self.y=py-1
            self.timer=0

    def update(self):
        if not self.active: return
        self.timer+=1
        if self.timer>=BULLET_MOVE_FRAMES:
            self.timer=0
            if self.y>0: self.y-=1
            else: self.active=False


class Enemy:
    def __init__(self):
        self.active=False
        self.x=0
        self.y=0
        self.timer=0

    def spawn(self,x,y):
        self.active=True
        self.x=x
        self.y=y
        self.timer=0

    def update(self):
        if not self.active: return
        self.timer+=1
        if self.timer>=ENEMY_MOVE_FRAMES:
            self.timer=0
            if self.y < ROWS-1: self.y += 1
            else: self.active=False


# -----------------------------
# Full Game State with 3 enemies
# -----------------------------
class GameState:
    def __init__(self):
        self.player = Player(PLAYER_START_X)
        self.bullet = Bullet()

        # 3 enemies (same as hardware)
        self.enemies = [Enemy(), Enemy(), Enemy()]

        self.score = 0
        self.last_action = "None"
        self.last_hit = "None"
        self.last_fire_time = 0

    def update_enemies(self):
        for e in self.enemies:
            e.update()

        # auto spawn to maintain 2-3 enemies
        active_count = sum(1 for e in self.enemies if e.active)

        if active_count < 2:
            # spawn in first free slots
            for e in self.enemies:
                if not e.active:
                    e.spawn(random.randint(0,COLS-1), 0)
                    break
        else:
            # chance to spawn a third
            if active_count == 2 and random.random() < 0.03:
                for e in self.enemies:
                    if not e.active:
                        e.spawn(random.randint(0,COLS-1), 0)
                        break

    def check_collision(self):
        if not self.bullet.active:
            return

        for e in self.enemies:
            if e.active and self.bullet.x == e.x and self.bullet.y == e.y:
                # collision
                e.active = False
                self.bullet.active = False
                self.score += 1
                self.last_hit = f"Hit at ({e.x},{e.y})"
                return


# -----------------------------
# Drawing
# -----------------------------
def draw_grid(surface):
    surface.fill(BLACK)
    for r in range(ROWS):
        for c in range(COLS):
            pygame.draw.rect(surface,GRAY,(MARGIN+c*CELL_SIZE, MARGIN+r*CELL_SIZE,
                                           CELL_SIZE-1, CELL_SIZE-1),1)

def draw_cell(screen,x,y,color):
    pygame.draw.rect(screen, color,
        (MARGIN+x*CELL_SIZE+1, MARGIN+y*CELL_SIZE+1, CELL_SIZE-2, CELL_SIZE-2))

def draw_info(screen,state,font):
    top = MARGIN + GRID_HEIGHT + MARGIN
    pygame.draw.rect(screen,(30,30,30),(0,top,SCREEN_WIDTH,INFO_HEIGHT))

    lines = [
        f"Score: {state.score}",
        f"Player: ({state.player.x},{state.player.y})",
        f"Bullet: ({state.bullet.x if state.bullet.active else '--'}, "
        f"{state.bullet.y if state.bullet.active else '--'})",
        f"Last action: {state.last_action}",
        f"Last hit: {state.last_hit}",
        "Controls: L/R/A/D move | SPACE fire | S snapshot"
    ]

    for i,line in enumerate(lines):
        screen.blit(font.render(line,True,WHITE),(10,top+5+i*18))


# -----------------------------
# MAIN
# -----------------------------
def main():
    pygame.init()
    screen=pygame.display.set_mode((SCREEN_WIDTH,SCREEN_HEIGHT))
    pygame.display.set_caption("Space Shooter - 3 Enemy Engine (Python Frontend)")
    clock=pygame.time.Clock()
    font=pygame.font.SysFont("Consolas",16)

    state = GameState()
    rec = Recorder()
    rec.start()

    running = True
    while running:
        dt = clock.tick(FPS) / 1000.0
        rec.tick()

        now = time.time()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False

            if event.type == pygame.KEYDOWN:

                if event.key in (pygame.K_q, pygame.K_ESCAPE):
                    running = False

                # Move Left
                elif event.key in (pygame.K_LEFT, pygame.K_a):
                    if state.player.x > 0:
                        state.player.x -= 1
                    state.last_action = "Left"
                    rec.record("left")

                # Move Right
                elif event.key in (pygame.K_RIGHT, pygame.K_d):
                    if state.player.x < COLS-1:
                        state.player.x += 1
                    state.last_action = "Right"
                    rec.record("right")

                # Shoot
                elif event.key == pygame.K_SPACE:
                    if now - state.last_fire_time >= FIRE_COOLDOWN_SEC:
                        state.bullet.spawn(state.player.x, state.player.y)
                        state.last_fire_time = now
                        state.last_action = "Fire"
                        rec.record("shoot")

                # Snapshot → Verilog TB + run + GTKWave
                elif event.key == pygame.K_s:
                    print("\nGenerating snapshot_tb.v and opening GTKWave...")
                    rec.snapshot()

        # Update world
        state.bullet.update()
        state.update_enemies()
        state.check_collision()

        # Draw everything
        draw_grid(screen)

        # draw enemies
        for e in state.enemies:
            if e.active:
                draw_cell(screen, e.x, e.y, RED)

        # draw bullet
        if state.bullet.active:
            draw_cell(screen, state.bullet.x, state.bullet.y, YELLOW)

        # draw player
        draw_cell(screen, state.player.x, state.player.y, BLUE)

        draw_info(screen, state, font)
        pygame.display.flip()

    pygame.quit()
    sys.exit()


if __name__ == "__main__":
    main()
