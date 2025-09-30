import pygame
import heapq
from collections import deque

# --- Setup ---
pygame.init()
WIDTH = 800
INFO_HEIGHT = 50
ROWS = 50
WIN = pygame.display.set_mode((WIDTH, WIDTH + INFO_HEIGHT))
pygame.display.set_caption("Pathfinding Algorithm Visualizer")

# --- Colors ---
RED = (255, 0, 0)
GREEN = (0, 255, 0)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
PURPLE = (128, 0, 128)
ORANGE = (255, 165, 0)
GREY = (128, 128, 128)
TURQUOISE = (64, 224, 208)

# --- Node/Spot Class ---
class Spot:
    def __init__(self, row, col, width, total_rows):
        self.row = row
        self.col = col
        self.x = row * width
        self.y = col * width
        self.color = WHITE
        self.neighbors = []
        self.width = width
        self.total_rows = total_rows

    def get_pos(self):
        return self.row, self.col

    def is_barrier(self):
        return self.color == BLACK

    def is_start(self):
        return self.color == ORANGE

    def is_end(self):
        return self.color == TURQUOISE

    def reset(self):
        self.color = WHITE

    def make_start(self):
        self.color = ORANGE

    def make_closed(self):
        self.color = RED

    def make_open(self):
        self.color = GREEN

    def make_barrier(self):
        self.color = BLACK

    def make_end(self):
        self.color = TURQUOISE

    def make_path(self):
        self.color = PURPLE

    def draw(self, win):
        pygame.draw.rect(win, self.color, (self.x, self.y, self.width, self.width))

    def update_neighbors(self, grid):
        self.neighbors = []
        if self.row < self.total_rows - 1 and not grid[self.row + 1][self.col].is_barrier(): # DOWN
            self.neighbors.append(grid[self.row + 1][self.col])
        if self.row > 0 and not grid[self.row - 1][self.col].is_barrier(): # UP
            self.neighbors.append(grid[self.row - 1][self.col])
        if self.col < self.total_rows - 1 and not grid[self.row][self.col + 1].is_barrier(): # RIGHT
            self.neighbors.append(grid[self.row][self.col + 1])
        if self.col > 0 and not grid[self.row][self.col - 1].is_barrier(): # LEFT
            self.neighbors.append(grid[self.row][self.col - 1])

    def __lt__(self, other):
        return False

# --- Path Reconstruction ---
def reconstruct_path(came_from, current, draw):
    while current in came_from:
        current = came_from[current]
        if current in came_from:
            current.make_path()
        draw()

# --- ALGORITHMS ---

# 1. A* Search Algorithm
def h(p1, p2):
    x1, y1 = p1
    x2, y2 = p2
    return abs(x1 - x2) + abs(y1 - y2)

def a_star_algorithm(draw, grid, start, end):
    count = 0
    open_set = [(0, count, start)]
    came_from = {}
    g_score = {spot: float("inf") for row in grid for spot in row}
    g_score[start] = 0
    f_score = {spot: float("inf") for row in grid for spot in row}
    f_score[start] = h(start.get_pos(), end.get_pos())
    open_set_hash = {start}

    while open_set:
        for event in pygame.event.get():
            if event.type == pygame.QUIT: pygame.quit()
        current = heapq.heappop(open_set)[2]
        open_set_hash.remove(current)

        if current == end:
            reconstruct_path(came_from, end, draw)
            end.make_end(); start.make_start()
            return True

        for neighbor in current.neighbors:
            temp_g_score = g_score[current] + 1
            if temp_g_score < g_score[neighbor]:
                came_from[neighbor] = current
                g_score[neighbor] = temp_g_score
                f_score[neighbor] = temp_g_score + h(neighbor.get_pos(), end.get_pos())
                if neighbor not in open_set_hash:
                    count += 1
                    heapq.heappush(open_set, (f_score[neighbor], count, neighbor))
                    open_set_hash.add(neighbor)
                    neighbor.make_open()
        draw()
        if current != start:
            current.make_closed()
    return False

# 2. Breadth-First Search (BFS) Algorithm
def bfs_algorithm(draw, grid, start, end):
    queue = deque([start])
    came_from = {}
    visited = {start}

    while queue:
        for event in pygame.event.get():
            if event.type == pygame.QUIT: pygame.quit()
        current = queue.popleft()

        if current == end:
            reconstruct_path(came_from, end, draw)
            end.make_end(); start.make_start()
            return True

        for neighbor in current.neighbors:
            if neighbor not in visited:
                visited.add(neighbor)
                came_from[neighbor] = current
                queue.append(neighbor)
                neighbor.make_open()
        draw()
        if current != start:
            current.make_closed()
    return False

# 3. Depth-First Search (DFS) Algorithm
def dfs_algorithm(draw, grid, start, end):
    stack = [start]
    came_from = {}
    visited = {start}

    while stack:
        for event in pygame.event.get():
            if event.type == pygame.QUIT: pygame.quit()
        current = stack.pop()

        if current == end:
            reconstruct_path(came_from, end, draw)
            end.make_end(); start.make_start()
            return True

        for neighbor in reversed(current.neighbors):
            if neighbor not in visited:
                visited.add(neighbor)
                came_from[neighbor] = current
                stack.append(neighbor)
                neighbor.make_open()
        draw()
        if current != start:
            current.make_closed()
    return False

# 4. Dijkstra's Algorithm
def dijkstra_algorithm(draw, grid, start, end):
    count = 0
    open_set = [(0, count, start)]
    came_from = {}
    g_score = {spot: float("inf") for row in grid for spot in row}
    g_score[start] = 0
    open_set_hash = {start}

    while open_set:
        for event in pygame.event.get():
            if event.type == pygame.QUIT: pygame.quit()
        current = heapq.heappop(open_set)[2]
        open_set_hash.remove(current)

        if current == end:
            reconstruct_path(came_from, end, draw)
            end.make_end(); start.make_start()
            return True

        for neighbor in current.neighbors:
            temp_g_score = g_score[current] + 1
            if temp_g_score < g_score[neighbor]:
                came_from[neighbor] = current
                g_score[neighbor] = temp_g_score
                if neighbor not in open_set_hash:
                    count += 1
                    heapq.heappush(open_set, (g_score[neighbor], count, neighbor))
                    open_set_hash.add(neighbor)
                    neighbor.make_open()
        draw()
        if current != start:
            current.make_closed()
    return False

# --- Grid and Drawing Functions ---
def make_grid(rows, width):
    grid = []
    gap = width // rows
    for i in range(rows):
        grid.append([])
        for j in range(rows):
            spot = Spot(i, j, gap, rows)
            grid[i].append(spot)
    return grid

def draw_grid_lines(win, rows, width):
    gap = width // rows
    for i in range(rows + 1):
        pygame.draw.line(win, GREY, (0, i * gap), (width, i * gap))
        pygame.draw.line(win, GREY, (i * gap, 0), (i * gap, width))

def draw(win, grid, rows, width):
    win.fill(WHITE)
    for row in grid:
        for spot in row:
            spot.draw(win)
    draw_grid_lines(win, rows, width)
    
    # Draw info panel
    pygame.draw.rect(win, GREY, (0, WIDTH, width, INFO_HEIGHT))
    font = pygame.font.SysFont('segoeui', 16)
    text1 = font.render("1: A* | 2: BFS | 3: DFS | 4: Dijkstra", 1, BLACK)
    text2 = font.render("LEFT-Click: Draw | RIGHT-Click: Erase | C: Clear", 1, BLACK)
    win.blit(text1, (10, WIDTH + 5))
    win.blit(text2, (10, WIDTH + 25))
    
    pygame.display.update()

def get_clicked_pos(pos, rows, width):
    gap = width // rows
    y, x = pos
    row = y // gap
    col = x // gap
    return row, col

def clear_path_visualization(grid):
    for row in grid:
        for spot in row:
            if spot.color in (GREEN, RED, PURPLE):
                spot.reset()

# --- Main Loop ---
def main(win, width):
    grid = make_grid(ROWS, width)
    start, end = None, None
    run = True

    while run:
        draw(win, grid, ROWS, width)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                run = False

            if pygame.mouse.get_pos()[1] >= WIDTH:
                continue

            if pygame.mouse.get_pressed()[0]: # LEFT mouse
                pos = pygame.mouse.get_pos()
                row, col = get_clicked_pos(pos, ROWS, width)
                spot = grid[row][col]
                if not start and spot != end:
                    start = spot; start.make_start()
                elif not end and spot != start:
                    end = spot; end.make_end()
                elif spot != end and spot != start:
                    spot.make_barrier()

            elif pygame.mouse.get_pressed()[2]: # RIGHT mouse
                pos = pygame.mouse.get_pos()
                row, col = get_clicked_pos(pos, ROWS, width)
                spot = grid[row][col]
                spot.reset()
                if spot == start: start = None
                elif spot == end: end = None

            if event.type == pygame.KEYDOWN:
                if event.key in (pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4) and start and end:
                    clear_path_visualization(grid)
                    for row in grid:
                        for spot in row:
                            spot.update_neighbors(grid)
                    
                    draw_func = lambda: draw(win, grid, ROWS, width)
                    
                    if event.key == pygame.K_1: a_star_algorithm(draw_func, grid, start, end)
                    elif event.key == pygame.K_2: bfs_algorithm(draw_func, grid, start, end)
                    elif event.key == pygame.K_3: dfs_algorithm(draw_func, grid, start, end)
                    elif event.key == pygame.K_4: dijkstra_algorithm(draw_func, grid, start, end)

                if event.key == pygame.K_c:
                    start, end = None, None
                    grid = make_grid(ROWS, width)

    pygame.quit()

if __name__ == "__main__":
    main(WIN, WIDTH)