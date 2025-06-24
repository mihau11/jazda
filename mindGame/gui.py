import tkinter as tk
from random import choice

class Gracz:
    def __init__(self):
        self.reka = []
        self.odrzucone = []
        self.karta = -1

    def suma(self):
        return len(self.reka) + len(self.odrzucone)

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
        if self.reka == []:
            self.reka = self.odrzucone
            self.odrzucone = []

def wojna(A: Gracz, B: Gracz, stawka: list):
    zakryte = 1
    if A.suma() < zakryte + 1:
        B.odrzucone += A.reka + A.odrzucone + stawka
        A.reka, A.odrzucone = [], []
        return
    if B.suma() < zakryte + 1:
        A.odrzucone += B.reka + B.odrzucone + stawka
        B.reka, B.odrzucone = [], []
        return

    for _ in range(zakryte):
        A.losuj()
        B.losuj()
        stawka += [A.karta, B.karta]

    A.kartA(B.karta)
    B.losuj()
    stawka += [A.karta, B.karta]

    if A.karta == B.karta:
        wojna(A, B, stawka)
    elif A.karta > B.karta:
        A.odrzucone += stawka
    else:
        B.odrzucone += stawka

# ===== GUI START =====

A = Gracz()
B = Gracz()
A.reka = [x for x in range(10)]
B.reka = [x for x in range(10)]
bl = -1000
licznik_rund = 0

def zagraj_runde():
    global bl, licznik_rund
    if A.suma() == 0 or B.suma() == 0:
        wynik_label.config(text="Gra zakończona!")
        return

    licznik_rund += 1
    A.kartA(bl)
    B.losuj()

    wynik = f"Runda {licznik_rund}\nTy: {A.karta} | Komputer: {B.karta}\n"
    if A.karta > B.karta:
        A.odrzucone += [A.karta, B.karta]
        wynik += "Wygrałeś rundę!"
    elif B.karta > A.karta:
        B.odrzucone += [A.karta, B.karta]
        wynik += "Przegrałeś rundę!"
    else:
        wynik += "WOJNA!"
        wojna(A, B, [A.karta, B.karta])
        if A.suma() == 0 or B.suma() == 0:
            wynik += "\nKoniec gry w trakcie wojny."

    bl = B.karta
    A.check()
    B.check()

    stan_label.config(text=f"Ty: {A.suma()} kart | Komputer: {B.suma()} kart")
    wynik_label.config(text=wynik)

# GUI setup
root = tk.Tk()
root.title("Wojna - Gra karciana")
root.resizable(False, False)  # <- STAŁY ROZMIAR OKNA

frame = tk.Frame(root, padx=20, pady=20)
frame.pack()

stan_label = tk.Label(frame, text="Rozpocznij grę!", font=("Arial", 14))
stan_label.pack(pady=10)

# SZTYWNY ROZMIAR WYNIKU (szerokość i wysokość w "znakach")
wynik_label = tk.Label(frame, text="", font=("Courier", 12), justify="left", width=40, height=4)
wynik_label.pack()

btn = tk.Button(frame, text="Zagraj rundę", command=zagraj_runde, font=("Arial", 14))
btn.pack(pady=10)

root.mainloop()