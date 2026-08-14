# Tankette Commander — Design

## Concept

A fictional "lately invented" one-man tankette, in the spirit of the Italian L3/33 or Polish TKS. The player is simultaneously driver, gunner, and commander — no crew abstraction needed, since it's diegetically a one-man vehicle.

## View

- Player is locked to the gunner's position at all times.
- Two view modes, toggled with **Z**: wide periscope (situational awareness, binocular-style two-circle vignette) and narrow, circular-vignetted gun sight with a Mauser-style post reticle (precision aiming).
- Periscope pan and gun traverse are each independent offsets *relative to hull facing* — like optics/a turret actually bolted to the tank, turning the hull sweeps both along with it, but panning/traversing still works independently on top of that (panning the periscope never moves the gun and vice versa). Gun traverse is limited to a narrow arc (**±7 degrees** from hull-forward) — this fictional tankette's mount, not a full 360-degree turret. Gun elevation always affects the gun (even while the periscope is on screen, since it stays laid), but only the gun-sight picture tilts with it (a y-shear pitch approximation) — the periscope stays level regardless.
- Controls work in both view modes at once, at different speeds: **arrows** are a fixed, coarse traverse/elevation rate; **I/J/K/L** (I/K elevate, J/L traverse) are a slow, precise fine-aim rate, cycled through three tiers by **X**. Whichever sight is currently on screen (periscope or gun sight) is what arrows/J/L traverse; Up/Down/I/K always elevate the gun specifically. Gun-sight controls (both coarse and fine) run at quarter speed compared to the periscope, since the narrow zoomed picture needs finer handling.

## Movement — no WSAD

T-34-style differential steering: there is no direct "turn left/right" input. Turning is achieved by declutching (disengaging) one track from the engine, same as the real mechanism — the hull's linear/angular speed derive from combining the two tracks' speeds (a track's speed is the throttle speed unless declutched, then zero). This is a deliberate simulation-first choice over arcade-style tank controls.

- **Q** declutches the right track (hull curves right), **E** declutches the left (curves left).
- **Space** throttles forward, **C** throttles reverse.

## Graphics

- Minimalistic 2.5D raycasting, Doom/Wolfenstein-style rendering.
- Ada + an SDL2 binding for window/input/framebuffer; raycasting math implemented directly in Ada.

## HUD — deliberately minimal

- No map, no radar, no on-screen enemy markers.
- The header shows a 3-digit azimuth number (0=north, 90=east, clockwise) for the current world-facing direction, and a small hull-icon indicator (rectangle + red line) showing the periscope/gun's offset from hull-forward.
- Situational awareness comes entirely from **text-based radio reports** (e.g. "Infantry squad spotted at 271"), triggered once per entity when it *spawns* into the world (not when the player spots it) — the bearing given is from the player's position at that moment. The player must remember reported azimuths and mentally cross-reference them against the azimuth number — there is no persistent marker.

## Weapons

- Hull/coax machine gun (**s**) — anti-infantry use only; does nothing against AT guns.
- 20mm-class autocannon (TKS-style) (**a**+**s**) — gives the tankette real offensive capability in AT-gun duels, rather than those encounters being pure stealth/avoidance; also kills infantry.
- Both weapons share the gun's aim: a hitscan fired along the gun's current laid direction (hull facing + gun offset), regardless of which sight is currently on screen — the coax shares the main gun's axis, so it's always aimed wherever the gun is, not wherever the periscope happens to be looking.

## Combat / damage model — kept intentionally simple

- **Infantry**: a persistent, close-range threat. If an infantry squad closes to point-blank range, it fires an (abstracted/"imaginary") RPG-type attack that destroys the tank in one hit. This is a distance-gated instant kill, not a simulated weapon.
- **AT guns**: a rarer, long-range threat. An AT gun needs 3 seconds of continuous line of sight on the player before its first shot; once locked on, it fires again every 5 seconds for as long as sight holds (losing sight resets it to needing a fresh 3-second acquisition). The tankette can absorb **3 hits**; the **4th hit destroys it**. No component/sub-system damage model — just a hit counter, shown as 3 pips in the header that fill in red per hit, plus a brief screen flash on each non-fatal hit.
- Either kind of death freezes all controls and fills the screen solid red.

## Missions

- Each mission is a bounded map/area.
- Radio reports accumulate over time, revealing contacts (infantry squads, AT guns) at specific azimuths as they're spotted.
- The player chooses which contacts to engage, avoid, or scout — this is a contact list to resolve, not a linear corridor of scripted encounters.
- **Open question**: exact win/loss conditions for a mission (e.g. all contacts resolved vs. time limit vs. reaching an extraction point) — not yet decided.
