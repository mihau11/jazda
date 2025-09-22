import pygame

# Screen dimensions
SCREEN_WIDTH = 1200
SCREEN_HEIGHT = 800

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 0, 255)
DARK_GRAY = (64, 64, 64)
ORANGE = (255, 165, 0)

# Game settings
GOAL_HEIGHT = SCREEN_HEIGHT * 0.3
PUCK_SPEED = 10
PLAYER_SPEED = PUCK_SPEED * 0.8
PLAYER_BOOST_SPEED = PLAYER_SPEED * 2
PUCK_RADIUS = 10
PLAYER_RADIUS = 20
GOALKEEPER_WIDTH = 25
GOALKEEPER_HEIGHT = 50
STRIKE_COOLDOWN = 0.5  # in seconds
STRIKE_DISTANCE = 30
PUCK_FRICTION = 0.99  # Friction factor (0.99 means 1% speed loss per frame)
STRIKE_SPEED_VARIATION = 0.2  # 20% speed variation when striking

# Positional Play Zones
# (x, y, width, height)
ZONES = {
    'user': {
        'left_attack': (SCREEN_WIDTH / 2, 0, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        'right_attack': (SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        'left_defense': (0, 0, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        'right_defense': (0, SCREEN_HEIGHT / 2, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
    },
    'ai': {
        'left_attack': (0, 0, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        'right_attack': (0, SCREEN_HEIGHT / 2, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        'left_defense': (SCREEN_WIDTH / 2, 0, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
        'right_defense': (SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2),
    }
}

# Settings ranges for customization
PUCK_SPEED_RANGE = (5, 20)
PUCK_RADIUS_RANGE = (5, 20)
PLAYER_RADIUS_RANGE = (10, 40)
GOALKEEPER_HEIGHT_RANGE = (30, 100)
USER_SPEED_RANGE = (3, 15)
AI_SPEED_RANGE = (2, 12)
