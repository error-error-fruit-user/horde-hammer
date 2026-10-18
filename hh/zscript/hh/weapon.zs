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

    property ActiveAmmo: activeAmmo;
    property ReloadFrameRate: reloadFrameRate;
    property FireFrameRate: fireFrameRate;
    property KeepPartialReload: keepPartialReload;
    property BoxWeight: boxWeight;
    property LastStand: lastStand;
    property Counted: counted;
    property Upgrade: upgrade;

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

// The weapons the mystery box can give: every HH_Weapon with a box weight, or, for a game whose
// weapons aren't HH_Weapons (Brutal Doom, Project Brutality), whatever is in the player's slots
class HH_WeaponPool play {
    static void Gather(PlayerPawn player, out Array<class<Weapon> > weapons, out Array<int> weights) {
        weapons.Clear();
        weights.Clear();
        foreach (type : AllActorClasses) {
            let weaponType = (class<HH_Weapon>)(type);
            if (weaponType != null && GetDefaultByType(weaponType).boxWeight > 0) {
                weapons.Push(weaponType);
                weights.Push(GetDefaultByType(weaponType).boxWeight);
            }
        }
        if (weapons.Size() != 0 || player == null || player.player == null) {
            return;
        }
        let manager = HH_InventoryManager.Of(player);
        let slots = player.player.weapons;
        for (let slot = 0; slot < 10; ++slot) {
            for (let index = 0; index < slots.SlotSize(slot); ++index) {
                let type = slots.GetWeapon(slot, index);
                if (type != null && HH_InventoryManager.Counts(type) && (manager == null || type != manager.melee)
                        && weapons.Find(type) == weapons.Size()) {
                    weapons.Push(type);
                    weights.Push(1);
                }
            }
        }
    }

    // A weighted pick among the weapons the player doesn't hold, other than `except`; null when
    // there is nothing left to give
    static class<Weapon> Choose(PlayerPawn player, class<Weapon> except = null) {
        Array<class<Weapon> > weapons;
        Array<int> weights;
        HH_WeaponPool.Gather(player, weapons, weights);
        let total = 0;
        for (let i = 0; i < weapons.Size(); ++i) {
            if (weapons[i] == except || (player != null && player.FindInventory(weapons[i]) != null)) {
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
