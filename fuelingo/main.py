import tkinter as tk
from tkinter import ttk
from tkinter import messagebox
import random

# --- GAME LOGIC CLASS (With Intelligence Mechanics) ---
class GameLogic:
    def __init__(self):
        self.day = 0; self.game_over = False; self.victory = False
        self.start_infantry = random.randint(4500, 5500); self.start_tanks = random.randint(130, 170)
        self.start_vehicles = random.randint(280, 350); self.start_artillery = random.randint(70, 90)
        self.infantry = self.start_infantry; self.tanks = self.start_tanks; self.vehicles = self.start_vehicles; self.artillery = self.start_artillery
        scale_factor = self.infantry / 5000
        self.depot_fuel, self.depot_rifle_ammo, self.depot_gun_ammo, self.depot_rations = int(1500 * scale_factor), int(2000 * scale_factor), int(1000 * scale_factor), int(2000 * scale_factor)
        self.frontline_fuel, self.frontline_rifle_ammo, self.frontline_gun_ammo, self.frontline_rations = int(120 * scale_factor), int(200 * scale_factor), int(100 * scale_factor), int(250 * scale_factor)
        self.frontline_integrity = 100; self.current_stance = 'Defensive'; self.offensive_days_counter = 0
        self.frontline_distance = 2; self.convoy_en_route = False; self.convoy_cargo = {}; self.convoy_eta = 0; self.convoy_return_eta = 0; self.convoy_type = None
        self.rail_cooldown = 0; self.reinforcement_timer = random.randint(5, 7); self.consumption_history = []
        self.unit_consumption = {'fuel': {'tanks': 0.3, 'vehicles': 0.1}, 'rations': {'infantry': 0.008}, 'rifle_ammo': {'infantry': 0.018}, 'gun_ammo': {'tanks': 0.4, 'artillery': 0.2}}
        
        # New Intelligence Mechanics
        self.intel = 10
        self.enemy_disruption = 0
        self.is_route_secured = False
        self.is_weakness_identified = False
        self.is_consumption_forecasted = False

        # Enemy state mechanics
        self.enemy_state = "Defensive"  # Enemy starts in defensive
        self.enemy_offensive_days_left = 0
        self.player_defensive_streak = 0  # Track consecutive player defensive days

    def get_daily_consumption(self):
        consumption = {'fuel': 0, 'rations': 0, 'rifle_ammo': 0, 'gun_ammo': 0}
        consumption['fuel'] += self.tanks * self.unit_consumption['fuel']['tanks'] + self.vehicles * self.unit_consumption['fuel']['vehicles']
        consumption['rations'] += self.infantry * self.unit_consumption['rations']['infantry']
        consumption['rifle_ammo'] += self.infantry * self.unit_consumption['rifle_ammo']['infantry']
        consumption['gun_ammo'] += self.tanks * self.unit_consumption['gun_ammo']['tanks'] + self.artillery * self.unit_consumption['gun_ammo']['artillery']
        if self.current_stance == 'Defensive':
            for key in consumption: consumption[key] *= 0.25
        
        variance = 0.0 if self.is_consumption_forecasted else 0.1 # No variance if forecasted
        return {key: int(val * random.uniform(1.0 - variance, 1.0 + variance)) for key, val in consumption.items()}

    def resolve_day(self):
        self.day += 1; initial_integrity = self.frontline_integrity
        if self.current_stance == 'Defensive': self.intel += 5
        
        convoy_event_log = ""
        if self.rail_cooldown > 0: self.rail_cooldown -= 1
        self.reinforcement_timer -= 1
        
        if self.convoy_en_route:
            # Enemy Interdiction check
            ambush_chance = (self.enemy_disruption / 100)
            if self.is_route_secured: ambush_chance *= 0.1 # 90% reduction
            if random.random() < ambush_chance:
                fuel_loss = int(self.convoy_cargo.get('fuel',0) * 0.3); self.convoy_cargo['fuel'] -= fuel_loss
                ammo_loss = int(self.convoy_cargo.get('rifle_ammo',0) * 0.3); self.convoy_cargo['rifle_ammo'] -= ammo_loss
                convoy_event_log = f"Convoy ambushed! Lost {fuel_loss} Fuel and {ammo_loss} Rifle Ammo."
            
            self.convoy_eta -= 1
            if self.convoy_eta == 0:
                for res, amt in self.convoy_cargo.items(): setattr(self, f"frontline_{res}", getattr(self, f"frontline_{res}") + amt)
                self.convoy_en_route = False; self.convoy_return_eta = self.frontline_distance
        elif self.convoy_return_eta > 0:
            self.convoy_return_eta -= 1

        # Track player defensive streak
        if self.current_stance == 'Defensive':
            self.player_defensive_streak += 1
        else:
            self.player_defensive_streak = 0

        # Trigger enemy offensive if player is too long in defensive
        if self.enemy_state == "Defensive" and self.player_defensive_streak >= 4:
            self.enemy_state = "Offensive"
            self.enemy_offensive_days_left = random.randint(2, 3)

        # Handle enemy offensive duration
        if self.enemy_state == "Offensive":
            self.enemy_offensive_days_left -= 1
            if self.enemy_offensive_days_left <= 0:
                self.enemy_state = "Defensive"
                self.enemy_offensive_days_left = 0

        daily_needs = self.get_daily_consumption()
        self.consumption_history.append({'stance': self.current_stance, 'consumption': daily_needs})
        shortfalls = {}
        for res, needed in daily_needs.items():
            available = getattr(self, f"frontline_{res}"); shortfalls[res] = max(0, needed - available)
            setattr(self, f"frontline_{res}", max(0, available - needed))

        integrity_change = 0 - shortfalls['rations'] * 0.5
        losses = {'infantry': 0, 'tanks': 0, 'vehicles': 0, 'artillery': 0}
        outcome = ""

        if self.current_stance == 'Defensive':
            outcome = "Defensive Hold (+5 Intel)"
            if sum(shortfalls.values()) == 0: integrity_change += 5
            losses['infantry'] = random.randint(int(self.start_infantry * 0.001), int(self.start_infantry * 0.004))
            if random.random() < 0.1: losses['tanks'] = 1
            if self.enemy_state == "Offensive":
                # Enemy attacks: increase losses and reduce integrity
                losses['infantry'] += random.randint(80, 180)
                losses['tanks'] += random.randint(2, 6)
                losses['vehicles'] += random.randint(5, 12)
                losses['artillery'] += random.randint(1, 4)
                integrity_change -= random.randint(5, 12)
                outcome += "Enemy launched an offensive! Your forces suffered extra losses.\n"
        else: # Offensive
            self.enemy_disruption += 3 # Offensives draw attention
            is_failed = (shortfalls['fuel'] > daily_needs['fuel'] * 0.4 or shortfalls['rifle_ammo'] > daily_needs['rifle_ammo'] * 0.4 or shortfalls['gun_ammo'] > daily_needs['gun_ammo'] * 0.4)
            if is_failed:
                outcome = "Offensive Failed"; integrity_change -= 25; self.offensive_days_counter = 0
                losses = {k: random.randint(int(getattr(self, f"start_{k}")*m1), int(getattr(self, f"start_{k}")*m2)) for k, m1, m2 in 
                          [('infantry',0.03,0.05), ('tanks',0.05,0.1), ('vehicles',0.03,0.06), ('artillery',0.02,0.05)]}
            else:
                outcome = "Offensive Succeeded"; self.offensive_days_counter += 1; self.frontline_distance += 1
                loss_multiplier = 0.5 if self.is_weakness_identified else 1.0 # 50% fewer losses
                losses = {k: int(random.randint(int(getattr(self, f"start_{k}")*m1), int(getattr(self, f"start_{k}")*m2)) * loss_multiplier) for k, m1, m2 in 
                          [('infantry',0.015,0.025), ('tanks',0.02,0.05), ('vehicles',0.01,0.03), ('artillery',0.0,0.02)]}

        for k, v in losses.items(): setattr(self, k, max(0, getattr(self, k) - v))
        self.frontline_integrity = max(0, min(100, self.frontline_integrity + integrity_change))
        
        if self.frontline_integrity <= 0: self.game_over = True; outcome = "DEFEAT: Frontline integrity collapsed."
        elif self.infantry <= 0: self.game_over = True; outcome = "DEFEAT: No infantry left to hold the line."
        elif self.offensive_days_counter >= 3: self.game_over = True; self.victory = True; outcome = "VICTORY! The enemy line is broken!"
        
        # Reset turn-based flags
        self.is_route_secured = self.is_weakness_identified = self.is_consumption_forecasted = False

        return {"outcome": outcome, "losses": losses, "consumption": daily_needs, "integrity_change": self.frontline_integrity - initial_integrity, "convoy_event": convoy_event_log, "enemy_state": self.enemy_state}
        self.is_route_secured = self.is_weakness_identified = self.is_consumption_forecasted = False
        
        return {"outcome": outcome, "losses": losses, "consumption": daily_needs, "integrity_change": self.frontline_integrity - initial_integrity, "convoy_event": convoy_event_log}

    def spend_intel(self, action):
        costs = {"secure": 10, "weakness": 25, "forecast": 5}
        if self.intel >= costs[action]:
            self.intel -= costs[action]
            if action == "secure": self.is_route_secured = True
            elif action == "weakness": self.is_weakness_identified = True
            elif action == "forecast": self.is_consumption_forecasted = True
            return True
        return False

    def dispatch_convoy(self, convoy_type, cargo):
        self.convoy_en_route = True; self.convoy_cargo = cargo; self.convoy_eta = self.frontline_distance; self.convoy_type = convoy_type
        if convoy_type == 'Train': self.rail_cooldown = 3; self.enemy_disruption += 5 # Train usage is noticeable
        for res, amt in cargo.items(): setattr(self, f"depot_{res}", getattr(self, f"depot_{res}") - amt)
    
    def apply_reinforcements(self, choice):
        if choice == 1: self.infantry += 2000; self.depot_rifle_ammo += 1500
        elif choice == 2: self.tanks += 50; self.vehicles += 100; self.depot_gun_ammo += 1000
        elif choice == 3: self.vehicles += 50; self.depot_fuel += 1000; self.depot_rations += 1000
        self.reinforcement_timer = random.randint(5, 7)

# --- GUI Pop-up Windows ---
class DailySummaryWindow(tk.Toplevel):
    def __init__(self, parent, summary):
        super().__init__(parent); self.title(f"Day {parent.game_logic.day} - After Action Report"); self.geometry("400x400"); self.resizable(False, False); self.transient(parent); self.grab_set(); self.protocol("WM_DELETE_WINDOW", lambda: None)
        ttk.Label(self, text=summary['outcome'], font=('Helvetica', 14, 'bold')).pack(pady=(10,5))
        if summary['convoy_event']: ttk.Label(self, text=summary['convoy_event'], foreground='red').pack()
        casualty_frame = ttk.LabelFrame(self, text="Casualty Report"); casualty_frame.pack(pady=5, padx=10, fill='x')
        for unit, num in summary['losses'].items():
            if num > 0: ttk.Label(casualty_frame, text=f"{unit.title()}: -{num}").pack(anchor='w', padx=10)
        consump_frame = ttk.LabelFrame(self, text="Consumption Report"); consump_frame.pack(pady=5, padx=10, fill='x')
        for res, num in summary['consumption'].items(): ttk.Label(consump_frame, text=f"{res.replace('_', ' ').title()}: {num}").pack(anchor='w', padx=10)
        ttk.Label(self, text=f"Integrity Change: {int(summary['integrity_change'])}").pack(pady=5)
        ttk.Button(self, text="Acknowledge & Proceed", command=self.destroy).pack(pady=10)
class DispatchWindow(tk.Toplevel):
    # ... (Unchanged)
    def __init__(self, parent, game_logic, convoy_type):
        super().__init__(parent); self.parent = parent; self.game_logic = game_logic; self.convoy_type = convoy_type; self.capacity = 250 if convoy_type == 'Trucks' else 1000
        self.title(f"Dispatch {convoy_type}"); self.geometry("400x350"); self.resizable(False, False); self.transient(parent); self.sliders = {}; self.slider_vars = {}
        resources = ['fuel', 'rations', 'rifle_ammo', 'gun_ammo']
        for i, res in enumerate(resources):
            tk.Label(self, text=f"{res.replace('_', ' ').title()}:").grid(row=i, column=0, padx=10, pady=5, sticky='w')
            max_val = getattr(self.game_logic, f"depot_{res}"); self.slider_vars[res] = tk.IntVar()
            self.sliders[res] = tk.Scale(self, from_=0, to=max_val, orient='horizontal', variable=self.slider_vars[res], command=self.update_load)
            self.sliders[res].grid(row=i, column=1, sticky='ew', padx=5); tk.Label(self, textvariable=self.slider_vars[res]).grid(row=i, column=2, padx=10)
        self.grid_columnconfigure(1, weight=1); self.load_var = tk.StringVar(value=f"Load: 0 / {self.capacity}")
        self.load_label = tk.Label(self, textvariable=self.load_var); self.load_label.grid(row=4, column=0, columnspan=3, pady=10)
        self.send_button = tk.Button(self, text="Dispatch", command=self.send); self.send_button.grid(row=5, column=0, columnspan=3, pady=10); self.update_load()
    def update_load(self, event=None):
        current_load = sum(var.get() for var in self.slider_vars.values()); self.load_var.set(f"Load: {current_load} / {self.capacity}")
        if current_load > self.capacity or current_load == 0: self.send_button.config(state='disabled'); self.load_label.config(fg='red')
        else: self.send_button.config(state='normal'); self.load_label.config(fg='black')
    def send(self): self.game_logic.dispatch_convoy(self.convoy_type, {res: var.get() for res, var in self.slider_vars.items()}); self.parent.update_display(); self.destroy()
class ReinforcementWindow(tk.Toplevel):
    # ... (Unchanged)
    def __init__(self, parent, game_logic):
        super().__init__(parent); self.parent = parent; self.game_logic = game_logic; self.title("Reinforcements Available"); self.geometry("450x200"); self.resizable(False, False); self.transient(parent)
        self.protocol("WM_DELETE_WINDOW", lambda: None); tk.Label(self, text="High Command has allocated reinforcements. Choose one package:", wraplength=400).pack(pady=10)
        btn_frame = tk.Frame(self); btn_frame.pack(pady=10, fill='x', expand=True)
        tk.Button(btn_frame, text="Infantry Division\n(+2000 Inf, +1500 Rifle Ammo)", command=lambda: self.choose(1)).pack(pady=5, padx=10)
        tk.Button(btn_frame, text="Armored Brigade\n(+50 Tanks, +100 Veh, +1000 Gun Ammo)", command=lambda: self.choose(2)).pack(pady=5, padx=10)
        tk.Button(btn_frame, text="Quartermaster's Corps\n(+50 Veh, +1000 Fuel, +1000 Rations)", command=lambda: self.choose(3)).pack(pady=5, padx=10)
    def choose(self, choice): self.game_logic.apply_reinforcements(choice); self.parent.update_display(); self.destroy()

# --- MAIN GUI APPLICATION ---
class LogisticsCommandGUI(tk.Tk):
    def __init__(self):
        super().__init__(); self.title("Logistics Command: Intelligence & Counter-Logistics"); self.minsize(950, 650)
        self.game_logic = GameLogic(); self.graph_category_var = tk.StringVar(value="Total")
        self.create_widgets(); self.update_display()

    def create_widgets(self):
        top_frame = tk.Frame(self, pady=5); top_frame.pack(fill='x')
        main_frame = tk.Frame(self); main_frame.pack(fill='both', expand=True, padx=10, pady=5)
        main_frame.grid_rowconfigure(0, weight=1); main_frame.grid_columnconfigure(0, weight=1); main_frame.grid_columnconfigure(1, weight=1)
        left_frame = ttk.LabelFrame(main_frame, text="Army & Depot Status"); left_frame.grid(row=0, column=0, sticky='nsew', padx=5)
        right_frame = ttk.LabelFrame(main_frame, text="Frontline Operations"); right_frame.grid(row=0, column=1, sticky='nsew', padx=5)
        self.day_var = tk.StringVar(); self.stance_var = tk.StringVar()
        ttk.Label(top_frame, textvariable=self.day_var, font=('Helvetica', 14, 'bold')).pack(side='left', padx=20)
        self.integrity_bar = ttk.Progressbar(top_frame, length=400, mode='determinate'); self.integrity_bar.pack(side='left', fill='x', expand=True, padx=20)
        ttk.Label(top_frame, textvariable=self.stance_var, font=('Helvetica', 14, 'bold')).pack(side='right', padx=20)
        ttk.Label(left_frame, text="Army Strength", font=('Helvetica', 12, 'bold')).pack(pady=5)
        self.unit_canvases = {}; self.unit_vars = {}
        for unit in ['infantry', 'tanks', 'artillery', 'vehicles']:
            frame = tk.Frame(left_frame); frame.pack(fill='x', padx=10, pady=1)
            self.unit_vars[unit] = tk.StringVar(); ttk.Label(frame, text=f"{unit.title()}:", width=10).pack(side='left')
            canvas = tk.Canvas(frame, height=30, bg='gray90'); canvas.pack(side='left', fill='x', expand=True, padx=5)
            ttk.Label(frame, textvariable=self.unit_vars[unit], width=15).pack(side='left'); self.unit_canvases[unit] = canvas
        ttk.Separator(left_frame, orient='horizontal').pack(fill='x', pady=10)
        ttk.Label(left_frame, text="Depot & Intelligence", font=('Helvetica', 12, 'bold')).pack(pady=10)
        self.intel_var = tk.StringVar()
        ttk.Label(left_frame, textvariable=self.intel_var, font=('Courier', 12, 'bold')).pack(anchor='w', padx=20)
        self.depot_vars = {res: tk.StringVar() for res in ['fuel', 'rations', 'rifle_ammo', 'gun_ammo']}
        for res, var in self.depot_vars.items(): ttk.Label(left_frame, textvariable=var, font=('Courier', 10)).pack(anchor='w', padx=20)
        # Move convoy visualization here
        convoy_status_frame = tk.Frame(left_frame); convoy_status_frame.pack(pady=10)
        self.convoy_vis_label = tk.Label(convoy_status_frame, text="[DEPOT] [--------------------] [FRONT]", font=("Courier", 10)); self.convoy_vis_label.pack()
        self.convoy_status_var = tk.StringVar(); ttk.Label(convoy_status_frame, textvariable=self.convoy_status_var).pack()

        right_frame.columnconfigure(0, weight=1)
        ttk.Label(right_frame, text="Frontline Supplies", font=('Helvetica', 12, 'bold')).pack(pady=5)
        self.frontline_vars = {res: tk.StringVar() for res in ['fuel', 'rations', 'rifle_ammo', 'gun_ammo']}
        for res, var in self.frontline_vars.items(): ttk.Label(right_frame, textvariable=var, font=('Courier', 10)).pack(anchor='w', padx=20)
        ttk.Separator(right_frame, orient='horizontal').pack(fill='x', pady=10, side='top')
        graph_filter_frame = tk.Frame(right_frame); graph_filter_frame.pack(pady=2, side='top')
        self.filter_buttons = {}; categories = ["Total", "Fuel", "Rations", "Rifle Ammo", "Gun Ammo"]
        for cat in categories: btn = tk.Button(graph_filter_frame, text=cat, command=lambda c=cat: self.set_graph_filter(c)); btn.pack(side='left', padx=3); self.filter_buttons[cat] = btn
        history_frame = tk.Frame(right_frame); history_frame.pack(fill='both', expand=True, padx=10, pady=5, side='top')
        self.history_canvas = tk.Canvas(history_frame, bg='gray95'); self.history_canvas.pack(fill='both', expand=True)

        # Footer for all actions
        footer_frame = tk.Frame(self, bg='gray90'); footer_frame.pack(side='bottom', fill='x', pady=5)
        # Spread actions horizontally
        stance_frame = tk.Frame(footer_frame, bg='gray90'); stance_frame.pack(side='left', padx=20)
        self.stance_def_btn = tk.Button(stance_frame, text="Set Defensive", command=lambda: self.set_stance('Defensive')); self.stance_def_btn.pack(pady=2, padx=2)
        self.stance_off_btn = tk.Button(stance_frame, text="Set Offensive", command=lambda: self.set_stance('Offensive')); self.stance_off_btn.pack(pady=2, padx=2)

        convoy_frame = tk.Frame(footer_frame, bg='gray90'); convoy_frame.pack(side='left', padx=20)
        self.truck_btn = tk.Button(convoy_frame, text="Dispatch Trucks", command=lambda: self.open_dispatch_window('Trucks')); self.truck_btn.pack(pady=2, padx=2)
        self.train_btn = tk.Button(convoy_frame, text="Dispatch Train", command=lambda: self.open_dispatch_window('Train')); self.train_btn.pack(pady=2, padx=2)

        intel_frame = tk.Frame(footer_frame, bg='gray90'); intel_frame.pack(side='left', padx=20)
        self.intel_btn_secure = tk.Button(intel_frame, text="Secure Route (10)", command=lambda: self.spend_intel("secure")); self.intel_btn_secure.pack(side='left', padx=2, pady=2)
        self.intel_btn_weakness = tk.Button(intel_frame, text="Identify Weakness (25)", command=lambda: self.spend_intel("weakness")); self.intel_btn_weakness.pack(side='left', padx=2, pady=2)
        self.intel_btn_forecast = tk.Button(intel_frame, text="Forecast (5)", command=lambda: self.spend_intel("forecast")); self.intel_btn_forecast.pack(side='left', padx=2, pady=2)

        # Help button
        help_frame = tk.Frame(footer_frame, bg='gray90'); help_frame.pack(side='right', padx=5)
        self.help_btn = tk.Button(help_frame, text="?", font=('Helvetica', 16, 'bold'), width=2, command=self.show_help_popup)
        self.help_btn.pack(pady=2, padx=2)

        endday_frame = tk.Frame(footer_frame, bg='gray90'); endday_frame.pack(side='right', padx=5)
        self.end_day_btn = tk.Button(endday_frame, text="END DAY", font=('Helvetica', 16, 'bold'), bg='darkgreen', fg='white', command=self.end_day_click)
        self.end_day_btn.pack(pady=2, padx=10, ipadx=10, fill='x')
        self.set_graph_filter("Total")

    def show_help_popup(self):
        help_text = (
            "Intel Actions:\n"
            "- Secure Route (10 Intel): Reduces the chance of convoy ambush for the next day.\n"
            "- Identify Weakness (25 Intel): Reduces casualties on your next successful offensive.\n"
            "- Forecast Consumption (5 Intel): Removes random variance from tomorrow's supply needs, allowing perfect planning.\n\n"
            "Convoy Types:\n"
            "- Trucks: Small, flexible, always available. Good for frequent, modest resupply.\n"
            "- Train: Large, delivers massive supplies in one trip, but has a cooldown after use. Using trains increases enemy disruption and ambush risk."
        )
        popup = tk.Toplevel(self)
        popup.title("Game Help")
        popup.geometry("540x340")
        popup.resizable(False, False)
        ttk.Label(popup, text="Game Help & Info", font=('Helvetica', 14, 'bold')).pack(pady=10)
        text_widget = tk.Text(popup, wrap='word', font=('Courier', 11), height=16, width=60)
        text_widget.pack(padx=10, pady=5)
        text_widget.insert('1.0', help_text)
        text_widget.config(state='disabled')
        ttk.Button(popup, text="Close", command=popup.destroy).pack(pady=10)

    def set_stance(self, stance): self.game_logic.current_stance = stance; self.update_display()
    def set_graph_filter(self, category):
        self.graph_category_var.set(category); self.update_history_graph()
        for cat, btn in self.filter_buttons.items(): btn.config(relief='sunken' if cat == category else 'raised')

    def spend_intel(self, action):
        if self.game_logic.spend_intel(action): self.update_display()
        else: messagebox.showwarning("Insufficient Intel", "You do not have enough Intel to authorize this action.")

    def end_day_click(self):
        summary = self.game_logic.resolve_day(); summary_win = DailySummaryWindow(self, summary); self.wait_window(summary_win); self.update_display()
        if self.game_logic.game_over:
            message = "VICTORY!\n\nYou have successfully broken the enemy lines!" if self.game_logic.victory else "DEFEAT.\n\nYour forces have been broken and the front has collapsed."
            messagebox.showinfo("Game Over", message); self.destroy()
        elif self.game_logic.reinforcement_timer <= 0:
            self.end_day_btn.config(state='disabled')
            rein_win = ReinforcementWindow(self, self.game_logic); self.wait_window(rein_win)
            self.end_day_btn.config(state='normal'); self.update_display()

    def open_dispatch_window(self, convoy_type): DispatchWindow(self, self.game_logic, convoy_type)
    def update_unit_dots(self):
        unit_dot_map = {'infantry': 50, 'tanks': 1, 'artillery': 1, 'vehicles': 2}
        for unit, canvas in self.unit_canvases.items():
            canvas.delete("all"); val_per_dot = unit_dot_map[unit]; current_val = getattr(self.game_logic, unit)
            dot_count = int(current_val / val_per_dot); x, y, dot_size, max_x = 2, 2, 4, canvas.winfo_width() - 2
            if max_x <= 0: continue
            for _ in range(dot_count):
                canvas.create_rectangle(x, y, x + dot_size, y + dot_size, fill='black', outline=""); x += dot_size + 2
                if x + dot_size > max_x: x = 2; y += dot_size + 2
    def update_history_graph(self):
        canvas = self.history_canvas; canvas.delete("all"); history = self.game_logic.consumption_history[-30:]
        if not history: return
        category_key = self.graph_category_var.get()
        values = [sum(h['consumption'].values()) for h in history] if category_key == "Total" else [h['consumption'].get(category_key.lower().replace(' ', '_'), 0) for h in history]
        width, height = canvas.winfo_width(), canvas.winfo_height()
        if width <= 1 or height <=1: return
        max_consumption = max(values) if values and max(values) > 0 else 1; bar_width = width / len(history)
        for i, (data, value) in enumerate(zip(history, values)):
            bar_height = (value / max_consumption) * (height - 15)
            x0 = i * bar_width; y0 = height - bar_height; x1 = x0 + bar_width - 1; y1 = height
            color = 'firebrick1' if data['stance'] == 'Offensive' else 'dodgerblue2'
            canvas.create_rectangle(x0, y0, x1, y1, fill=color, outline='')
            if bar_width > 25: canvas.create_text(x0 + bar_width / 2, y0 - 8, text=str(value), font=("Helvetica", 8), fill="black")
    def update_display(self):
        gl = self.game_logic; self.day_var.set(f"DAY: {gl.day}"); self.stance_var.set(f"STANCE: {gl.current_stance}"); self.integrity_bar['value'] = gl.frontline_integrity
        for unit, var_dict in self.unit_vars.items(): var_dict.set(f"{getattr(gl, unit)} / {getattr(gl, f'start_{unit}')}")
        self.intel_var.set(f"Intel Points: {gl.intel}")
        for res, var in self.depot_vars.items(): var.set(f"{res.replace('_', ' ').title():<12}: {getattr(gl, f'depot_{res}')}")
        for res, var in self.frontline_vars.items(): var.set(f"{res.replace('_', ' ').title():<12}: {getattr(gl, f'frontline_{res}')}")
        track_len = 20; track = ['-'] * track_len
        if gl.convoy_en_route:
            progress = (gl.frontline_distance - gl.convoy_eta) / gl.frontline_distance; pos = int(progress * track_len)
            if pos < track_len: track[pos] = '>C>'; self.convoy_status_var.set(f"{gl.convoy_type} en route. ETA: {gl.convoy_eta} days.")
        elif gl.convoy_return_eta > 0:
            progress = (gl.frontline_distance - gl.convoy_return_eta) / gl.frontline_distance; pos = track_len - int(progress * track_len) -1
            if pos >= 0: track[pos] = '<C<'; self.convoy_status_var.set(f"Empty {gl.convoy_type} returning. ETA: {gl.convoy_return_eta} days.")
        else: self.convoy_status_var.set("No convoy in transit.")
        self.convoy_vis_label.config(text=f"[DEPOT] {''.join(track)} [FRONT]")
        is_convoy_busy = gl.convoy_en_route or gl.convoy_return_eta > 0
        self.truck_btn.config(state='disabled' if is_convoy_busy else 'normal')
        self.train_btn.config(text=f"Train (Ready in {gl.rail_cooldown})" if gl.rail_cooldown > 0 else "Dispatch Train", state='disabled' if is_convoy_busy or gl.rail_cooldown > 0 else 'normal')
        self.stance_def_btn.config(relief='sunken' if gl.current_stance == 'Defensive' else 'raised')
        self.stance_off_btn.config(relief='sunken' if gl.current_stance == 'Offensive' else 'raised')
        # Update Intel button states
        self.intel_btn_secure.config(state='disabled' if gl.is_route_secured or gl.intel < 10 else 'normal', relief='sunken' if gl.is_route_secured else 'raised')
        self.intel_btn_weakness.config(state='disabled' if gl.is_weakness_identified or gl.intel < 25 else 'normal', relief='sunken' if gl.is_weakness_identified else 'raised')
        self.intel_btn_forecast.config(state='disabled' if gl.is_consumption_forecasted or gl.intel < 5 else 'normal', relief='sunken' if gl.is_consumption_forecasted else 'raised')
        self.after(50, self.update_unit_dots); self.after(50, self.update_history_graph)

if __name__ == "__main__":
    app = LogisticsCommandGUI()
    app.mainloop()