from random import choice, shuffle

class Gracz():
    def __init__(self):
        self.reka = []
        self.odrzucone = []
        self.karta = -1
    
    def suma(self):
        return len(self.reka)+len(self.odrzucone)
    
    def losuj(self):
        self.check()
        self.karta = choice(self.reka)
        self.reka.remove(self.karta)
        
    def kartA(self, bl: int):
        self.check()
        opcje = sorted([k for k in self.reka if k < bl], reverse=True)
        self.karta = opcje[0] if opcje else max(self.reka)
        self.reka.remove(self.karta)
        
    def check(self):
        if self.reka==[]:
            self.reka=self.odrzucone
            self.odrzucone=[]

def wojna(A:Gracz,B:Gracz,stawka:list):
    zakryte=1 ######################################Zmień jeśli chcesz ;)
    if A.suma()<zakryte+1:
        B.odrzucone+=A.reka+A.odrzucone+stawka
        A.reka,A.odrzucone=[],[]
        return [A,B]
    if B.suma()<zakryte+1:
        A.odrzucone+=B.reka+B.odrzucone+stawka
        B.reka,B.odrzucone=[],[]
        return [A,B]
    
    for i in range(zakryte):
        A.losuj()
        B.losuj()
        stawka+=[A.karta,B.karta]
        
    #A.kartA(B.karta) ##################################Zmień jeśli chcesz ;)
    A.losuj()
    B.losuj()
    stawka+=[A.karta,B.karta]
    
    if A.karta==B.karta: 
        #print("x")
        return wojna(A,B,stawka)
    elif A.karta>B.karta:
        A.odrzucone+=stawka
    elif B.karta>A.karta:
        B.odrzucone+=stawka
    return [A,B]

def mecz(n):
    A,B=Gracz(),Gracz()
    
    talia=[x for y in range(4) for x in range(n)]
    shuffle(talia)
    A.reka=talia[0:2*n]
    B.reka=talia[2*n:4*n]
    # A.reka=[x for x in range(n)]
    # B.reka=[x for x in range(n)]
    bl=-1000000
    licznik=0
    while len(A.reka)>0 and len(B.reka)>0:
        #A.kartA(bl) ####################################Zmień jeśli chcesz
        A.losuj()
        B.losuj()
        if A.karta>B.karta:
            A.odrzucone+=[A.karta,B.karta]
            bl=B.karta
        elif B.karta>A.karta:
            B.odrzucone+=[A.karta,B.karta]
            bl=B.karta
        else:
            #print([A.karta,B.karta])
            A,B=wojna(A,B,[A.karta,B.karta])
            bl=B.karta
            if A.suma()==0 or B.suma()==0:
                return [A.suma(),B.suma(),licznik]
        #print(ak,bk)
        licznik+=1
        A.check()
        B.check()
    return [A.suma(),B.suma(),licznik]

def turniej(n,metoda,l):
    total=[0,0,0,0]
    for i in range(n):
        score=metoda(l)
        if score[0]>score[1]: total[0]+=1
        elif score[1]>score[0]: total[1]+=1
        else: total[2]+=1
        total[3]+=score[2]
    total[3]//=n
    return total
print(turniej(1000000,mecz,20))