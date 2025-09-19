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
    def __init__(self, x, y):
        super().__init__(x, y, BLUE, PLAYER_SPEED, PLAYER_RADIUS)
        self.boost_active = False
        self.current_speed = self.speed

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
        
        if keys[pygame.K_j]: # Left
            self.strike(puck, -PUCK_SPEED * strike_multiplier, 0)
        if keys[pygame.K_l]: # Right
            self.strike(puck, PUCK_SPEED * strike_multiplier, 0)
        if keys[pygame.K_i]: # Up
            self.strike(puck, 0, -PUCK_SPEED * strike_multiplier)
        if keys[pygame.K_k]: # Down
            self.strike(puck, 0, PUCK_SPEED * strike_multiplier)
        if keys[pygame.K_m]: # Towards opponent goal
            goal_center_x, goal_center_y = opponent_goal
            # Add randomness to the Y target within the goal area
            goal_y_start = (SCREEN_HEIGHT - GOAL_HEIGHT) // 2
            goal_y_end = goal_y_start + GOAL_HEIGHT
            random_y = random.uniform(goal_y_start, goal_y_end)
            angle = math.atan2(random_y - self.y, goal_center_x - self.x)
            dx = PUCK_SPEED * math.cos(angle) * strike_multiplier
            dy = PUCK_SPEED * math.sin(angle) * strike_multiplier
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

    def update(self, puck, target_goal, teammates):
        # Check if any teammate is close to the puck (within striking distance)
        teammate_near_puck = False
        for teammate in teammates:
            if teammate != self:
                distance_to_puck = math.sqrt((teammate.x - puck.x)**2 + (teammate.y - puck.y)**2)
                if distance_to_puck <= STRIKE_DISTANCE + teammate.radius:
                    teammate_near_puck = True
                    break
        
        if teammate_near_puck:
            # Position for a pass - move to a good passing position
            # Move to a position that's closer to the target goal but not too close to the puck
            ideal_x = (puck.x + target_goal[0]) / 2
            ideal_y = (puck.y + target_goal[1]) / 2
            
            # Add some spread to avoid all teammates going to the same spot
            spread_offset = hash(id(self)) % 100 - 50  # Use object id for consistent but different offsets
            ideal_y += spread_offset
            
            if self.x < ideal_x:
                self.x += self.speed
            elif self.x > ideal_x:
                self.x -= self.speed
                
            if self.y < ideal_y:
                self.y += self.speed
            elif self.y > ideal_y:
                self.y -= self.speed
        else:
            # Normal AI movement: follow the puck
            if self.y < puck.y:
                self.y += self.speed
            elif self.y > puck.y:
                self.y -= self.speed
            
            if self.x < puck.x:
                 self.x += self.speed
            elif self.x > puck.x:
                 self.x -= self.speed

        # Keep within screen bounds (no more team-based restrictions)
        self.x = max(self.radius, min(self.x, SCREEN_WIDTH - self.radius))
        self.y = max(self.radius, min(self.y, SCREEN_HEIGHT - self.radius))

        # AI striking - only strike if no teammate is closer to the puck
        my_distance_to_puck = math.sqrt((self.x - puck.x)**2 + (self.y - puck.y)**2)
        should_strike = True
        
        for teammate in teammates:
            if teammate != self:
                teammate_distance = math.sqrt((teammate.x - puck.x)**2 + (teammate.y - puck.y)**2)
                if teammate_distance < my_distance_to_puck:
                    should_strike = False
                    break
        
        if should_strike and my_distance_to_puck < STRIKE_DISTANCE + self.radius:
            # Find the teammate closest to the enemy goal
            closest_to_goal = None
            closest_goal_distance = float('inf')
            
            for teammate in teammates:
                if teammate != self:
                    goal_distance = math.sqrt((teammate.x - target_goal[0])**2 + (teammate.y - target_goal[1])**2)
                    if goal_distance < closest_goal_distance:
                        closest_goal_distance = goal_distance
                        closest_to_goal = teammate
            
            # Check if I am the closest to the goal
            my_goal_distance = math.sqrt((self.x - target_goal[0])**2 + (self.y - target_goal[1])**2)
            
            if closest_to_goal is not None and my_goal_distance > closest_goal_distance:
                # Pass to the teammate closest to the goal (double strength)
                angle = math.atan2(closest_to_goal.y - self.y, closest_to_goal.x - self.x)
                dx = PUCK_SPEED * 2 * math.cos(angle)  # Double strength for passes
                dy = PUCK_SPEED * 2 * math.sin(angle)  # Double strength for passes
                self.strike(puck, dx, dy)
            else:
                # I am closest to goal, so strike at the goal
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
