import pygame
from config import *
import random
import time
import math

class Puck:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.radius = PUCK_RADIUS
        self.color = BLACK
        self.speed = PUCK_SPEED
        self.dx = self.speed * random.choice([-1, 1])
        self.dy = self.speed * random.choice([-1, 1])

    def move(self):
        self.x += self.dx
        self.y += self.dy

    def bounce(self):
        # Top and bottom walls
        if self.y - self.radius <= 0 or self.y + self.radius >= SCREEN_HEIGHT:
            self.dy *= -1

        goal_y_start = (SCREEN_HEIGHT - GOAL_HEIGHT) // 2
        goal_y_end = goal_y_start + GOAL_HEIGHT

        # Left wall bounce
        if self.x - self.radius <= 0 and not (goal_y_start < self.y < goal_y_end):
            self.x = self.radius
            self.dx *= -1
        
        # Right wall bounce
        if self.x + self.radius >= SCREEN_WIDTH and not (goal_y_start < self.y < goal_y_end):
            self.x = SCREEN_WIDTH - self.radius
            self.dx *= -1

    def reset(self):
        self.x = SCREEN_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2
        self.dx = self.speed * random.choice([-1, 1])
        self.dy = self.speed * random.choice([-1, 1])

    def draw(self, screen):
        pygame.draw.circle(screen, self.color, (int(self.x), int(self.y)), self.radius)

class Player:
    def __init__(self, x, y, color, speed, radius):
        self.x = x
        self.y = y
        self.color = color
        self.speed = speed
        self.radius = radius
        self.last_strike_time = 0

    def can_strike(self):
        return time.time() - self.last_strike_time > STRIKE_COOLDOWN

    def strike(self, puck, dx, dy):
        if self.can_strike():
            distance = math.sqrt((self.x - puck.x)**2 + (self.y - puck.y)**2)
            if distance <= STRIKE_DISTANCE + self.radius:
                puck.dx = dx
                puck.dy = dy
                self.last_strike_time = time.time()
                return True
        return False

    def draw(self, screen):
        pygame.draw.circle(screen, self.color, (int(self.x), int(self.y)), self.radius)

class UserPlayer(Player):
    def __init__(self, x, y):
        super().__init__(x, y, BLUE, PLAYER_SPEED, PLAYER_RADIUS)
        self.boost_active = False
        self.current_speed = self.speed

    def handle_input(self, keys, puck, opponent_goal):
        self.current_speed = self.speed
        if keys[pygame.K_SPACE]:
            self.current_speed = self.speed * 2

        if keys[pygame.K_w]:
            self.y -= self.current_speed
        if keys[pygame.K_s]:
            self.y += self.current_speed
        if keys[pygame.K_a]:
            self.x -= self.current_speed
        if keys[pygame.K_d]:
            self.x += self.current_speed
        
        # Strike logic
        if keys[pygame.K_j]: # Left
            self.strike(puck, -PUCK_SPEED, 0)
        if keys[pygame.K_l]: # Right
            self.strike(puck, PUCK_SPEED, 0)
        if keys[pygame.K_i]: # Up
            self.strike(puck, 0, -PUCK_SPEED)
        if keys[pygame.K_k]: # Down
            self.strike(puck, 0, PUCK_SPEED)
        if keys[pygame.K_m]: # Towards opponent goal
            goal_center_x, goal_center_y = opponent_goal
            angle = math.atan2(goal_center_y - self.y, goal_center_x - self.x)
            dx = PUCK_SPEED * math.cos(angle)
            dy = PUCK_SPEED * math.sin(angle)
            self.strike(puck, dx, dy)

    def update(self):
        # Keep player within screen bounds
        self.x = max(self.radius, min(self.x, SCREEN_WIDTH - self.radius))
        self.y = max(self.radius, min(self.y, SCREEN_HEIGHT - self.radius))

class AIPlayer(Player):
    def __init__(self, x, y, team='ai', can_cross_center=False):
        self.team = team
        self.can_cross_center = can_cross_center
        color = BLUE if self.team == 'user' else RED
        super().__init__(x, y, color, PLAYER_SPEED * 0.8, PLAYER_RADIUS)

    def update(self, puck, target_goal):
        # AI movement: simple logic to follow the puck
        if self.y < puck.y:
            self.y += self.speed
        elif self.y > puck.y:
            self.y -= self.speed
        
        if self.x < puck.x:
             self.x += self.speed
        elif self.x > puck.x:
             self.x -= self.speed

        # Stay in its half of the rink unless allowed to cross
        if not self.can_cross_center:
            if self.team == 'user':
                self.x = max(self.radius, min(self.x, SCREEN_WIDTH // 2 - self.radius))
            else: # opponent team
                self.x = max(SCREEN_WIDTH // 2 + self.radius, min(self.x, SCREEN_WIDTH - self.radius))
        
        self.y = max(self.radius, min(self.y, SCREEN_HEIGHT - self.radius))

        # AI striking
        distance_to_puck = math.sqrt((self.x - puck.x)**2 + (self.y - puck.y)**2)
        if distance_to_puck < STRIKE_DISTANCE + self.radius:
            goal_center_x, goal_center_y = target_goal
            angle = math.atan2(goal_center_y - self.y, goal_center_x - self.x)
            dx = PUCK_SPEED * math.cos(angle)
            dy = PUCK_SPEED * math.sin(angle)
            self.strike(puck, dx, dy)

class Goalkeeper(Player):
    def __init__(self, x, y, is_user_goalie=False):
        super().__init__(x, y, BLUE if is_user_goalie else RED, PLAYER_SPEED * 0.7, 0)
        self.width = GOALKEEPER_WIDTH
        self.height = GOALKEEPER_HEIGHT
        self.is_user_goalie = is_user_goalie
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)

    def update(self, puck):
        # Track puck's Y position
        if self.rect.centery < puck.y:
            self.y += self.speed
        elif self.rect.centery > puck.y:
            self.y -= self.speed

        # Keep within goal area vertically
        goal_y_start = (SCREEN_HEIGHT - GOAL_HEIGHT) // 2
        goal_y_end = goal_y_start + GOAL_HEIGHT
        self.y = max(goal_y_start, min(self.y, goal_y_end - self.height))
        self.rect.y = self.y

    def draw(self, screen):
        pygame.draw.rect(screen, self.color, self.rect)

    def check_block(self, puck):
        puck_rect = pygame.Rect(puck.x - puck.radius, puck.y - puck.radius, puck.radius * 2, puck.radius * 2)
        if self.rect.colliderect(puck_rect):
            puck.dx *= -1.1 # Bounce away with a little extra speed
            # Add some vertical spin based on where it hits the paddle
            puck.dy = (puck.y - self.rect.centery) / (self.height / 2) * PUCK_SPEED 
            return True
        return False
