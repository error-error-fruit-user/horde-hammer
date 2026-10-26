// The base class for zombies weapons: a magazine on top of the reserve ammo, partial reloads,
// zoom, and the properties the mystery box, wall buys and last stand read. Horde Hammer ships no
// weapons; a game's weapons subclass this (see "Drop-in weapons" in the README).

class HH_Weapon : Weapon {
    int activeAmmo;             // rounds in the magazine; the Default is the magazine's size
    int reloadFrameRate;        // tics per reload frame (FR); Speed Cola takes one off
    int fireFrameRate;          // tics per fire frame (FF); Double Tap takes one off
    bool keepPartialReload;     // a reload only takes what the magazine is missing
    bool zoomed;
    bool toggledZoom;           // the owner's hh_toggled_zoom

    meta int boxWeight;         // how often the mystery box picks it, 0 for never
    meta int lastStand;         // the pistol for going down: the highest one held wins, 0 for never
    meta bool counted;          // counts against hh_max_weapons (drinks and melee don't)
    meta class<Weapon> upgrade; // its upgraded version, which wall buys sell ammo for
    meta bool equipment;        // carried apart from the weapons (hh_max_equipment), on the equipment key
    meta class<Weapon> downed;  // given for the last stand instead, when this is the pistol
    meta int risenWeight;       // once unlocked from the roster, how often the box picks it while its
                                // player is Risen (HH_RisenPower), instead of 1; 0 for no difference

    property ActiveAmmo: activeAmmo;
    property ReloadFrameRate: reloadFrameRate;
    property FireFrameRate: fireFrameRate;
    property KeepPartialReload: keepPartialReload;
    property BoxWeight: boxWeight;
    property LastStand: lastStand;
    property Counted: counted;
    property Upgrade: upgrade;
    property Equipment: equipment;
    property Downed: downed;
    property RisenWeight: risenWeight;

    Default {
        HH_Weapon.Counted true;
        XScale 0.5;
        YScale 0.5;
        Weapon.BobStyle "InverseSmooth";
        Weapon.AmmoUse 1;
        +WEAPON.NOAUTOAIM
        +WEAPON.NOAUTOFIRE
        +WEAPON.AMMO_OPTIONAL
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        if (other.player != null) {
            let cvar = CVar.GetCVar('hh_toggled_zoom', other.player);
            self.toggledZoom = cvar != null && cvar.GetBool();
        }
    }

    void ActivateFastReload() {
        self.reloadFrameRate = max(1, self.Default.reloadFrameRate - 1);
    }

    void DeactivateFastReload() {
        self.reloadFrameRate = self.Default.reloadFrameRate;
    }

    void ActivateDoubleFire() {
        self.fireFrameRate = max(1, self.Default.fireFrameRate - 1);
    }

    void DeactivateDoubleFire() {
        self.fireFrameRate = self.Default.fireFrameRate;
    }

    action State ToggleZoom() {
        return invoker.zoomed? ResolveState("ZoomOut"): ResolveState("ZoomIn");
    }

    action void ZoomIn() {
        A_ZoomFactor(1.5);
        invoker.zoomed = true;
        invoker.BobRangeX = 0.2;
        invoker.BobRangeY = 0.2;
    }

    action void ZoomOut() {
        A_ZoomFactor(1.0);
        invoker.zoomed = false;
        invoker.BobRangeX = 1.0;
        invoker.BobRangeY = 1.0;
    }

    action void ReadyWeapon() {
        if (invoker.zoomed && !invoker.toggledZoom) {
            A_WeaponReady(WRF_ALLOWRELOAD);
        } else {
            A_WeaponReady(WRF_ALLOWRELOAD | WRF_ALLOWZOOM);
        }
    }

    action void Reload() {
        let missing = invoker.Default.activeAmmo - invoker.activeAmmo;
        if (invoker.keepPartialReload) {
            let moved = min(missing, self.CountInv(invoker.ammoType1));
            self.TakeInventory(invoker.ammoType1, moved);
            invoker.activeAmmo += moved;
        } else {
            let moved = min(invoker.Default.activeAmmo, self.CountInv(invoker.ammoType1));
            self.TakeInventory(invoker.ammoType1, moved);
            invoker.activeAmmo = moved;
        }
    }

    action void ShootBullets(double spread, int damage, int bullets) {
        A_FireBullets(spread, spread, bullets == 1? -1: bullets, damage, flags: FBF_NORANDOM);
        invoker.activeAmmo = max(0, invoker.activeAmmo - invoker.ammoUse1);
    }

    action Actor, Actor ShootProjectile(class<Actor> projectile) {
        invoker.activeAmmo = max(0, invoker.activeAmmo - invoker.Default.ammoUse1);
        Actor missile, target;
        [missile, target] = A_FireProjectile(projectile, useAmmo: false);
        return missile, target;
    }

    action State When(bool condition, StateLabel label) {
        return condition? ResolveState(label): ResolveState(null);
    }

    action State WhenZoomed(StateLabel label) {
        return invoker.When(invoker.zoomed, label);
    }

    action State WhenNotZoomed(StateLabel label) {
        return invoker.When(!invoker.zoomed, label);
    }

    action State WhenShouldZoomOut(StateLabel label) {
        return invoker.When(!invoker.toggledZoom && !(self.player.cmd.buttons & BT_ZOOM), label);
    }

    action State WhenNoActiveAmmo(StateLabel label) {
        return invoker.When(invoker.activeAmmo == 0, label);
    }

    action State WhenAnyActiveAmmo(StateLabel label) {
        return invoker.When(invoker.activeAmmo != 0, label);
    }

    action State WhenLastActiveAmmo(StateLabel label) {
        return invoker.When(invoker.activeAmmo == invoker.Default.ammoUse1, label);
    }

    action State WhenNoAmmo(StateLabel label) {
        return invoker.When(self.CountInv(invoker.ammoType1) == 0, label);
    }

    action State WhenFullAmmo(StateLabel label) {
        return invoker.When(invoker.activeAmmo == invoker.Default.activeAmmo, label);
    }

    // Reload and fire frames last as long as the weapon's frame rate (sped up by perks)
    action void FR() {
        A_SetTics(invoker.reloadFrameRate);
    }

    action void FF() {
        A_SetTics(invoker.fireFrameRate);
    }
}

// The weapons the mystery box can give: the ones in the player's weapon slots (their class's
// Player.WeaponSlot, and any weapon's own Weapon.SlotNumber), so every player class, a mod's
// included, gets its own roster. An HH_Weapon comes as often as its box weight (never at 0); any
// other weapon but melee at 1, unless it is CHEATNOTWEAPON (a mod's variant of another, like Brutal
// Doom's purist and dual ones).
class HH_WeaponPool play {
    static void Gather(PlayerPawn player, out Array<class<Weapon> > weapons, out Array<int> weights, bool withUnlocked = true) {
        weapons.Clear();
        weights.Clear();
        if (player == null || player.player == null) {
            return;
        }
        let manager = HH_InventoryManager.Of(player);
        let slots = player.player.weapons;
        for (let slot = 0; slot < PlayerPawn.NUM_WEAPON_SLOTS; ++slot) {
            for (let index = 0; index < slots.SlotSize(slot); ++index) {
                let type = slots.GetWeapon(slot, index);
                if (type == null || weapons.Find(type) != weapons.Size()) {
                    continue;
                }
                let weight = 0;
                let zombiesWeapon = (class<HH_Weapon>)(type);
                if (zombiesWeapon != null) {
                    weight = GetDefaultByType(zombiesWeapon).boxWeight;
                } else if (HH_InventoryManager.Counts(type) && (manager == null || type != manager.melee)
                        && !GetDefaultByType(type).bCheatNotWeapon) {
                    weight = 1;
                }
                if (weight > 0) {
                    weapons.Push(type);
                    weights.Push(weight);
                }
            }
        }
        // and what the player unlocked from the roster, some more often while Risen
        if (withUnlocked && manager != null) {
            let risen = player.FindInventory('HH_RisenPower') != null;
            foreach (token : manager.unlocked) {
                let type = HH_InventoryManager.UnlockedType(token);
                if (type != null && weapons.Find(type) == weapons.Size()) {
                    let weight = 1;
                    let zombiesWeapon = (class<HH_Weapon>)(type);
                    if (risen && zombiesWeapon != null && GetDefaultByType(zombiesWeapon).risenWeight > 0) {
                        weight = GetDefaultByType(zombiesWeapon).risenWeight;
                    }
                    weapons.Push(type);
                    weights.Push(weight);
                }
            }
        }
    }

    // Whether the box can give `type` to `player` at all (whether or not they hold it now)
    static bool Gives(PlayerPawn player, class<Weapon> type, bool withUnlocked = true) {
        Array<class<Weapon> > weapons;
        Array<int> weights;
        HH_WeaponPool.Gather(player, weapons, weights, withUnlocked);
        return weapons.Find(type) != weapons.Size();
    }

    // Every weapon the loaded files have, for the roster: each class not replaced by another and not
    // a variant (powered up, or CHEATNOTWEAPON: drinks) whose pickup is a sprite from the IWAD or a
    // file after it. The engine defines every game's weapons; another game's have no sprite here,
    // or one of the engine's own (before the IWAD), or one that only shares a name (rotated, not
    // a pickup's single A0).
    static void Everything(out Array<class<Weapon> > weapons) {
        weapons.Clear();
        let firstGameLump = max(0, Wads.FindLump("S_START", 0));
        foreach (type : AllActorClasses) {
            let weaponType = (class<Weapon>)(type);
            if (weaponType == null || weaponType == 'Weapon' || Actor.GetReplacement(weaponType) != weaponType) {
                continue;
            }
            let weapon = GetDefaultByType(weaponType);
            if (weapon.bCheatNotWeapon || weapon.bPowered_Up) {
                continue;
            }
            let spawn = weapon.SpawnState;
            if (spawn == null || spawn.sprite == 0) {
                continue;
            }
            let texture = TexMan.GetName(spawn.GetSpriteTexture(0));
            let lump = Wads.CheckNumForName(texture, Wads.ns_sprites);
            if (lump < firstGameLump || texture.Left(4) == "TNT1" || texture.Mid(5, 1) != "0") {
                continue;
            }
            weapons.Push(weaponType);
        }
    }

    // A weighted pick among the weapons the player doesn't hold (HH_InventoryManager.Held), other
    // than `except`; null when there is nothing left to give
    static class<Weapon> Choose(PlayerPawn player, class<Weapon> except = null) {
        Array<class<Weapon> > weapons;
        Array<int> weights;
        HH_WeaponPool.Gather(player, weapons, weights);
        let total = 0;
        for (let i = 0; i < weapons.Size(); ++i) {
            if (weapons[i] == except || (player != null && HH_InventoryManager.Held(player, weapons[i]) != null)) {
                weights[i] = 0;
            }
            total += weights[i];
        }
        if (total == 0) {
            return null;
        }
        let pick = Random[HH_Box](1, total);
        for (let i = 0; i < weapons.Size(); ++i) {
            pick -= weights[i];
            if (pick <= 0 && weights[i] > 0) {
                return weapons[i];
            }
        }
        return null;
    }

    // Any weapon to show while the box spins (the player may hold it), other than `except`
    static class<Weapon> Show(PlayerPawn player, class<Weapon> except = null) {
        Array<class<Weapon> > weapons;
        Array<int> weights;
        HH_WeaponPool.Gather(player, weapons, weights);
        if (weapons.Size() == 0) {
            return null;
        }
        if (weapons.Size() == 1) {
            return weapons[0];
        }
        let index = Random[HH_Box](0, weapons.Size() - 2);
        let exceptIndex = weapons.Find(except);
        if (exceptIndex != weapons.Size() && index >= exceptIndex) {
            ++index;
        }
        return weapons[index];
    }
}
