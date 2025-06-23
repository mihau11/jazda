from random import randrange
class tiktoe:
    board=[[0,0,0],[0,0,0],[0,0,0]]
    winner=""
    moves={"player":[],"bot":[]}
    def isWin(self):
        for line in self.board:
            if line[0]==line[1] and line[1]==line[2] and line[2]!=0: return line[0]
        for i in range(len(self.board)):
            if self.board[0][i]==self.board[1][i] and self.board[1][i]==self.board[2][i] and self.board[2][i]!=0: return self.board[0][i]
        if self.board[0][0]==self.board[1][1] and self.board[2][2]==self.board[1][1] and self.board[1][1]!=0: return self.board[1][1]
        if self.board[2][0]==self.board[1][1] and self.board[0][2]==self.board[1][1] and self.board[1][1]!=0: return self.board[1][1]
        return 0
    
    def druk(self):
        for line in self.board:
            print(line)
            
    def ruch(self, gracz,x,y):
        if self.board[y][x]==0: return -1
        self.board[y][x]=gracz
        return gracz
    
    def bot(self):
        if len(self.moves["player"])==0:
            if len(self.moves["bot"])==0 :self.board[1][1]=8
            else: return 0
        else:
            if (self.moves["player"][0][0]+self.moves["player"][0][1])%2==0:return 11 #remis # debilu jednak nie
        return 0
    
    def mecz(self):
        if randrange(4)!=3: self.bot()
gra1 = tiktoe()
gra1.board=[[2,0,0],[1,2,1],[1,1,2]]
print(gra1)