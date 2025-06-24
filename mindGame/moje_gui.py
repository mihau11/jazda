import tkinter as tk
from tkinter import simpledialog
from random import choice, shuffle

class Gracz():
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

    def zagrywa(self, karta):
        self.check()
        self.karta = karta
        self.reka.remove(karta)

    def check(self):
        if not self.reka:
            self.reka = self.odrzucone
            self.odrzucone = []

def wojna(A, B, stawka):
    zakryte = 1
    if A.suma() < zakryte + 1:
        B.odrzucone += A.reka + A.odrzucone + stawka
        A.reka, A.odrzucone = [], []
        return [A, B, "Bot wygrał przez brak kart", []]
    if B.suma() < zakryte + 1:
        A.odrzucone += B.reka + B.odrzucone + stawka
        B.reka, B.odrzucone = [], []
        return [A, B, "Gracz wygrał przez brak kart", []]

    for _ in range(zakryte):
        A.losuj()
        B.losuj()
        stawka += [A.karta, B.karta]

    return [A, B, "wojna", stawka]

def przygotuj_talie(n, p):
    talia = [x+1 for y in range(2 * p) for x in range(n)]
    shuffle(talia)
    A = Gracz()
    B = Gracz()
    A.reka = talia[:p * n]
    B.reka = talia[p * n:]
    return A, B

def aktualizuj_gui():
    for widget in ramka_ruchu.winfo_children():
        widget.destroy()

    info_bot.config(text=f"Bot: {len(bot.reka)} kart")
    info_rundy.config(text=f"Runda: {rundy[0]}")
    info_stosy.config(text=f"Twoje odrzucone: {len(gracz.odrzucone)} | Bota odrzucone: {len(bot.odrzucone)}")

    for karta in sorted(gracz.reka):
        btn = tk.Button(ramka_ruchu, text=str(karta), command=lambda k=karta: wykonaj_runde(k))
        btn.pack(side=tk.LEFT, padx=2)

def wykonaj_runde(karta):
    gracz.zagrywa(karta)
    bot.losuj()
    wynik = ""

    stawka = [gracz.karta, bot.karta]
    wynik += f"Zagrałeś: {gracz.karta}, Bot: {bot.karta}\n"

    if gracz.karta > bot.karta:
        gracz.odrzucone += stawka
        wynik += "Wygrana!"
    elif bot.karta > gracz.karta:
        bot.odrzucone += stawka
        wynik += "Przegrana."
    else:
        wynik += "Wojna!\n"
        A, B, status, stawka = wojna(gracz, bot, stawka)
        if status == "wojna":
            wynik_label.config(text=wynik + "\nWybierz kartę na wojnę:")
            pokaz_wojne(stawka)
            return
        else:
            wynik = status

    zakoncz_runde(wynik)

def pokaz_wojne(stawka):
    for widget in ramka_ruchu.winfo_children():
        widget.destroy()

    for karta in sorted(gracz.reka):
        btn = tk.Button(ramka_ruchu, text=str(karta), command=lambda k=karta: rozstrzygnij_wojne(k, stawka))
        btn.pack(side=tk.LEFT, padx=2)
        
def rozstrzygnij_wojne(karta, stawka):
    gracz.zagrywa(karta)
    bot.losuj()
    stawka += [gracz.karta, bot.karta]

    wynik = f"Wojna! Zagrałeś: {gracz.karta}, Bot: {bot.karta}\n"

    if gracz.karta > bot.karta:
        gracz.odrzucone += stawka
        wynik += "Wygrałeś wojnę!"
    else:
        bot.odrzucone += stawka
        wynik += "Przegrałeś wojnę."

    zakoncz_runde(wynik)

def zakoncz_runde(wynik):
    wynik_label.config(text=wynik)
    gracz.check()
    bot.check()
    rundy[0] += 1

    if gracz.suma() == 0 or bot.suma() == 0:
        wynik_label.config(text=f"Koniec gry! {'Gracz' if gracz.suma() > 0 else 'Bot'} wygrał!")
        for widget in ramka_ruchu.winfo_children():
            widget.config(state=tk.DISABLED)
    else:
        aktualizuj_gui()

# GUI
root = tk.Tk()
root.withdraw()

n = simpledialog.askinteger("Parametr n", "Podaj rozmiar talii (n):", minvalue=1, maxvalue=100)
p = simpledialog.askinteger("Parametr p", "Podaj liczbę powtórzeń talii (p):", minvalue=1, maxvalue=10)

root.deiconify()
root.title("Gra w Wojnę")
root.geometry("600x300")
root.resizable(False, False)

info_bot = tk.Label(root, text="")
info_bot.pack()

info_rundy = tk.Label(root, text="")
info_rundy.pack()

info_stosy = tk.Label(root, text="")
info_stosy.pack()

ramka_ruchu = tk.Frame(root)
ramka_ruchu.pack(pady=10)

wynik_label = tk.Label(root, text="")
wynik_label.pack(pady=10)

gracz, bot = przygotuj_talie(n, p)
rundy = [1]

aktualizuj_gui()

root.mainloop()
