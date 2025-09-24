import random

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
        self.intel = 10
        self.enemy_disruption = 0
        self.is_route_secured = False
        self.is_weakness_identified = False
        self.is_consumption_forecasted = False
        self.enemy_state = "Defensive"
        self.enemy_offensive_days_left = 0
        self.player_defensive_streak = 0
    def get_daily_consumption(self):
        consumption = {'fuel': 0, 'rations': 0, 'rifle_ammo': 0, 'gun_ammo': 0}
        consumption['fuel'] += self.tanks * self.unit_consumption['fuel']['tanks'] + self.vehicles * self.unit_consumption['fuel']['vehicles']
        consumption['rations'] += self.infantry * self.unit_consumption['rations']['infantry']
        consumption['rifle_ammo'] += self.infantry * self.unit_consumption['rifle_ammo']['infantry']
        consumption['gun_ammo'] += self.tanks * self.unit_consumption['gun_ammo']['tanks'] + self.artillery * self.unit_consumption['gun_ammo']['artillery']
        if self.current_stance == 'Defensive':
            for key in consumption: consumption[key] *= 0.25
        variance = 0.0 if self.is_consumption_forecasted else 0.1
        return {key: int(val * random.uniform(1.0 - variance, 1.0 + variance)) for key, val in consumption.items()}
    def resolve_day(self):
        self.day += 1; initial_integrity = self.frontline_integrity
        if self.current_stance == 'Defensive': self.intel += 5
        convoy_event_log = ""
        if self.rail_cooldown > 0: self.rail_cooldown -= 1
        self.reinforcement_timer -= 1
        if self.convoy_en_route:
            ambush_chance = (self.enemy_disruption / 100)
            if self.is_route_secured: ambush_chance *= 0.1
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
        if self.current_stance == 'Defensive':
            self.player_defensive_streak += 1
        else:
            self.player_defensive_streak = 0
        if self.enemy_state == "Defensive" and self.player_defensive_streak >= 4:
            self.enemy_state = "Offensive"
            self.enemy_offensive_days_left = random.randint(2, 3)
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
                losses['infantry'] += random.randint(80, 180)
                losses['tanks'] += random.randint(2, 6)
                losses['vehicles'] += random.randint(5, 12)
                losses['artillery'] += random.randint(1, 4)
                integrity_change -= random.randint(5, 12)
                outcome += "Enemy launched an offensive! Your forces suffered extra losses.\n"
        else:
            self.enemy_disruption += 3
            is_failed = (shortfalls['fuel'] > daily_needs['fuel'] * 0.4 or shortfalls['rifle_ammo'] > daily_needs['rifle_ammo'] * 0.4 or shortfalls['gun_ammo'] > daily_needs['gun_ammo'] * 0.4)
            if is_failed:
                outcome = "Offensive Failed"; integrity_change -= 25; self.offensive_days_counter = 0
                losses = {k: random.randint(int(getattr(self, f"start_{k}")*m1), int(getattr(self, f"start_{k}")*m2)) for k, m1, m2 in 
                          [('infantry',0.03,0.05), ('tanks',0.05,0.1), ('vehicles',0.03,0.06), ('artillery',0.02,0.05)]}
            else:
                outcome = "Offensive Succeeded"; self.offensive_days_counter += 1; self.frontline_distance += 1
                loss_multiplier = 0.5 if self.is_weakness_identified else 1.0
                losses = {k: int(random.randint(int(getattr(self, f"start_{k}")*m1), int(getattr(self, f"start_{k}")*m2)) * loss_multiplier) for k, m1, m2 in 
                          [('infantry',0.015,0.025), ('tanks',0.02,0.05), ('vehicles',0.01,0.03), ('artillery',0.0,0.02)]}
        for k, v in losses.items(): setattr(self, k, max(0, getattr(self, k) - v))
        self.frontline_integrity = max(0, min(100, self.frontline_integrity + integrity_change))
        if self.frontline_integrity <= 0: self.game_over = True; outcome = "DEFEAT: Frontline integrity collapsed."
        elif self.infantry <= 0: self.game_over = True; outcome = "DEFEAT: No infantry left to hold the line."
        elif self.offensive_days_counter >= 3: self.game_over = True; self.victory = True; outcome = "VICTORY! The enemy line is broken!"
        self.is_route_secured = self.is_weakness_identified = self.is_consumption_forecasted = False
        return {"outcome": outcome, "losses": losses, "consumption": daily_needs, "integrity_change": self.frontline_integrity - initial_integrity, "convoy_event": convoy_event_log, "enemy_state": self.enemy_state}
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
        if convoy_type == 'Train': self.rail_cooldown = 3; self.enemy_disruption += 5
        for res, amt in cargo.items(): setattr(self, f"depot_{res}", getattr(self, f"depot_{res}") - amt)
    def apply_reinforcements(self, choice):
        if choice == 1: self.infantry += 2000; self.depot_rifle_ammo += 1500
        elif choice == 2: self.tanks += 50; self.vehicles += 100; self.depot_gun_ammo += 1000
        elif choice == 3: self.vehicles += 50; self.depot_fuel += 1000; self.depot_rations += 1000
        self.reinforcement_timer = random.randint(5, 7)
