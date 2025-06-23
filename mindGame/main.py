from random import choice
def obaLosowo(n):
    a=[x for x in range(n)]
    b=[x for x in range(n)]
    score={"a":0, "b":0}
    for i in range(9):
        ax,bx=choice(a),choice(b)
        if ax>bx: score["a"]+=1
        elif bx>ax: score["b"]+=1
        a.remove(ax)
        b.remove(bx)
    return(score)

def jedenLosowo(n):
    a=[x for x in range(n)]
    b=[x for x in range(n)]
    score={"a":0, "b":0}
    for bx in b:
        ax=choice(a)
        if ax>bx: score["a"]+=1
        elif bx>ax: score["b"]+=1
        a.remove(ax)
    return(score)

def turniej(n,metoda,s):
    total={"a":0,"b":0}
    for i in range(n):
        score=metoda(s)
        if score["a"]>score["b"]: total["a"]+=1
        elif score["b"]>score["a"]: total["b"]+=1
    return total

def getA(a,bl):
    if bl-1 in a: return bl-1
    elif bl==0: return a[len(a)-1]
    else:
        for i in range(len(a)):
            if bl-i in a: return bl-i
    return a[len(a)-1]
        
def rafal(n):
    a=[x for x in range(n)]
    b=[x for x in range(n)]
    score={"a":0, "b":0}
    bx=choice(b)
    bl=bx
    ax=len(a)-1
    if ax>bx: score["a"]+=1
    elif bx>ax: score["b"]+=1
    a.remove(ax)
    b.remove(bx)
    for i in range(8):
        bx=choice(b)
        ax = getA(a,bl)
        
        if ax>bx: score["a"]+=1
        elif bx>ax: score["b"]+=1
        bl=bx
        a.remove(ax)
        b.remove(bx)
    return score

def raf_kol(n):
    a=[x for x in range(n)]
    b=[x for x in range(n)]
    score={"a":0, "b":0}
    bx=0
    bl=bx
    ax=len(a)-1
    if ax>bx: score["a"]+=1
    elif bx>ax: score["b"]+=1
    a.remove(ax)
    b.remove(bx)
    for bx in b:
        ax=getA(a,bl)
        if ax>bx: score["a"]+=1
        elif bx>ax: score["b"]+=1
        a.remove(ax)
    return(score)

#print(turniej(1000000,obaLosowo,50))
print(turniej(1000000,rafal,1000))