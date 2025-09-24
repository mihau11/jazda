import tkinter as tk
from tkinter import ttk

class DailySummaryWindow(tk.Toplevel):
    def __init__(self, parent, summary):
        super().__init__(parent)
        self.title(f"Day {parent.game_logic.day} - After Action Report")
        self.geometry("400x400")
        self.resizable(False, False)
        self.transient(parent)
        self.grab_set()
        self.protocol("WM_DELETE_WINDOW", lambda: None)

        # Position window on the right half of the parent
        self.update_idletasks()
        try:
            parent_x = parent.winfo_x()
            parent_y = parent.winfo_y()
            parent_w = parent.winfo_width()
            parent_h = parent.winfo_height()
            win_w = 400
            win_h = 400
            x = parent_x + parent_w // 2
            y = parent_y + (parent_h - win_h) // 2 if parent_h > win_h else parent_y
            self.geometry(f"{win_w}x{win_h}+{x}+{y}")
        except Exception:
            pass

        ttk.Label(self, text=summary['outcome'], font=('Helvetica', 14, 'bold')).pack(pady=(10,5))
        if summary['convoy_event']:
            ttk.Label(self, text=summary['convoy_event'], foreground='red').pack()
        casualty_frame = ttk.LabelFrame(self, text="Casualty Report")
        casualty_frame.pack(pady=5, padx=10, fill='x')
        for unit, num in summary['losses'].items():
            if num > 0:
                ttk.Label(casualty_frame, text=f"{unit.title()}: -{num}").pack(anchor='w', padx=10)
        consump_frame = ttk.LabelFrame(self, text="Consumption Report")
        consump_frame.pack(pady=5, padx=10, fill='x')
        for res, num in summary['consumption'].items():
            ttk.Label(consump_frame, text=f"{res.replace('_', ' ').title()}: {num}").pack(anchor='w', padx=10)
        ttk.Label(self, text=f"Integrity Change: {int(summary['integrity_change'])}").pack(pady=5)
        ttk.Button(self, text="Acknowledge & Proceed", command=self.destroy).pack(pady=10)

class DispatchWindow(tk.Toplevel):
    def __init__(self, parent, game_logic, convoy_type):
        super().__init__(parent)
        self.parent = parent
        self.game_logic = game_logic
        self.convoy_type = convoy_type
        self.capacity = 250 if convoy_type == 'Trucks' else 1000
        self.title(f"Dispatch {convoy_type}")
        self.geometry("400x350")
        self.resizable(False, False)
        self.transient(parent)
        self.sliders = {}
        self.slider_vars = {}
        resources = ['fuel', 'rations', 'rifle_ammo', 'gun_ammo']
        for i, res in enumerate(resources):
            tk.Label(self, text=f"{res.replace('_', ' ').title()}:" ).grid(row=i, column=0, padx=10, pady=5, sticky='w')
            max_val = getattr(self.game_logic, f"depot_{res}")
            self.slider_vars[res] = tk.IntVar()
            self.sliders[res] = tk.Scale(self, from_=0, to=max_val, orient='horizontal', variable=self.slider_vars[res], command=self.update_load)
            self.sliders[res].grid(row=i, column=1, sticky='ew', padx=5)
            tk.Label(self, textvariable=self.slider_vars[res]).grid(row=i, column=2, padx=10)
        self.grid_columnconfigure(1, weight=1)
        self.load_var = tk.StringVar(value=f"Load: 0 / {self.capacity}")
        self.load_label = tk.Label(self, textvariable=self.load_var)
        self.load_label.grid(row=4, column=0, columnspan=3, pady=10)
        self.send_button = tk.Button(self, text="Dispatch", command=self.send)
        self.send_button.grid(row=5, column=0, columnspan=3, pady=10)
        self.update_load()
    def update_load(self, event=None):
        current_load = sum(var.get() for var in self.slider_vars.values())
        self.load_var.set(f"Load: {current_load} / {self.capacity}")
        if current_load > self.capacity or current_load == 0:
            self.send_button.config(state='disabled')
            self.load_label.config(fg='red')
        else:
            self.send_button.config(state='normal')
            self.load_label.config(fg='black')
    def send(self):
        self.game_logic.dispatch_convoy(self.convoy_type, {res: var.get() for res, var in self.slider_vars.items()})
        self.parent.update_display()
        self.destroy()

class ReinforcementWindow(tk.Toplevel):
    def __init__(self, parent, game_logic):
        super().__init__(parent)
        self.parent = parent
        self.game_logic = game_logic
        self.title("Reinforcements Available")
        self.geometry("450x200")
        self.resizable(False, False)
        self.transient(parent)
        self.protocol("WM_DELETE_WINDOW", lambda: None)
        tk.Label(self, text="High Command has allocated reinforcements. Choose one package:", wraplength=400).pack(pady=10)
        btn_frame = tk.Frame(self)
        btn_frame.pack(pady=10, fill='x', expand=True)
        tk.Button(btn_frame, text="Infantry Division\n(+2000 Inf, +1500 Rifle Ammo)", command=lambda: self.choose(1)).pack(pady=5, padx=10)
        tk.Button(btn_frame, text="Armored Brigade\n(+50 Tanks, +100 Veh, +1000 Gun Ammo)", command=lambda: self.choose(2)).pack(pady=5, padx=10)
        tk.Button(btn_frame, text="Quartermaster's Corps\n(+50 Veh, +1000 Fuel, +1000 Rations)", command=lambda: self.choose(3)).pack(pady=5, padx=10)
    def choose(self, choice):
        self.game_logic.apply_reinforcements(choice)
        self.parent.update_display()
        self.destroy()
