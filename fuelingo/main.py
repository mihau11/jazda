
import tkinter as tk
from tkinter import ttk
from tkinter import messagebox
from game_logic import GameLogic
from windows import DailySummaryWindow, DispatchWindow, ReinforcementWindow

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
        summary = self.game_logic.resolve_day()
        summary_win = DailySummaryWindow(self, summary)
        self.wait_window(summary_win)
        self.update_display()
        # Theme switching logic
        if self.game_logic.current_stance == 'Offensive':
            self.set_theme('offensive')
        else:
            self.set_theme('default')
        if self.game_logic.game_over:
            message = "VICTORY!\n\nYou have successfully broken the enemy lines!" if self.game_logic.victory else "DEFEAT.\n\nYour forces have been broken and the front has collapsed."
            messagebox.showinfo("Game Over", message)
            self.destroy()
        elif self.game_logic.reinforcement_timer <= 0:
            self.end_day_btn.config(state='disabled')
            rein_win = ReinforcementWindow(self, self.game_logic)
            self.wait_window(rein_win)
            self.end_day_btn.config(state='normal')
            self.update_display()
    def set_theme(self, theme):
        # Default theme colors
        default_bg = 'gray90'
        default_canvas_bg = 'gray95'
        default_btn_bg = 'gray90'
        default_btn_fg = 'black'
        default_end_btn_bg = 'darkgreen'
        default_end_btn_fg = 'white'
        offensive_bg = 'firebrick1'
        offensive_canvas_bg = 'mistyrose'
        offensive_btn_bg = 'yellow'
        offensive_btn_fg = 'black'
        if theme == 'offensive':
            bg = offensive_bg
            canvas_bg = offensive_canvas_bg
            btn_bg = offensive_btn_bg
            btn_fg = offensive_btn_fg
            end_btn_bg = offensive_btn_bg
            end_btn_fg = offensive_btn_fg
        else:
            bg = default_bg
            canvas_bg = default_canvas_bg
            btn_bg = default_btn_bg
            btn_fg = default_btn_fg
            end_btn_bg = default_end_btn_bg
            end_btn_fg = default_end_btn_fg
        # Update main frames and canvases
        self.configure(bg=bg)
        for child in self.winfo_children():
            if isinstance(child, tk.Frame):
                child.configure(bg=bg)
            if isinstance(child, tk.Canvas):
                child.configure(bg=canvas_bg)
            if isinstance(child, tk.Button):
                child.configure(bg=btn_bg, fg=btn_fg)
                if child.cget('text') == 'END DAY':
                    child.configure(bg=end_btn_bg, fg=end_btn_fg)
            if isinstance(child, ttk.LabelFrame):
                try:
                    child.configure(style='Custom.TLabelframe')
                except Exception:
                    pass
        # Update all widgets recursively
        def update_children(widget):
            for c in widget.winfo_children():
                if isinstance(c, tk.Frame):
                    c.configure(bg=bg)
                if isinstance(c, tk.Canvas):
                    c.configure(bg=canvas_bg)
                if isinstance(c, tk.Button):
                    c.configure(bg=btn_bg, fg=btn_fg)
                    if c.cget('text') == 'END DAY':
                        c.configure(bg=end_btn_bg, fg=end_btn_fg)
                if isinstance(c, ttk.LabelFrame):
                    try:
                        c.configure(style='Custom.TLabelframe')
                    except Exception:
                        pass
                update_children(c)
        # Set ttk style for LabelFrame
        style = ttk.Style()
        style.configure('Custom.TLabelframe', background=bg)
        style.configure('Custom.TLabelframe.Label', background=bg)
        update_children(self)

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