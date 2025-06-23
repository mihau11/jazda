from random import choice

def getA(a,bl):
    if bl-1 in a: return bl-1
    elif bl==0: return a[len(a)-1]
    else:
        for i in range(len(a)):
            if bl-i in a: return bl-i
    return a[len(a)-1]

def wojna(a,b,ax,bx,bl,al):
    a.remove(al)
    b.remove(bl)
    zakryte=2
    if len(a)+len(ax)<zakryte+1:
        bx+=a+ax+[al,bl]
        return [a,b,ax,bx,-1]
    if len(b)+len(bx)<zakryte+1:
        ax+=b+bx+[al,bl]
        return [a,b,ax,bx,-2]
    wax,wbx=[],[]
    for i in range(zakryte):
        if len(a)==0:
            a=ax
            ax=[]
        if len(b)==0:
            b=bx
            bx=[]
        ak=choice(a)
        bk=choice(b)
        wax.append(ak)
        wbx.append(bk)
        a.remove(ak)
        b.remove(bk)
    if len(a)==0:
        a=ax
        ax=[]
    if len(b)==0:
        b=bx
        bx=[]
    ak,bk=getA(a,bl),choice(b)
    
    if ak==bk: 
        print("x")
        return wojna(a,b,ax,bx,bk,ak)
    elif ak>bk:
        ax+=wax+wbx+[ak,bk,bl,al]
    elif bk>ak:
        bx+=wax+wbx+[ak,bk,bl,al]
    a.remove(ak)
    b.remove(bk)
    return [a,b,ax,bx,bk]

def mecz(n):
    a=[x for x in range(n)]
    b=[x for x in range(n)]
    bl=-1000000
    ax=[]
    bx=[]
    licznik=0
    while len(a)>0 and len(b)>0:
        ak,bk=getA(a,bl),choice(b)
        if ak>bk:
            ax+=[ak,bk]
            a.remove(ak)
            b.remove(bk)
            bl=bk
        elif bk>ak:
            bx+=[ak,bk]
            a.remove(ak)
            b.remove(bk)
            bl=bk        
        else:
            print([ak,bk])
            a,b,ax,bx,bl=wojna(a,b,ax,bx,bk,ak)
            if bl <0:
                return [len(a+ax),len(b+bx),licznik*-1]
        #print(ak,bk)
        licznik+=1
        if len(a)==0:
            a=ax
            ax=[]
        if len(b)==0:
            b=bx
            bx=[]
    return [len(a+ax),len(b+bx),licznik]

def turniej(n,metoda,l):
    total=[0,0,0]
    for i in range(n):
        score=metoda(l)
        if score[0]>score[1]: total[0]+=1
        elif score[1]>score[0]: total[1]+=1
        else: total[2]+=1
    return total
#print(turniej(1000000,mecz,20))
for i in range(1):
    w=mecz(10)
    if w[0]==20 or w[1]==20: print(w)
    elif w[2]<0: print([[w]])
    else: print([w])