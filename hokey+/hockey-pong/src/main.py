import pygame
from config import *
from classes import Puck, UserPlayer, AIPlayer, Goalkeeper
import math
import random

def show_menu(screen):
    big_font = pygame.font.Font(None, 200)
    small_font = pygame.font.Font(None, 35)
    
    descriptions = {
        1: "Goalkeepers and User Player",
        2: "User vs 1 AI Player",
        3: "User + 1 AI vs 2 AI Players",
        4: "User + 2 AI vs 3 AI Players"
    }

    selected_option = 1
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_LEFT:
                    selected_option = max(1, selected_option - 1)
                elif event.key == pygame.K_RIGHT:
                    selected_option = min(4, selected_option + 1)
                elif event.key == pygame.K_RETURN:
                    return selected_option

        screen.fill(DARK_GRAY)
        
        # Display big digit
        digit_text = big_font.render(str(selected_option), True, ORANGE)
        screen.blit(digit_text, (SCREEN_WIDTH // 2 - digit_text.get_width() // 2, SCREEN_HEIGHT // 3))

        # Display description
        desc_text = small_font.render(descriptions[selected_option], True, ORANGE)
        screen.blit(desc_text, (SCREEN_WIDTH // 2 - desc_text.get_width() // 2, SCREEN_HEIGHT * 2/3))
        
        pygame.display.flip()

def show_pause_screen(screen):
    font = pygame.font.Font(None, 100)
    small_font = pygame.font.Font(None, 50)
    
    pause_text = font.render("PAUSED", True, ORANGE)
    menu_text = small_font.render("Press M to return to Menu", True, ORANGE)
    
    # Create a semi-transparent overlay
    overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
    overlay.fill((64, 64, 64, 150)) # Dark gray with alpha
    screen.blit(overlay, (0, 0))

    screen.blit(pause_text, (SCREEN_WIDTH // 2 - pause_text.get_width() // 2, SCREEN_HEIGHT // 3))
    screen.blit(menu_text, (SCREEN_WIDTH // 2 - menu_text.get_width() // 2, SCREEN_HEIGHT * 2/3))

def game_loop(screen, player_config):
    clock = pygame.time.Clock()

    puck = Puck(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)
    user_player = UserPlayer(SCREEN_WIDTH // 4, SCREEN_HEIGHT // 2)
    
    user_goalie = Goalkeeper(10, SCREEN_HEIGHT // 2 - GOALKEEPER_HEIGHT // 2, is_user_goalie=True)
    ai_goalie = Goalkeeper(SCREEN_WIDTH - GOALKEEPER_WIDTH - 10, SCREEN_HEIGHT // 2 - GOALKEEPER_HEIGHT // 2)

    ai_players = []
    user_team = []

    if player_config == 2:
        ai_players.append(AIPlayer(SCREEN_WIDTH * 3/4, SCREEN_HEIGHT / 2, team='ai', can_cross_center=True))
    elif player_config == 3:
        user_team.append(AIPlayer(SCREEN_WIDTH / 4 + 50, SCREEN_HEIGHT / 2 + 50, team='user'))
        ai_players.append(AIPlayer(SCREEN_WIDTH * 3/4, SCREEN_HEIGHT / 3, team='ai', can_cross_center=True))
        ai_players.append(AIPlayer(SCREEN_WIDTH * 3/4, SCREEN_HEIGHT * 2/3, team='ai'))
    elif player_config == 4:
        user_team.append(AIPlayer(SCREEN_WIDTH / 4 + 50, SCREEN_HEIGHT / 3, team='user'))
        user_team.append(AIPlayer(SCREEN_WIDTH / 4 + 50, SCREEN_HEIGHT * 2/3, team='user'))
        ai_players.append(AIPlayer(SCREEN_WIDTH * 3/4, SCREEN_HEIGHT / 2, team='ai', can_cross_center=True))
        ai_players.append(AIPlayer(SCREEN_WIDTH * 3/4, SCREEN_HEIGHT / 4, team='ai'))
        ai_players.append(AIPlayer(SCREEN_WIDTH * 3/4, SCREEN_HEIGHT * 3/4, team='ai'))


    score_left = 0
    score_right = 0
    font = pygame.font.Font(None, 74)

    paused = False
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return 'QUIT'
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_p:
                    paused = not paused
                if event.key == pygame.K_m and paused:
                    return 'MENU'

        if paused:
            show_pause_screen(screen)
        else:
            keys = pygame.key.get_pressed()
            opponent_goal_pos = (SCREEN_WIDTH, SCREEN_HEIGHT // 2)
            user_goal_pos = (0, SCREEN_HEIGHT // 2)
            user_player.handle_input(keys, puck, opponent_goal_pos)
            user_player.update()

            puck.move()
            puck.bounce()

            user_goalie.update(puck)
            ai_goalie.update(puck)
            user_goalie.check_block(puck)
            ai_goalie.check_block(puck)

            for player in ai_players:
                player.update(puck, user_goal_pos)
            for player in user_team:
                player.update(puck, opponent_goal_pos) # Teammates aim for opponent goal

            # --- Player Collision Resolution ---
            all_players = [user_player] + user_team + ai_players
            for i, player1 in enumerate(all_players):
                for player2 in all_players[i+1:]:
                    dx = player1.x - player2.x
                    dy = player1.y - player2.y
                    distance = math.sqrt(dx**2 + dy**2)
                    min_dist = player1.radius + player2.radius

                    if distance < min_dist:
                        # Collision detected, calculate overlap
                        overlap = min_dist - distance
                        
                        # Avoid division by zero if players are at the exact same position
                        if distance == 0:
                            angle = random.uniform(0, 2 * math.pi)
                        else:
                            angle = math.atan2(dy, dx)
                        
                        # Move players apart
                        move_x = math.cos(angle) * overlap / 2
                        move_y = math.sin(angle) * overlap / 2
                        
                        player1.x += move_x
                        player1.y += move_y
                        player2.x -= move_x
                        player2.y -= move_y

            # Goal scoring
            goal_y_start = (SCREEN_HEIGHT - GOAL_HEIGHT) // 2
            goal_y_end = goal_y_start + GOAL_HEIGHT
            if puck.x - puck.radius <= 5 and goal_y_start < puck.y < goal_y_end:
                score_right += 1
                puck.reset()
            elif puck.x + puck.radius >= SCREEN_WIDTH - 5 and goal_y_start < puck.y < goal_y_end:
                score_left += 1
                puck.reset()

            screen.fill(WHITE)
            
            # Draw center line
            pygame.draw.line(screen, RED, (SCREEN_WIDTH // 2, 0), (SCREEN_WIDTH // 2, SCREEN_HEIGHT), 5)
            
            # Draw goals
            goal_y = (SCREEN_HEIGHT - GOAL_HEIGHT) // 2
            pygame.draw.rect(screen, RED, (0, goal_y, 5, GOAL_HEIGHT))
            pygame.draw.rect(screen, RED, (SCREEN_WIDTH - 5, goal_y, 5, GOAL_HEIGHT))

            puck.draw(screen)
            user_player.draw(screen)
            user_goalie.draw(screen)
            ai_goalie.draw(screen)
            for player in ai_players:
                player.draw(screen)
            for player in user_team:
                player.draw(screen)

            # Display score
            score_text = f"{score_left} - {score_right}"
            text = font.render(score_text, True, BLACK)
            screen.blit(text, (SCREEN_WIDTH // 2 - text.get_width() // 2, 10))

        pygame.display.flip()
        clock.tick(60)

def main():
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Hockey Pong")

    while True:
        player_config = show_menu(screen)
        result = game_loop(screen, player_config)
        if result == 'QUIT':
            break
    
    pygame.quit()

if __name__ == '__main__':
    main()
