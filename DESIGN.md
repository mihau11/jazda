# Tankette Commander — Design

## Concept

A fictional "lately invented" one-man tankette, in the spirit of the Italian L3/33 or Polish TKS. The player is simultaneously driver, gunner, and commander — no crew abstraction needed, since it's diegetically a one-man vehicle.

## View

- Player is locked to the gunner's position at all times.
- Two view modes, toggled with **Z**: wide periscope (situational awareness, binocular-style two-circle vignette) and narrow, circular-vignetted gun sight with a Mauser-style post reticle (precision aiming).
- Periscope pan and gun traverse are each independent offsets *relative to hull facing* — like optics/a turret actually bolted to the tank, turning the hull sweeps both along with it, but panning/traversing still works independently on top of that (panning the periscope never moves the gun and vice versa). Gun traverse is limited to a narrow arc (**±7 degrees** from hull-forward) — this fictional tankette's mount, not a full 360-degree turret. Gun elevation always affects the gun (even while the periscope is on screen, since it stays laid), but only the gun-sight picture tilts with it (a y-shear pitch approximation) — the periscope stays level regardless.
- Controls work in both view modes at once, at different speeds: **arrows** are a fixed, coarse traverse/elevation rate; **I/J/K/L** (I/K elevate, J/L traverse) are a slow, precise fine-aim rate, cycled through three tiers by **X**. Whichever sight is currently on screen (periscope or gun sight) is what arrows/J/L traverse; Up/Down/I/K always elevate the gun specifically. Gun-sight controls (both coarse and fine) run at quarter speed compared to the periscope, since the narrow zoomed picture needs finer handling.

## Movement — no WSAD

T-34-style clutch-brake steering: there is no direct "turn left/right" input. Each track has its own 3-position lever — **Drive** (coupled to the engine), **Declutched** (freewheels — no engine thrust, no clutch drag), **Brake** (actively hauled to a stop, regardless of throttle) — and the hull's linear/angular speed derive from combining the two tracks' resulting speeds. This is a deliberate simulation-first choice over arcade-style tank controls.

- Each track carries a persistent speed rather than snapping to a target: under Drive the engine keeps adding a small constant push every frame the throttle is held, so the track just keeps accelerating -- there's no fixed top speed, only a small always-on rolling-friction drag (also felt under Declutched, and by the whole vehicle) that it climbs toward asymptotically, so long straightaways reward patience with a genuinely higher top end rather than hitting a governor; under Declutched the track holds steady bar that same friction (the clutch itself adds no resistance); under Brake it's hauled toward zero fast. This is what makes the combinations feel distinct rather than all reducing to the same "half speed": both Drive = normal driving, gradually building up speed; both Declutched = a slow coast to a stop; both Brake = a hard stop in place, even with the throttle held; one Drive + one Declutched = a turn that starts gentle and gradually tightens as the free track's speed bleeds off; one Drive + one Brake = an immediate, sharp pivot that bleeds speed fast.
- Levers are sticky, absolute-position keys (like a real lever, they stay where you put them) — left track: **1**=Drive **2**=Declutched **3**=Brake; right track: **0**=Drive **9**=Declutched **8**=Brake (deliberately inverted from the left track's order). Both default to Drive.
- **Space** throttles forward, **C** throttles reverse — the levers decide whether a track *follows* the throttle at all, not whether the tank moves.

## Graphics

- Minimalistic 2.5D raycasting, Doom/Wolfenstein-style rendering.
- Ada + an SDL2 binding for window/input/framebuffer; raycasting math implemented directly in Ada.
- Walls, floor, ceiling, and entity sprites render as flat procedural colors by default, with no assets required. Optionally, the player can drop `.bmp` files into an `assets/` folder to texture-map any of these instead (see `assets/README.md`) -- a deliberate, opt-in exception to the "no external assets" rule elsewhere in this project (audio remains fully synthesized either way).

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

- A main menu opens the game: **1** starts a normal Mission, **2** starts Test Drive, **3** starts Trolling -- Test Drive and Trolling both use the same map-building flow below but skip mission/contact spawning (no win/loss condition, just free driving/aiming practice); Trolling is deliberately undefined beyond that for now, a reserved slot for whatever odd one-off idea comes up next, so it doesn't have to get bolted onto Mission or Test Drive's already-settled behavior.
- Before a mission starts, the player builds the map themselves: pick a size, then place terrain obstacles (wall/pillar/barrier) on a top-down grid. The remaining free interior space converts live into a 1-11 difficulty number — more open space is harder, since it gives contacts better sightlines and the player less cover.
- Difficulty sets the mission's contact quota and how often contacts arrive: harder missions get more contacts, spawning more frequently. Contacts (infantry, rarer AT guns) are placed by the game at random free map cells over time, not by the player and not all at mission start — each spawn immediately fires a radio report per the spawn-detection system.
- Radio reports accumulate over time, revealing contacts (infantry squads, AT guns) at specific azimuths as they're spotted.
- The player chooses which contacts to engage, avoid, or scout — this is a contact list to resolve, not a linear corridor of scripted encounters.
- **Win/loss conditions**: loss on player destruction (unchanged); win once every contact in the mission's quota has spawned and been destroyed — the full contact list resolved. (Time-limit and extraction-point alternatives were considered but not chosen.)
