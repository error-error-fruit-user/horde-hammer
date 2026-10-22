# Horde Hammer

> **AI notice:** this project is developed with the help of AI. Much of the code and documentation was written with [Claude](https://claude.ai) (Anthropic), working under my direction and review. Commits that Claude helped write carry a `Co-Authored-By: Claude` trailer, so you can see which ones in the history.

A ZScript library for UZDoom that brings the systems of Call of Duty zombies maps to Doom mods: rounds and spawning, points, buyable doors and wall buys, the mystery box, perks, power-up drops, last stand and revive, spectating and a movable HUD. It works in single player and multiplayer.

It was extracted from [Nacht des Schreckens](https://github.com/error-error-fruit-user/nacht-des-schreckens), which will be the first map built on it. [spawn-room](https://github.com/error-error-fruit-user/spawn-room) is a template for starting a new map or map pack. Horde Hammer ships no weapons and no copyrighted assets; its art is placeholders and its sounds are Doom's own, until a game brings its own.

**Status:** early (0.1.0). Every system runs and is tested, but expect names to change before 1.0.

## Requirements

UZDoom 5.0 or newer (the library's ZScript is version 5.0.0). Doom 2 or Freedoom as the IWAD.

## Loading it

Load the library before the game that uses it:

```
uzdoom -iwad freedoom2.wad -file horde-hammer.pk3 your-map.pk3
```

Without the library, a game built on it stops at startup with "Unknown class HH_...".

## Making a game with it

The library adds its event handlers and nothing else: the player class, status bar, skills and maps are the game's, in the game's own `MAPINFO`. Any player class works (Horde Hammer gives its items to whoever enters). For a game with no status bar of its own, `StatusBarClass = "HH_Hud"` leaves the whole screen to Horde Hammer's HUD.

### Map things

They appear in Ultimate Doom Builder under **Horde Hammer**, with named arguments.

| Number | Class | What it is | Arguments |
|---:|---|---|---|
| 27000 | `HH_Spawner` | Where zombies come from (invisible) | 0: zone (0 spawns from the start) |
| 27001 | `HH_MysteryBoxLocation` | A place the box can be (invisible) | 0: 1 always first, -1 never first |
| 27002 | `HH_Door` | A buyable door; vanishes when bought | 0-3: zones it opens, 4: cost (0 for 1000) |
| 27003 | `HH_Debris` | The same, as a pile of debris | as the door |
| 27004 | `HH_QuickReviveMachine` | Quick Revive (solo: brings you back, 3 times) | |
| 27005 | `HH_JuggernogMachine` | Juggernog (more health) | |
| 27006 | `HH_SpeedColaMachine` | Speed Cola (faster reloads) | |
| 27007 | `HH_DoubleTapMachine` | Double Tap (faster fire, double damage) | |
| 27008 | `HH_SpectatorSpot` | Where spectators' bodies wait (optional) | |
| 27009 | `HH_GameOverCamera` | What everyone sees at the end (optional) | 0: the TID of a camera to activate and look through instead |
| 27010 | `HH_Zombie` | A zombie placed by hand | |
| 27011 | `HH_RespawnSpot` | Where players come back at a new round, instead of the player starts (optional) | 0: player (1 the first...), 0 anyone |

Wall buys have no number of their own: a game subclasses `HH_WallBuy` for each weapon, setting `HH_WallBuy.Weapon` and `HH_WallBuy.Cost`, gives it its own chalk outline sprite and a number in its `MAPINFO`.

Buying a door opens its zones, and the spawners in them start spawning. A door's TID goes along with its `door_opened` event, so a map script can open real sector doors too.

### Settings

Every setting is a CVar, listed with its meaning in `hh/CVARINFO.txt`: points and costs, zombie health, count and speed per round, spawn timing, the box, drops, revive times, and switches like `hh_kick_enabled`, `hh_auto_start` and `hh_hud_before_start` (off for a game with an intro). A host changes them like any CVar (`hh_box_cost 500`).

A game sets its own defaults by subclassing `HH_Defaults` (the engine has no other way for a mod to change a library's CVar defaults). The CVars start at -1, which means "the game's default":

```
class MyMap_Defaults : HH_Defaults {
    override void Fill(HH_SettingsHandler settings) {
        super.Fill(settings);
        settings.Set("hh_zombie_class", "MyMap_Zombie");
        settings.Set("hh_auto_start", "0");     // the map starts round 1 itself, after its intro
    }
}
```

### Keys

| Key | Does |
|---|---|
| Use | Buy what you're touching, take the box's weapon, hold next to a downed teammate to revive them; while spectating, watch the next player |
| F (`hh_kick`) | Kick |
| Q (`hh_repulse`) | Repulse: hold off the next round (everyone has to keep pressing it) |
| Drop weapon, twice | Drop the weapon in hand (costs `hh_drop_weapon_cost`) |
| 1, 2, ..., 0 | The first carried weapon, the second..., 0 for melee |

The kick and repulse keys are network events (in the controls menu under "Horde Hammer"), not `+user` buttons, so they don't clash with mods that use those. A game can replace the kick with its own (a knife bought off the wall): give the player a subclass of `HH_KickItem` with its own `Kick` state, and take the plain one away. Melee (the 0 key) is the first weapon without ammo the player starts with, so equipment they start with, like grenades, isn't taken for it.

### Controllers

The first time a player presses a controller button, Horde Hammer asks once whether to use the zombies layout (`hh_pad_layout_set` remembers the answer, and "Offer the zombies controller layout again" in Horde Hammer's options asks again). Yes rebinds these buttons, and only these:

| Button | Does |
|---|---|
| Right trigger | Fire |
| Left trigger | Zoom |
| A | Use |
| X | Reload |
| Y | Swap weapon |
| Right stick click | Kick |
| Left stick click | Sprint |
| Left bumper | Repulse |
| Right bumper, twice | Drop weapon |
| D-pad, clockwise from left | Weapons 1 to 4 |
| Start | Pause |
| Back | Main menu |

It is a question, not a default, because UZDoom already binds most of these buttons and won't let a mod's default bindings take them, and only a menu may change bindings. A game that has its own layout turns the question off with `hh_pad_layout 0` in its `HH_Defaults`.

### The HUD

Points, round, ammo, perks, power-ups, hints, the revive bar and messages are drawn on top of whatever status bar is in use. Each player places, sizes and hides every part in **Options → Horde Hammer Options → HUD Layout** (or the `hh_hud_*` CVars), with a reset at the bottom.

### Weapons

Horde Hammer has no guns. A game's weapons subclass `HH_Weapon`, which adds a magazine on top of reserve ammo, partial reloads, zoom, and frame rates that Speed Cola and Double Tap speed up:

| Property | Means |
|---|---|
| `HH_Weapon.ActiveAmmo` | The magazine's size |
| `HH_Weapon.ReloadFrameRate`, `HH_Weapon.FireFrameRate` | Tics per reload and fire frame (state frames call `FR` / `FF`) |
| `HH_Weapon.KeepPartialReload` | A reload only takes what the magazine is missing |
| `HH_Weapon.BoxWeight` | How often the mystery box gives it (0 for never) |
| `HH_Weapon.LastStand` | Going down pulls out the held weapon with the highest value (0 for never) |
| `HH_Weapon.Upgrade` | Its upgraded version, which wall buys sell ammo for |

Last stand and Max Ammo find weapons by these properties, so there is no list to edit. The box searches the player's own weapon slots (their class's `Player.WeaponSlot`, and any weapon's `Weapon.SlotNumber`), so every player class gets its own roster, a mod's included (Brutal Doom, Project Brutality): an `HH_Weapon` comes as often as its box weight, any other weapon but melee at 1, unless it is `CHEATNOTWEAPON` (a mod's variant of another, like Brutal Doom's purist and dual ones). A packaged weapon that should come from the box needs a slot. The box, wall buys and weapons lying on the floor never give a weapon the player already holds: the same class, one derived from it or one it derives from, or its upgrade.

**Weapon packages.** A weapon is easiest to share as a folder of its own that a game copies into its pk3: `weapons/<weapon>/` with its script (`<weapon>.zs`), its sound names (`sndinfo.txt`) and its sound files, plus its sprites in `sprites/weapons/<weapon>/` (sprites only load from `sprites/`). Files in folders don't load by themselves, so the game adds one line for each weapon to its root `ZSCRIPT.zs` and one to its `SNDINFO.txt`:

```
#include "weapons/colt/colt.zs"             // ZSCRIPT.zs
$include "weapons/colt/sndinfo.txt"         // SNDINFO.txt
```

Its `sndinfo.txt` names its files by path (`weapons/colt/sounds/fire.ogg`), and its script has no `version` line (only the root `ZSCRIPT.zs` does). Each weapon brings its own ammo type. Nacht des Schreckens and spawn-room lay out their weapons this way; spawn-room's rifle is a small, commented example. A weapon can also skip the two lines by putting `zscript.<weapon>` and `sndinfo.<weapon>` at the pk3's root, since root files whose names differ only in extension all load (`test/zscript.rifle` does this).

### Art, sounds and text

Everything a player sees or hears can be replaced without touching the library:

- **Sprites**: the placeholders are drawn by `tools/placeholders.py` (sprite names starting with `HH`, in `hh/sprites/hh/` and `hh/graphics/hh/`). A game ships files with the same names, or uses its own sprites in its subclasses.
- **Sounds**: every sound is a name starting with `hh/` (`hh/purchase`, `hh/round_start`...) in `hh/SNDINFO.txt`, pointing at Doom's own until a game's SNDINFO defines the same name.
- **Text**: every string is a `HH_` id in `hh/LANGUAGE.txt`; a game's LANGUAGE redefines any of them.
- **Perks**: subclass a machine for its sprite and `HH_PerkMachine.Drink` (Quick Revive also has `HH_QuickReviveMachine.SoloDrink`), and the drink for its animation: a `Sprites` state naming three sprites plays them as frames A-Z, A-Z (the perk after I) and A-B, or replace `Ready` entirely. Perk and power-up icons are pictures named `HHI??` in `graphics/hh/`; a game ships its own under the same names.
- **Drops**: subclass one (`MyMap_Instakill : HH_Instakill` with its own Spawn states) and the subclass drops instead of the original.
- **Zombies**: `HH_Zombie` walks with the IWAD's former human sprites; subclass it with your own states and set `hh_zombie_class`. A random zombie set subclasses `HH_ZombieSpawner` (like `HH_VariedZombie`, Doom's monsters).

### Map scripts and events

Map scripts call the library through `ScriptCall("HH_Acs", ...)`; `acs/hh.acs` wraps every call (`HH_CurrentRound()`, `HH_GivePoints(player, amount)`, `HH_OpenZone(zone)`, `HH_StartGame()`...). They also get events: `HH_Listen("round_started", "MyScript")` runs `MyScript` with the round as its argument whenever a round starts. The same events reach ZScript as interface events named `hh_<event>`. The events and their numbers are listed at the top of `hh/zscript/hh/events.zs`: game started, round started and ended, game over, player downed, revived, bled out and respawned, door opened, perk bought, box opened and moved, power-up taken, zone opened, and the repulse key pressed (at any time, so a game can use it too).

### With Brutal Doom or Project Brutality

Horde Hammer draws its HUD over theirs and gives its items to their player class. Turn off what they already do: `hh_weapon_switching 0` (their own weapon slots), `hh_kick_enabled 0` (their own melee), and the HUD's ammo setting to "Horde Hammer weapons" or "Never". Their monsters replace Doom's, so `HH_VariedZombie` spawns theirs.

## Multiplayer

Everything runs in lockstep on every machine, so the library never reads one machine's player in game code, checks every lookup, and sizes player arrays to `MAXPLAYERS`. Players who bleed out watch until the next round; players who join a game already going do too. The game ends when nobody is left standing.

## Building and testing

- `python3 publish.py` packs `hh/` into `published/horde-hammer.pk3` (reproducible; warns about lump name problems).
- `python3 tools/placeholders.py` redraws the placeholder art, `python3 tools/testmap.py` the test map.
- `test/` is loaded after the library for testing (never shipped): `test/maps/hhtest.wad` has one of every map thing, `test/ZSCRIPT.zs` adds console network events that drive the game (`netevent hhtest_state`, `hhtest_use:<class>`, `hhtest_down`, `hhtest_killall`), and `test/acs/hhtest.o` listens to events from ACS. Play it with `uzdoom -iwad freedoom2.wad -file hh test +map HHTEST`.

## License

[0BSD](LICENSE): use it for anything, no credit required.
