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
    
    def wybierz(self):
        self.check()
        print(f"Twoje karty: {sorted(self.reka)} Suma: {self.suma()}")
        dozagrania=-1
        while not dozagrania in self.reka:
            dozagrania=int(input("Karta:"))
        self.karta=dozagrania
        self.reka.remove(dozagrania)
        
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
        
    A.kartA(B.karta) ##################################Zmień jeśli chcesz ;)
    #A.losuj()
    #A.wybierz()
    B.losuj()
    print(f"Bot: {B.karta}")
    stawka+=[A.karta,B.karta]
    
    if A.karta==B.karta: 
        print("Wojna")
        return wojna(A,B,stawka)
    elif A.karta>B.karta:
        print("Wygrana")
        A.odrzucone+=stawka
    elif B.karta>A.karta:
        print("Przegrana")
        B.odrzucone+=stawka
    return [A,B]

def mecz(n,p):
    A,B=Gracz(),Gracz()
    
    talia=[x for y in range(2*p) for x in range(n)]
    shuffle(talia)
    A.reka=talia[0:p*n]
    B.reka=talia[p*n:2*p*n]
    bl=-1000000
    licznik=0
    while len(A.reka)>0 and len(B.reka)>0:
        A.kartA(bl) ####################################Zmień jeśli chcesz
        #A.losuj()
        #A.wybierz()
        B.losuj()
        print(f"Bot: {B.karta}")
        if A.karta>B.karta:
            print("Wygrana")
            A.odrzucone+=[A.karta,B.karta]
            bl=B.karta
        elif B.karta>A.karta:
            print("Przegrana")
            B.odrzucone+=[A.karta,B.karta]
            bl=B.karta
        else:
            print("Wojna")
            A,B=wojna(A,B,[A.karta,B.karta])
            bl=B.karta
            if A.suma()==0 or B.suma()==0:
                return [A.suma(),B.suma(),licznik]
        licznik+=1
        A.check()
        B.check()
    return [A.suma(),B.suma(),licznik]


print(mecz(5,1))