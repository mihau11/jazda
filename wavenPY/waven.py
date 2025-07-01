from random import choice,randrange
class Point:
    def __init__(self,row,col):
        self.row=row
        self.col=col
    def __str__(self):
        return f"Row: {self.row} Column: {self.col}"
class Result:
    def __init__(self,suck,mess):
         self.isSuccess = suck
         self.message = mess
    def __str__(self):
        return self.message
class Hero:
    def __init__(self, name, start:Point):
        self.name=name
        self.symbol=name[0]
        self.health=11
        self.move=3
        self.power1=choice([self.__smash,self.__shot])
        self.position=start
    
    def hello(self):
        return f"Name: {self.name}\nHealt: {self.health}\nPower1: {self.power1.__name__[2:]}\nPosition: {self.position}\n"

    def __str__(self):
            return self.symbol
    def __smash(self,foe):
        if measure(self.position,foe.position) > 1:
            return Result(False,"Target is too far.")
        damage=randrange(3)+self.move
        foe.health-=damage
        self.move-=1
        return Result(True,f"You dealt {damage} to {foe.name}")
    
    def __shot(self,foe):
        dist=measure(self.position,foe.position)
        if dist>3:
            return Result(False,"Target is too far.")
        damage=randrange(-3,2)+self.move
        foe.health-=damage
        self.move-=1
        if damage<1:
            return Result(True,"You missed.")
        return Result(True,f"You dealt {damage} to {foe.name}")
    def moveTo(self,dest:Point):
        dist=measure(self.position,dest)
        if dist>self.move:
            return Result(False,"It is too far for you.")
        self.position=dest
        self.move-=dist
        return Result(True,f"Moved {dist} fields.")
    
    def usePower1(self,foe):
        return self.power1(foe)
        
def measure(pos1:Point,pos2:Point):
        a=pos1.row-pos2.row
        b=pos1.col-pos2.col
        return abs(a)+abs(b)