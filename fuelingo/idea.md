
# Logistics Command: Game Documentation

## Overview

**Logistics Command** is a single-player, graphical military logistics simulation game built in Python (Tkinter). You play as a Logistics Commander, responsible for sustaining a frontline army during a critical offensive. The game focuses on strategic planning, resource management, and supply chain operations rather than direct combat.

## Objective

Sustain a successful offensive for **three consecutive days** while managing troop strength, morale, and a fragile supply line against a reactive enemy. Victory is achieved by maintaining this streak; defeat occurs if your frontline integrity or infantry drops to zero.


## Gameplay Loop

---

## Project Structure & Refactoring

To improve clarity and maintainability, the codebase has been refactored:

- `main.py`: Main entry point, contains only the application logic and UI orchestration.
- `game_logic.py`: Contains the `GameLogic` class with all game mechanics and state management.
- `windows.py`: Contains all Tkinter window classes (`DailySummaryWindow`, `DispatchWindow`, `ReinforcementWindow`) for pop-up dialogs and UI components.

Recent changes:
- Game logic and window classes have been exported to their own files.
- The daily summary window now pops up on the right half of the main window for improved UX.

Each day (turn) consists of:
1. **Assess Situation:** Review dashboard for army, depot, frontline, and intel status.
2. **Intel Actions:** Spend Intel points on special operations (see below).
3. **Set Army Stance:** Choose Defensive or Offensive for the day.
4. **Manage Convoys:** Dispatch supply convoys (Truck/Train) from depot to frontline.
5. **End Day:** Resolve events and review After Action Report.

---

## Game Systems

### Army & Integrity
- **Units:** Infantry, Tanks, Vehicles, Artillery
- **Frontline Integrity:** 0–100, represents morale and combat effectiveness. Decreases from supply shortages and combat; can recover in Defensive stance. If it reaches zero, you lose.
- **Dynamic Consumption:** Daily supply needs scale with unit counts.

### Resource Management
- **Primary Supplies:**
    - Fuel (Tanks, Vehicles)
    - Rations (All units)
    - Rifle Ammo (Infantry)
    - Gun Ammo (Tanks, Artillery)
- **Intel:**
    - Earned daily in Defensive stance
    - Spend on tactical actions:
        - **Secure Route (10):** Reduces convoy ambush chance
        - **Identify Weakness (25):** Reduces casualties on next successful offensive
        - **Forecast Consumption (5):** Removes random variance from next day's supply needs

### Logistics Network
- **Convoys:**
    - **Trucks:** Small, flexible, always available
    - **Train:** Large, cooldown after use
- **Supply Line Distance:** Starts at 2 days; increases after each successful offensive

### Enemy Actions
- **Enemy State:**
    - Default is Defensive
    - If player remains Defensive for 4+ days, enemy switches to Offensive for 2–3 days
    - During enemy Offensive, player suffers extra losses and reduced integrity
    - Enemy returns to Defensive after offensive duration
- **Enemy Interdiction:**
    - Disruption increases with player offensives and train use, raising ambush risk

### Dynamic Events
- **Randomized Start:** Unit counts vary each game
- **Reinforcements:** Every 5–7 days, choose one of three packages to shape your army

---

## User Interface

- **Dashboard:** Resizable, adaptive layout
- **Army Dots:** Visual grid for unit strength (dots disappear as losses occur)
- **Supply Graph:** 30-day history, filterable by resource, color-coded by stance
- **Convoy Visualization:** Shown under depot/intel section
- **Footer Actions:** All main actions (stance, convoy, intel, end day, help) are spread horizontally at the bottom
- **Help Button:** A '?' button opens a popup window explaining all intel actions and the difference between trucks and train convoys
## Help & Info Popup

Click the "?" button in the footer to open a help window. The popup explains:

- **Intel Actions:**
    - Secure Route (10 Intel): Reduces the chance of convoy ambush for the next day.
    - Identify Weakness (25 Intel): Reduces casualties on your next successful offensive.
    - Forecast Consumption (5 Intel): Removes random variance from tomorrow's supply needs, allowing perfect planning.

- **Convoy Types:**
    - Trucks: Small, flexible, always available. Good for frequent, modest resupply.
    - Train: Large, delivers massive supplies in one trip, but has a cooldown after use. Using trains increases enemy disruption and ambush risk.
- **Pop-ups:** After Action Reports and Reinforcement choices are modal

---

## Win/Loss Conditions

- **Victory:** 3 consecutive successful Offensive days
- **Defeat:**
    - Frontline Integrity = 0
    - Infantry = 0

---

## Technical Notes

- Built with Python 3 and Tkinter
- Main logic: `main.py` (see `GameLogic` and `LogisticsCommandGUI` classes)
- UI and game state are tightly integrated for a seamless experience

---

## Changelog

- Added enemy state logic (Defensive/Offensive)
- Convoy visualization moved under depot/intel
- Footer layout for all action buttons

---

For further details, see code comments in `main.py`.