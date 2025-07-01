from waven import Point, Hero
BOARD_SIZE=7
STARTING_POINTS=[Point(0,0),Point(BOARD_SIZE-1,BOARD_SIZE-1),Point(0,BOARD_SIZE-1),Point(BOARD_SIZE-1,0)]
NAMES=["Rafal","Gabrys"]

def showTable(board:list):
    roof="  "
    for i in range(BOARD_SIZE):
        roof+=f" {i}  "
    print(roof)
    line="  "
    for i in range(BOARD_SIZE):
        line+="----"
    print(line)
    for i in range(BOARD_SIZE):
        place=f"{i}|"
        for col in board[i]:
            place+=" "+str(col)+" |"
        print(place)
        print(line)
def makeTable(players:list):
    board=[[" " for _ in range(BOARD_SIZE)] for _ in range(BOARD_SIZE)]    
    for p in players:
        print(p)
        board[p.position.row][p.position.col]=p
    return board

def Game():
    players=[Hero(NAMES[i],STARTING_POINTS[i]) for i in range(len(NAMES))]
    
        
    while len(players)>1:
        for player in players:
            board=makeTable(players)
            player.move=3
            showTable(board)
            print(player.hello())
            while player.move>0:
                command = input("Chooose your action:\n(move/atack)")
                if command == "move":
                    target=Point(int(input("Insert row:")),int(input("Insert column:")))
                    if target.row >BOARD_SIZE-1 or target.row<0 or target.col>BOARD_SIZE-1 or target.col<0:
                        print("Invalid arguments.")
                    elif board[target.row][target.col]!=" ":
                        print("This field is already occupied.")
                    else:
                        print(player.moveTo(target))
                elif command == "attack":
                    attack=int(input(f"Choose index of your attack:\n(1: {player.power1.__name__[2:]})"))-1
                    pool=[player.power1]
                    if attack<len(pool) and attack>-1:
                        target=Point(int(input("Insert row:")),int(input("Insert column:")))
                        if target.row >BOARD_SIZE-1 or target.row<0 or target.col>BOARD_SIZE-1 or target.col<0:
                            print("Invalid arguments.")
                        elif board[target.row][target.col]==" ":
                            print("There is nothing.")
                        else:
                            print(pool[attack](board[target.row][target.col]))
                    else:
                        print("Invalid index.")
                
Game()