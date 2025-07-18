import tkinter as tk
from tkinter import ttk
import math

kalibry = {
    "5.45x39mm": [880, 0.0034, 0.0056, 0.295],
    "5.56x45mm NATO": [920, 0.004, 0.0057, 0.3],
    "7.62x39mm": [715, 0.0079, 0.0079, 0.32],
    "7.62x51mm NATO": [840, 0.0093, 0.0079, 0.3],
    "7.62x54mmR": [830, 0.0096, 0.0079, 0.32],
    "9x19mm Parabellum": [400, 0.008, 0.009, 0.32],
    ".50 BMG (12.7x99mm)": [890, 0.042, 0.0127, 0.295],
    "12.7x108mm": [860, 0.048, 0.0127, 0.3],
    "14.5x114mm": [1000, 0.064, 0.0145, 0.28],
    "20x102mm": [1030, 0.102, 0.02, 0.25],
    "40x53mm": [240, 0.23, 0.04, 0.4],
    "5.7x28mm (Belgian)": [715, 0.002, 0.0057, 0.28],
    "0.45 ACP (American)": [260, 0.015, 0.01143, 0.35],
    "6.8x51mm (American)": [910, 0.0113, 0.0068, 0.29],
    "7.62x35mm Blackout": [620, 0.0095, 0.00762, 0.3],
    "9x39mm (Russian)": [290, 0.016, 0.009, 0.34]
}

def symuluj_rzut(x_docelowy, kaliber, kat_deg, dt=0.01, eps=1.0):
    v0, masa, sr_diam, Cd = kalibry[kaliber]
    rho = 1.225
    A = math.pi * (sr_diam / 2) ** 2
    g = 9.81

    x = y = t = 0
    kat_rad = math.radians(kat_deg)
    vx = v0 * math.cos(kat_rad)
    vy = v0 * math.sin(kat_rad)

    while y >= 0:
        v = math.hypot(vx, vy)
        Fd = 0.5 * Cd * rho * A * v**2
        ax = -Fd * vx / (masa * v)
        ay = -Fd * vy / (masa * v) - g

        vx += ax * dt
        vy += ay * dt
        x += vx * dt
        y += vy * dt
        t += dt

        if abs(x - x_docelowy) <= eps and vy < 0:
            return True, t
        if x > x_docelowy + eps and vy < 0:
            return True, t

    return False, None

def znajdz_kat_bisekcja(x_doc, kaliber, dokladnosc=0.001):
    min_kat = 0.01
    max_kat = 45.0
    wynik = None
    czas = None

    while (max_kat - min_kat) > dokladnosc:
        mid_kat = (min_kat + max_kat) / 2
        trafiony, t = symuluj_rzut(x_doc, kaliber, mid_kat)

        if trafiony:
            wynik = mid_kat
            czas = t
            max_kat = mid_kat
        else:
            min_kat = mid_kat

    return (round(wynik, 3), czas) if wynik else (None, None)

def uniesienie_lufy(kat_deg, lufa_m=0.5):
    return math.sin(math.radians(kat_deg)) * lufa_m * 1000  # mm

root = tk.Tk()
root.title("Porównanie balistyki dwóch kalibrów")
root.geometry("520x380")
root.resizable(False, False)

tk.Label(root, text="Wybierz kaliber 1:").grid(row=0, column=0, pady=10, padx=10)
kaliber_var1 = tk.StringVar(value=list(kalibry.keys())[0])
kaliber_menu1 = ttk.Combobox(root, textvariable=kaliber_var1, values=list(kalibry.keys()), state="readonly", width=30)
kaliber_menu1.grid(row=1, column=0, padx=10)

tk.Label(root, text="Wybierz kaliber 2:").grid(row=0, column=1, pady=10, padx=10)
kaliber_var2 = tk.StringVar(value=list(kalibry.keys())[1])
kaliber_menu2 = ttk.Combobox(root, textvariable=kaliber_var2, values=list(kalibry.keys()), state="readonly", width=30)
kaliber_menu2.grid(row=1, column=1, padx=10)

tk.Label(root, text="Dystans do celu (m):").grid(row=2, column=0, columnspan=2, pady=(15,0))

frame_dystans = tk.Frame(root)
frame_dystans.grid(row=3, column=0, columnspan=2, pady=5)

dystans_var = tk.IntVar(value=1000)

dystans_entry = tk.Entry(frame_dystans, width=10, justify='center')
dystans_entry.pack()
dystans_entry.insert(0, "1000")

dystans_slider = tk.Scale(frame_dystans, from_=100, to=5000, orient='horizontal',
                          variable=dystans_var, length=460)
dystans_slider.pack()

def on_entry_change(event):
    try:
        val = int(dystans_entry.get())
        if 100 <= val <= 5000:
            dystans_var.set(val)
    except ValueError:
        pass

def on_slider_change(val):
    dystans_entry.delete(0, tk.END)
    dystans_entry.insert(0, str(int(float(val))))

dystans_entry.bind('<Return>', on_entry_change)
dystans_var.trace_add('write', lambda *args: on_slider_change(dystans_var.get()))

wynik_label1 = tk.Label(root, text="Kaliber 1 wynik", font=("Courier", 11), justify="left")
wynik_label1.grid(row=5, column=0, padx=10, sticky="w")

wynik_label2 = tk.Label(root, text="Kaliber 2 wynik", font=("Courier", 11), justify="left")
wynik_label2.grid(row=5, column=1, padx=10, sticky="w")

def oblicz():
    kaliber1 = kaliber_var1.get()
    kaliber2 = kaliber_var2.get()
    dystans = dystans_var.get()
    wynik_label1.config(text="Obliczanie...")
    wynik_label2.config(text="Obliczanie...")

    kat1, t1 = znajdz_kat_bisekcja(dystans, kaliber1)
    kat2, t2 = znajdz_kat_bisekcja(dystans, kaliber2)

    if kat1:
        h1 = uniesienie_lufy(kat1)
        wynik1 = f"Kąt: {kat1:.3f}°\nUniesienie lufy: {h1:.1f} mm\nCzas lotu: {t1:.2f} s"
    else:
        wynik1 = "Nie osiągnięto celu"

    if kat2:
        h2 = uniesienie_lufy(kat2)
        wynik2 = f"Kąt: {kat2:.3f}°\nUniesienie lufy: {h2:.1f} mm\nCzas lotu: {t2:.2f} s"
    else:
        wynik2 = "Nie osiągnięto celu"

    wynik_label1.config(text=f"{kaliber1}:\n{wynik1}")
    wynik_label2.config(text=f"{kaliber2}:\n{wynik2}")

btn_oblicz = tk.Button(root, text="Oblicz kąty i uniesienia", command=oblicz)
btn_oblicz.grid(row=4, column=0, columnspan=2, pady=10)

root.mainloop()
