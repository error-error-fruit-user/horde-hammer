# AGENTS.md

Horde Hammer quick context for OpenCode. `CLAUDE.md` is the fuller spec — read it before a
non-trivial change; this file is the map of the place.

## What this is

**Horde Hammer** (prefix `HH`) is a ZScript library for UZDoom that gives any mod the systems of a
Call of Duty zombies mode: rounds and spawning, points, buyable doors and wall buys, the mystery
box, perks, power-up drops, last stand and revive, spectating and a movable HUD. It was ported
from the hard-coded `zmd` code in `../nacht-des-schreckens`, which now depends on it.
`../spawn-room` is the template project built on it.

It ships **no weapons** (only the `HH_Weapon` base class and the hooks that find weapons) and **no
copyrighted assets**: its sprites are placeholders drawn by `tools/placeholders.py`, its sounds are
aliases of Doom's, and a game replaces them.

## Commands

- Pack: `python3 publish.py` → `published/horde-hammer.pk3` (dependency-free, reproducible; warns
  about case collisions, lump names over 8 characters, bad sprite names and SNDINFO entries naming
  missing files; `--strict` fails on them).
- Generators: `python3 tools/placeholders.py` (placeholder sprites and HUD pictures) and
  `python3 tools/testmap.py` (`test/maps/hhtest.wad`). Edit the scripts, not their output.
- `secrets/check.sh [files...]` — compiles the library (and anything after it) with `-norun` and
  prints script errors. **Run it after every ZScript change.** (`-norun` always exits 57; the
  script judges by the log.)
- `secrets/run.sh [-t seconds] [-m map] "console commands; quit" [files...]` — plays a map
  headless (offscreen video, under `script`, since UZDoom only behaves with a terminal) and prints
  the output. With `test` loaded and `-m HHTEST`, the test map and the `hhtest_*` network events
  drive the game: `netevent hhtest_state` prints round, points, weapons and perks;
  `hhtest_use:<class>` touches and uses the nearest thing of that class; `hhtest_down`;
  `hhtest_killall`. **Always end with `wait 2; quit`** (a command right before `quit` may never
  run). `screenshot_dir <dir>; ...; screenshot` takes real screenshots of the HUD.
- `secrets/net.sh [-t seconds] [-m map] "host commands" "joiner commands" [files...]` — a
  two-player game on 127.0.0.1, both headless, printing both outputs: the two machines'
  `hhtest_state` lines must match line for line, or the game has desynced.
- `secrets/acc.sh source.acs output.o` — compiles ACS with the ACC in `secrets/acc/` (through
  Wine), with `acs/` on the include path. `test/acs/hhtest.o` is built from `test/acs_src/hhtest.acs`.
- Logs: a VM abort prints a ZScript stack trace; in a headless run it leaves the game stuck in the
  console, which shows up as a timeout.
- Version control is **jj** (colocated with git): `secrets/commit.sh "msg" [--claude] [--opencode]`, then
  `secrets/push.sh`.

## Layout

- `hh/` is the pk3: `ZSCRIPT.zs` (`version "5.0.0"`, the latest UZDoom) includes
  `zscript/hh/*.zs`; `MAPINFO.txt` adds the event handlers (`HH_SettingsHandler` first, so the
  others can read settings in `WorldLoaded`) and the DoomEdNums 27000-27099; `CVARINFO.txt`,
  `LANGUAGE.txt`, `SNDINFO.txt`, `KEYCONF.txt`, `MENUDEF.txt` (generated menu layout: one block per
  HUD part).
- Everything per player hangs off `HH_InventoryManager` (inventory_manager.zs): carried weapons,
  perks, the down/spectating/game over flags and `hud` (`HH_HudState`: point deltas, hint, revive
  bar, kept in play so every machine has it). The game-wide handlers are `HH_Rounds` (phases:
  waiting, round, delay, repulsion, game over), `HH_Spawning` (zones, the zombie list,
  retargeting), `HH_Players` and `HH_Input` (entering, leaving, respawning, the network events
  behind every key), `HH_PointsHandler`, `HH_DropPool`, `HH_MysteryBoxHandler`, `HH_HudHandler`
  (all drawing, in `RenderOverlay`, over any status bar), `HH_Events` and `HH_SettingsHandler`.
  `HH_ControllerLayout` (controller.zs) offers the zombies pad layout once, from
  `HH_Input.InputProcess`, through a `MessageBoxMenu`.
- `acs/hh.acs` (not packed) wraps every `HH_Acs` call for map scripts. `test/` (not packed) is the
  test map, the test-only handler and defaults, a drop-in test weapon (`zscript.rifle`,
  `sndinfo.rifle`) and the ACS test library.

## Settings

Every setting is a CVar, but server settings start at -1 (or "") meaning "the game's default", and
code reads them only through `HH_Settings.Int/Float/Bool/Str("hh_...")`, never by name. Defaults
live in `HH_Defaults.Fill` (settings.zs); a game subclasses `HH_Defaults` and the most derived
subclass wins — this is the only way for a game to set the library's defaults (redefining a CVar in
another CVARINFO is a fatal startup error, and DEFCVARS only loads from the IWAD). When adding a
setting: add it to `CVARINFO.txt` at -1 with a comment, and its default to `HH_Defaults.Fill`.

A name must not match a class name, whatever the case (`hh_regen` clashed with `HH_Regen`), nor a
KEYCONF alias (a CVar named like a key command shadows it in the console: `hh_kick` the setting
broke `hh_kick` the key, so the setting is `hh_kick_enabled`). A menu `Option` can't drive a string
CVar whose default is empty (it shows "unknown" and writes garbage): give a game a numeric switch
of its own and turn it into a setting in its `HH_Defaults`. User CVars (the HUD) can't be read by
name in ZScript either: `CVar.FindCVar`.

## Conventions

The library follows the style of the engine's own ZScript (`uzdoom.pk3`) so it reads like the API
it calls; nacht's `zmd` code was all lowercase and is restyled as it moves.

- **Names**: classes, structs, enums, methods, properties and engine calls in PascalCase as the
  engine declares them (`HH_Rounds`, `override void PostBeginPlay()`, `A_StartSound`,
  `Level.CreateActorIterator`). Fields and locals camelCase. Constants and enum values UPPER_CASE
  (`CHAN_AUTO`, `BT_USE`, `MAXPLAYERS`, `const DOUBLE_TAP_TICS = 35`). Keywords lowercase. Actor
  flags uppercase (`+SOLID`, `+INVENTORY.UNDROPPABLE`). Sprite names in states uppercase
  (`HHBX A -1;`).
- **Explicit `self.`** on every field and method of the object itself (the owner's preference; the
  engine's code leaves it out, ours doesn't).
- **4 spaces**, never tabs.
- **Identifiers ignore case**, so a field, method, constant, type or CVar must not share a name with
  any other in scope in any case (`cooldown` and `COOLDOWN`, `log` and `Log()`, `weapon` and
  `Weapon` all failed). `Stop`, `color`, `name`, `event` (in ACS) and `round` (in ACS) are reserved.
- **Keep nacht's names for mechanics** (repulsion is repulsion), restyled but not renamed.
- **Prefixes**: classes `HH_`, CVars `hh_`, network and interface events `hh_`, sounds `hh/...`,
  LANGUAGE ids `HH_...`, sprites `HH??`, DoomEdNums 27000-27099. The library reserves no TIDs: map
  things say what they mean with arguments.
- **Files**: engine lumps at the pk3 root in uppercase with `.txt` or `.zs`; ZScript in
  `zscript/hh/` in lowercase snake_case; assets under `sprites/hh/` and `graphics/hh/` (HUD
  pictures in `graphics/`, not `sprites/`). Player-facing strings in `LANGUAGE.txt`.
- **A library never takes over the game.** `MAPINFO.txt` only adds handlers and editor numbers;
  player classes, status bar, skills and maps are the game's. Nothing names a game's class, TID or
  map; games hook in through `HH_Defaults`, subclasses, events and ACS calls.
- **Map things** carry Ultimate Doom Builder hints (`//$Category "Horde Hammer"`, `//$Title`,
  `//$Sprite`, `//$Arg0`).
- **Weapons and drops are discovered, not listed**: `AllActorClasses` and their properties
  (`HH_Weapon.BoxWeight`, `HH_Drop.Pool`). There is no `Class.IsAbstract()` in this engine, so a
  zero property is what keeps a base class out.

## Multiplayer and safety rules

UZDoom multiplayer is peer-to-peer lockstep: every machine runs the same play code and must reach
the same state, or the game desyncs, and any VM abort ends the session for everyone. Every change
is checked against these rules, and against `secrets/net.sh`:

- **Play scope never reads `consolePlayer`.** Only `ui` code (`RenderOverlay`, `UiTick`,
  `InputProcess`) may.
- **Input goes `InputProcess` → `EventHandler.SendNetworkEvent("hh_...")` → `NetworkProcess`** (or a
  KEYCONF alias of `netevent`), and `NetworkProcess` checks the player is in game, has a body and
  the item it needs.
- **Every lookup that can fail is checked**: iterators, `FindInventory`, `EventHandler.Find`,
  `players[i].mo`, `playeringame[i]`.
- **Per-player arrays are `MAXPLAYERS` long** (64 in UZDoom), and loops over players skip the ones
  not in game. Code works with one player, and with players who join late or leave.
- **Randomness in play scope uses named RNGs** (`Random[HH_Box](...)`).
- **No unbounded loops**: zmd froze every machine with a loop that never found a player to
  spectate.
- Choosing a weapon while damage is being dealt doesn't stick; do it on the next tick (see
  `HH_LastStand.pistolOut`).
- Save games: handler and item fields are saved; anything rebuilt at map start checks
  `e.IsSaveGame`; ui state is `transient ui`.

## Working in this repo

- Ask before editing project files (standing preference of the repo owner).
- `secrets/` (scripts, `acc/`, `run/`, `TODO.md`, any token) and `published/` are local/untracked;
  don't commit them, and never read `token.txt` (here or in `..`).
- Keep the AI notice at the top of `README.md` (the same one tdl, nacht and spawn-room carry).
- The library is **0BSD** (`LICENSE`). Only code that is ours or under a license at least as
  permissive (0BSD, MIT-0, CC0, Unlicense, public domain) may come in; MIT/BSD/zlib code would need
  its notice kept, so ask first. The kick is our own (nacht's was adapted from NTM's, whose license
  is unknown).
- Planned work, including what still needs a person at the keys, is in `secrets/TODO.md`; work that
  spans the projects is in `../TODO.md`.
