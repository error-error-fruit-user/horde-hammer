# Horde Hammer

> **AI notice:** this project is developed with the help of AI. Much of the code and documentation was written with [Claude](https://claude.ai) (Anthropic), working under my direction and review. Commits that Claude helped write carry a `Co-Authored-By: Claude` trailer, so you can see which ones in the history.

A ZScript library for GZDoom/UZDoom that brings the systems of Call of Duty zombies maps to Doom mods: rounds and spawning, points, buyable doors and wall buys, the mystery box, perks, power-up drops, last stand and revive, spectating and the HUD.

It is being extracted from [Nacht des Schreckens](https://github.com/error-error-fruit-user/nacht-des-schreckens), which will be the first map built on it. Horde Hammer ships no weapons and no copyrighted game assets; games bring their own.

**Status:** early. Nothing is usable yet.

## Using it (planned)

Load the library before your game:

```
uzdoom -iwad freedoom2.wad -file horde-hammer.pk3 your-map.pk3
```

Your game sets its player class and status bar in its own `MAPINFO`, places Horde Hammer's map things (`HH_` classes, listed under "Horde Hammer" in Ultimate Doom Builder), and adds weapons by subclassing `HH_Weapon`. [spawn-room](https://github.com/error-error-fruit-user/spawn-room) is a template to start a new map or map pack from.

## License

[0BSD](LICENSE): use it for anything, no credit required.
