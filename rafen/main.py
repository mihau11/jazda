from time import sleep
BOARD_SIZE=7
class Point:
    def __init__(self,row,col):
        self.row=row
        self.col=col
    def __str__(self):
        return f"Row: {self.row} Column: {self.col}"

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
        board[p.position.row][p.position.col]=p
    return board
class Soldat:
    def __init__(self,ksywa:str,place:Point):
        self.ruchy=5
        self.mendy=[]
        self.ksywa=ksywa
        self.position=place
    def __str__(self):
        return self.ksywa[0]
    def rozkazy(self):
        print(self.ksywa+":")
        command=input()
        self.mendy=[]
        while self.ruchy>0 and command!="q":
            if command in ["w","s","a","d"]:
                self.mendy.append(command)
            command=input()
            self.ruchy-=1

def Game():
    duoling=[Soldat("Ivan",Point(0,BOARD_SIZE-1)), Soldat("Hans",Point(BOARD_SIZE-1,0))]
    board=makeTable(duoling)
    showTable(board)
    for s in duoling:
        s.rozkazy()
    for i in range(max([len(s.mendy) for s in duoling])):
        for s in duoling:
            if len(s.mendy):
                new=s.position
                r=s.mendy[0]
                if r=="w":   new=Point(s.position.row-1,s.position.col)
                elif r=="s": new=Point(s.position.row+1,s.position.col)
                elif r=="a": new=Point(s.position.row,s.position.col-1)
                elif r=="d":new=Point(s.position.row,s.position.col+1)
                if new.row in range(0,BOARD_SIZE) and new.col in range(0,BOARD_SIZE):
                    s.position=new
                s.mendy.pop(0)
        board=makeTable(duoling)
        showTable(board)
        sleep(1)
Game()