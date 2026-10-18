// Wall buys: a weapon bought off the wall, then its ammo. A game subclasses this for each weapon,
// setting HH_WallBuy.Weapon and HH_WallBuy.Cost and drawing its own chalk outline.

class HH_WallBuy : HH_Interactable {
    meta class<Weapon> weaponType;
    meta int cost;

    property Weapon: weaponType;
    property Cost: cost;

    Default {
        //$Category "Horde Hammer"
        //$Sprite HHWBA0
        HH_WallBuy.Cost 500;
        +WALLSPRITE
        +NOGRAVITY
    }

    int AmmoCost() {
        return self.cost / max(1, HH_Settings.Int("hh_wall_ammo_divisor"));
    }

    // The upgraded version of the weapon, if the game has one (HH_Weapon.Upgrade)
    class<Weapon> UpgradedWeapon() {
        let zombiesWeapon = (class<HH_Weapon>)(self.weaponType);
        return zombiesWeapon != null? GetDefaultByType(zombiesWeapon).upgrade: null;
    }

    // Which of the two the player holds, or null
    class<Weapon> HeldVersion(Actor player) {
        if (self.weaponType != null && player.FindInventory(self.weaponType) != null) {
            return self.weaponType;
        }
        let upgraded = self.UpgradedWeapon();
        if (upgraded != null && player.FindInventory(upgraded) != null) {
            return upgraded;
        }
        return null;
    }

    static bool AmmoIsFull(Actor player, class<Weapon> type) {
        let ammoType = GetDefaultByType(type).ammoType1;
        if (ammoType == null) {
            return true;
        }
        let owned = player.FindInventory(ammoType);
        return owned != null && owned.amount >= owned.MaxAmount;
    }

    override void DoTouch(PlayerPawn player, HH_InventoryManager manager) {
        if (self.weaponType == null) {
            return;
        }
        let held = self.HeldVersion(player);
        if (held == null) {
            HH_Interactable.HintCost(manager, self.cost);
        } else if (!HH_WallBuy.AmmoIsFull(player, held)) {
            HH_Interactable.HintCost(manager, held == self.weaponType? self.AmmoCost(): HH_Settings.Int("hh_wall_upgraded_ammo_cost"));
        }
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (self.weaponType == null) {
            return false;
        }
        let held = self.HeldVersion(player);
        if (held != null) {
            // Ammo, charged only when there is room for it
            let price = held == self.weaponType? self.AmmoCost(): HH_Settings.Int("hh_wall_upgraded_ammo_cost");
            if (HH_WallBuy.AmmoIsFull(player, held) || !HH_Points.Take(player, price)) {
                player.A_StartSound("hh/denied", CHAN_AUTO);
                return false;
            }
            manager.FillAmmo(GetDefaultByType(held).ammoType1);
        } else {
            if (!HH_Points.Take(player, self.cost)) {
                player.A_StartSound("hh/denied", CHAN_AUTO);
                return false;
            }
            player.GiveInventory(self.weaponType, 1);
            player.A_SelectWeapon(self.weaponType);
        }
        player.A_StartSound("hh/purchase", CHAN_AUTO);
        return true;
    }

    States {
    Spawn:
        HHWB A -1 Bright;
        Stop;
    }
}
