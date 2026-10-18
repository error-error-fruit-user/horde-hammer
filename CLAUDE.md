# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**Horde Hammer** (prefix `HH`) is a ZScript library for GZDoom/UZDoom that gives any mod the systems of a Call of Duty zombies mode: rounds and spawning, points, buyable doors and wall buys, the mystery box, perks, power-up drops, last stand and revive, spectating and the HUD/overlays. It is being extracted from the hard-coded `zmd` code in `../nacht-des-schreckens` (Nacht des Schreckens, the first map built on it), which will then depend on it. **spawn-room** (`../spawn-room`, its own repo) is the template project for zombies maps and map packs built on Horde Hammer; it gets filled in once the library works. Planned work is in `secrets/TODO.md` (local, untracked); work that spans the projects in `..` is in `../TODO.md`.

Horde Hammer ships **no weapons**. It has the weapon *base* class and the weapon hooks (box pool, wall buys, last stand pistol), and weapons are drop-in packages that a game adds (nacht's World at War weapons are the first set). It also ships **no copyrighted game assets**: anything ripped from World at War stays in nacht, and the library's own sprites and sounds are placeholders a game replaces or original or freely licensed work.

## Commands

- Pack: `python3 publish.py` (once it is copied from `../nacht-des-schreckens/publish.py`; change `PACKAGE`, `NAME` and `LICENSES` at its top) zips the library folder into `published/horde-hammer.pk3`. It is dependency-free Python 3.8+, reproducible (sorted, fixed timestamps), and warns about case collisions, lump names over 8 characters, bad sprite names and SNDINFO entries naming missing files (`--strict` fails on them).
- Play: load the library before the game, `uzdoom -iwad freedoom2.wad -file horde-hammer.pk3 nacht.pk3`. GZDoom/UZDoom also load a plain folder with `-file <folder>`, which skips packing while developing (`../tdl/uzdoom.sh` wraps the flatpak UZDoom). tdl, the launcher in `../tdl`, is used to play the built pk3s.
- Logs: `+logfile hh.log` (or `-stdout`) and `+developer 1`; a VM abort prints a ZScript stack trace, which is the first thing to look at for a crash.
- Version control is **jj** (colocated with git). `secrets/commit.sh "msg" [--claude]` commits and moves the `main` bookmark; use `--claude` for work Claude helped write (adds the Co-Authored-By trailer). `secrets/push.sh` pushes `main` as `error-error-fruit-user` with `secrets/token.txt` or, if there is none, the shared `../token.txt`. Both run from anywhere in the project.

## Conventions

The library follows the style of the engine's own ZScript (`gzdoom.pk3`, UZDoom's `uzdoom.pk3`) so it reads like the API it calls. nacht's `zmd` code is all lowercase (`a_startSound`, `self.owner.setCamera`, `chan_5`); fix that when porting a file instead of copying it as is.

- **Names**: classes, structs, enums, methods, properties and engine calls in PascalCase as the engine declares them (`HH_Rounds`, `override void PostBeginPlay()`, `Super.Tick()`, `A_StartSound`, `Level.CreateActorIterator`, `TexMan.CheckForTexture`, `Inventory.MaxAmount`). Fields and locals camelCase. Constants and enum values UPPER_CASE (`CHAN_5`, `BT_USE`, `MAXPLAYERS`, `const SWITCH_DELAY = 5`). Keywords lowercase (`class`, `override`, `let`, `foreach`). Actor flags uppercase (`+SOLID`, `+INVENTORY.UNDROPPABLE`). Sprite names in state blocks uppercase (`PLNE A 1;`).
- **Prefixes**, so nothing collides with the engine, the game or other mods: classes `HH_`, CVARs `hh_`, network and interface event names `hh_`, logical sound names `hh/...`, LANGUAGE ids `HH_...`, TIDs and DoomEdNums from documented ranges (see `secrets/TODO.md` for the ones to pick). Sprite names are a global 4-character namespace: keep a list of the ones the library uses and check each new one against the engine's and the IWADs'.
- **Files**: engine lumps at the pk3 root in uppercase with `.txt` or `.zs` (`ZSCRIPT.zs`, `MAPINFO.txt`, `SNDINFO.txt`, `CVARINFO.txt`, `MENUDEF.txt`, `LANGUAGE.txt`, `GLDEFS.txt`, `KEYCONF.txt`, `TEXTURES.txt`), ZScript under `zscript/hh/` in lowercase snake_case files, one main class per file, named after it (`HH_MysteryBox` in `zscript/hh/mystery_box.zs`). Assets under `sprites/hh/`, `sounds/hh/`, `graphics/hh/`, so a game's own folders never mix with them. Icons and HUD pictures go in `graphics/`, not `sprites/`. Strings players read go in `LANGUAGE.txt` (`"$HH_GAME_OVER"`), not in code.
- **A library never takes over the game.** Its `MAPINFO.txt` only adds event handlers (`GameInfo { AddEventHandlers = ... }`, which merges). The player classes, status bar, skills, episodes and maps belong to the game (or the template). Nothing in the library may name a game's class, TID or map: nacht's intro, plane and barrel stay in nacht, and the library offers hooks (virtual methods, events, map things with arguments, CVARs or a settings handler) instead of constants like `zmd_Player.liveTid = 15`.
- **Map things** carry Ultimate Doom Builder hints in their `Default` block (`//$Category "Horde Hammer"`, `//$Title`, `//$Sprite`, `//$Arg0 "..."`), so mappers see named things and arguments instead of raw numbers.
- **Weapons are discovered, not listed.** The box, wall buys and last stand find weapons by walking `AllActorClasses` for `HH_Weapon` subclasses and reading their properties (box weight, cost, last stand eligibility), so dropping a weapon package into a game needs no edit to a central list.

## Multiplayer and safety rules

GZDoom/UZDoom multiplayer is peer-to-peer lockstep: every machine runs the same play code and must reach the same state, or the game desyncs, and any VM abort (null access, array out of bounds) ends the session for everyone. nacht crashes in multiplayer today, and its known causes are listed in `../nacht-des-schreckens/secrets/TODO.md`. Every piece of ported code gets checked against these rules:

- **Play scope never reads `consolePlayer`.** It differs on each machine, so state written from it desyncs. Only `ui` code (`RenderOverlay`, status bar `Draw`, `UiTick`) may use it.
- **Input goes `InputProcess` → `EventHandler.SendNetworkEvent("hh_...")` → `NetworkProcess`**, and `NetworkProcess` checks `e.Player` is in game, its `mo` exists and the item it needs exists before touching anything.
- **Every lookup that can fail is checked**: `ActorIterator.Next()`, `FindInventory`, `EventHandler.Find`, `players[i].mo`, `playeringame[i]`. A missing map thing gives a console warning, never an abort.
- **Per-player arrays are `MAXPLAYERS` long** (never `[4]`), and loops over players skip the ones not in game. Code must also work with one player and with a player who joins late or leaves.
- **Randomness in play scope uses named RNGs** (`Random[HH_Box](...)`), which stay in sync; cosmetic effects can use `SXF_CLIENTSIDE` and ui-only state.
- Test in multiplayer on one machine before calling a change done: one UZDoom with `-host 2 -file ...`, another with `-join 127.0.0.1 -file ...`.

## Working in this repo

- Ask before editing project files (standing preference of the repo owner).
- `secrets/` (`commit.sh`, `push.sh`, `TODO.md`, any token) and `published/` are local/untracked; don't commit them, and never read `token.txt` (here or in `..`).
- Keep the AI notice at the top of `README.md` (the same one tdl, nacht and spawn-room carry).
- The library is **0BSD** (`LICENSE`). Only code that is ours or under a license at least as permissive (0BSD, MIT-0, CC0, Unlicense, public domain) may come in; MIT/BSD/zlib code would need its notice kept, so ask first. nacht's quick kick is adapted from NTM's, whose license is unknown, so it stays out (see `secrets/TODO.md`). nacht's code itself is ours to relicense, apart from what its readme credits to others.
