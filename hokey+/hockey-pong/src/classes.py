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
        
        # Apply friction to slow down the puck over time
        self.dx *= PUCK_FRICTION
        self.dy *= PUCK_FRICTION

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
                # Add random speed variation to strikes
                speed_multiplier = 1.0 + random.uniform(-STRIKE_SPEED_VARIATION, STRIKE_SPEED_VARIATION)
                puck.dx = dx * speed_multiplier
                puck.dy = dy * speed_multiplier
                self.last_strike_time = time.time()
                return True
        return False

    def draw(self, screen):
        pygame.draw.circle(screen, self.color, (int(self.x), int(self.y)), self.radius)

class UserPlayer(Player):
    def __init__(self, x, y, zone=None):
        super().__init__(x, y, BLUE, PLAYER_SPEED, PLAYER_RADIUS)
        self.boost_active = False
        self.current_speed = self.speed
        self.zone = zone

    def return_to_zone(self):
        if not self.zone:
            return True # No zone assigned, can't return
        zone_x, zone_y, zone_w, zone_h = self.zone
        target_x = zone_x + zone_w / 2
        target_y = zone_y + zone_h / 2

        dx = target_x - self.x
        dy = target_y - self.y
        dist = math.sqrt(dx**2 + dy**2)

        if dist < 5: # Close enough
            self.x = target_x
            self.y = target_y
            return True

        # Move slowly
        self.x += (dx / dist) * 2
        self.y += (dy / dist) * 2
        return False

    def handle_input(self, keys, puck, opponent_goal):
        self.current_speed = self.speed
        boost_active = keys[pygame.K_SPACE]
        if boost_active:
            self.current_speed = self.speed * 2

        if keys[pygame.K_w]:
            self.y -= self.current_speed
        if keys[pygame.K_s]:
            self.y += self.current_speed
        if keys[pygame.K_a]:
            self.x -= self.current_speed
        if keys[pygame.K_d]:
            self.x += self.current_speed
        
        # Strike logic with boost consideration
        strike_multiplier = 2.0 if boost_active else 1.0
        
        # New shooting controls
        if keys[pygame.K_i]: # Up
            self.strike(puck, 0, -PUCK_SPEED * strike_multiplier)
        if keys[pygame.K_COMMA]: # Down
            self.strike(puck, 0, PUCK_SPEED * strike_multiplier)
        if keys[pygame.K_j]: # Left
            self.strike(puck, -PUCK_SPEED * strike_multiplier, 0)
        if keys[pygame.K_l]: # Right
            self.strike(puck, PUCK_SPEED * strike_multiplier, 0)
        
        # Diagonal shots
        diag_speed = PUCK_SPEED * strike_multiplier / math.sqrt(2)
        if keys[pygame.K_o]: # Up-Right
            self.strike(puck, diag_speed, -diag_speed)
        if keys[pygame.K_u]: # Up-Left
            self.strike(puck, -diag_speed, -diag_speed)
        if keys[pygame.K_m]: # Down-Left
            self.strike(puck, -diag_speed, diag_speed)
        if keys[pygame.K_PERIOD]: # Down-Right
            self.strike(puck, diag_speed, diag_speed)

        # Shot at goal
        if keys[pygame.K_k]:
            goal_center_x, goal_center_y = opponent_goal
            random_y = random.uniform((SCREEN_HEIGHT - GOAL_HEIGHT) // 2, (SCREEN_HEIGHT + GOAL_HEIGHT) // 2)
            angle = math.atan2(random_y - self.y, goal_center_x - self.x)
            dx = PUCK_SPEED * math.cos(angle) * strike_multiplier
            dy = PUCK_SPEED * math.sin(angle) * strike_multiplier
            self.strike(puck, dx, dy)

    def update(self):
        # Keep player within screen bounds
        self.x = max(self.radius, min(self.x, SCREEN_WIDTH - self.radius))
        self.y = max(self.radius, min(self.y, SCREEN_HEIGHT - self.radius))

class AIPlayer(Player):
    def __init__(self, x, y, team='ai', position=None):
        self.team = team
        self.position = position
        self.zone = ZONES[team][position]
        color = BLUE if self.team == 'user' else RED
        super().__init__(x, y, color, PLAYER_SPEED * 0.8, PLAYER_RADIUS)

    def update(self, puck, target_goal, teammates):
        # Determine the target position
        target_x, target_y = self.get_target_position(puck, teammates)

        # Move towards the target position
        if self.x < target_x:
            self.x += self.speed
        elif self.x > target_x:
            self.x -= self.speed
            
        if self.y < target_y:
            self.y += self.speed
        elif self.y > target_y:
            self.y -= self.speed

        # Keep within screen bounds
        self.x = max(self.radius, min(self.x, SCREEN_WIDTH - self.radius))
        self.y = max(self.radius, min(self.y, SCREEN_HEIGHT - self.radius))

        # AI striking logic
        self.handle_striking(puck, target_goal, teammates)

    def return_to_zone(self):
        zone_x, zone_y, zone_w, zone_h = self.zone
        target_x = zone_x + zone_w / 2
        target_y = zone_y + zone_h / 2

        # Move towards the zone center
        dx = target_x - self.x
        dy = target_y - self.y
        dist = math.sqrt(dx**2 + dy**2)

        if dist > self.speed:
            self.x += (dx / dist) * self.speed
            self.y += (dy / dist) * self.speed
        else:
            self.x = target_x
            self.y = target_y
        
        return dist < 2 # Return True if close enough to target

    def handle_striking(self, puck, target_goal, teammates):
        my_distance_to_puck = math.sqrt((self.x - puck.x)**2 + (self.y - puck.y)**2)
        
        # Check if I am the closest teammate to the puck
        is_closest = all(
            my_distance_to_puck <= math.sqrt((teammate.x - puck.x)**2 + (teammate.y - puck.y)**2)
            for teammate in teammates if teammate != self
        )

        if is_closest and my_distance_to_puck < STRIKE_DISTANCE + self.radius:
            # Find the teammate closest to the enemy goal
            closest_to_goal = None
            min_goal_dist = float('inf')
            for teammate in teammates:
                if teammate != self:
                    dist = math.sqrt((teammate.x - target_goal[0])**2 + (teammate.y - target_goal[1])**2)
                    if dist < min_goal_dist:
                        min_goal_dist = dist
                        closest_to_goal = teammate
            
            my_goal_dist = math.sqrt((self.x - target_goal[0])**2 + (self.y - target_goal[1])**2)

            if closest_to_goal and my_goal_dist > min_goal_dist:
                # Pass to the teammate closest to the goal
                angle = math.atan2(closest_to_goal.y - self.y, closest_to_goal.x - self.x)
                dx = PUCK_SPEED * 2 * math.cos(angle)
                dy = PUCK_SPEED * 2 * math.sin(angle)
                self.strike(puck, dx, dy)
            else:
                # Strike at the goal
                angle = math.atan2(target_goal[1] - self.y, target_goal[0] - self.x)
                dx = PUCK_SPEED * math.cos(angle)
                dy = PUCK_SPEED * math.sin(angle)
                self.strike(puck, dx, dy)

    def get_target_position(self, puck, teammates):
        # Check if a teammate is close to the puck
        teammate_near_puck = any(
            math.sqrt((teammate.x - puck.x)**2 + (teammate.y - puck.y)**2) <= STRIKE_DISTANCE + teammate.radius
            for teammate in teammates if teammate != self
        )

        zone_x, zone_y, zone_w, zone_h = self.zone
        zone_center_x = zone_x + zone_w / 2
        zone_center_y = zone_y + zone_h / 2

        # If puck is far or a teammate has it, stay in zone
        puck_in_zone = zone_x < puck.x < zone_x + zone_w and zone_y < puck.y < zone_y + zone_h
        if teammate_near_puck or not puck_in_zone:
            return zone_center_x, zone_center_y
        else:
            # If puck is in zone and no one has it, go for it
            return puck.x, puck.y

class Goalkeeper(Player):
    def __init__(self, x, y, is_user_goalie=False):
        super().__init__(x, y, BLUE if is_user_goalie else RED, PLAYER_SPEED * 0.7, 0)
        self.width = GOALKEEPER_WIDTH
        self.height = GOALKEEPER_HEIGHT
        self.is_user_goalie = is_user_goalie
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)

    def update(self, puck):
        # Predict where the puck will be when it reaches the goal line
        if abs(puck.dx) > 0.1:  # Only predict if puck is moving horizontally
            time_to_goal = abs(self.rect.centerx - puck.x) / abs(puck.dx)
            predicted_y = puck.y + puck.dy * time_to_goal
        else:
            predicted_y = puck.y
        
        # Move towards the predicted position
        if self.rect.centery < predicted_y:
            self.y += self.speed
        elif self.rect.centery > predicted_y:
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
            # Determine which wall is closer
            distance_to_top = puck.y
            distance_to_bottom = SCREEN_HEIGHT - puck.y
            closer_to_top = distance_to_top < distance_to_bottom
            
            # Calculate strike direction at 30 degrees toward closer wall
            if self.is_user_goalie:
                # User goalie strikes toward right side of field
                base_angle = 0  # Right direction
            else:
                # AI goalie strikes toward left side of field
                base_angle = math.pi  # Left direction
            
            # Add 30 degree angle toward closer wall
            angle_offset = math.radians(30) if closer_to_top else math.radians(-30)
            strike_angle = base_angle + angle_offset
            
            # Add random speed variation to goalkeeper strikes
            speed_multiplier = 1.0 + random.uniform(-STRIKE_SPEED_VARIATION, STRIKE_SPEED_VARIATION)
            strike_speed = PUCK_SPEED * 1.2 * speed_multiplier  # Slightly faster than normal strikes
            
            puck.dx = math.cos(strike_angle) * strike_speed
            puck.dy = math.sin(strike_angle) * strike_speed
            return True
        return False
