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
        //$Arg0 "Cost"
        //$Arg0Tooltip "0: the class's own"
        HH_WallBuy.Cost 500;
        +WALLSPRITE
        +NOGRAVITY
    }

    // The price here: the map's (its first argument), else the class's
    int CurrentCost() {
        return self.args[0] > 0? self.args[0]: self.cost;
    }

    int AmmoCost() {
        return self.CurrentCost() / max(1, HH_Settings.Int("hh_wall_ammo_divisor"));
    }

    // The upgraded version of the weapon, if the game has one (HH_Weapon.Upgrade)
    class<Weapon> UpgradedWeapon() {
        return HH_InventoryManager.UpgradeOf(self.weaponType);
    }

    // The version of it the player holds (HH_InventoryManager.Held), or null
    class<Weapon> HeldVersion(Actor player) {
        let held = HH_InventoryManager.Held(player, self.weaponType);
        return held != null? held.GetClass(): null;
    }

    int HeldAmmoCost(class<Weapon> held) {
        let upgraded = self.UpgradedWeapon();
        return upgraded != null && held == upgraded? HH_Settings.Int("hh_wall_upgraded_ammo_cost"): self.AmmoCost();
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
            HH_Interactable.HintCost(manager, self.CurrentCost());
        } else if (!HH_WallBuy.AmmoIsFull(player, held)) {
            HH_Interactable.HintCost(manager, self.HeldAmmoCost(held));
        }
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (self.weaponType == null) {
            return false;
        }
        let held = self.HeldVersion(player);
        if (held != null) {
            // Ammo, charged only when there is room for it
            let price = self.HeldAmmoCost(held);
            if (HH_WallBuy.AmmoIsFull(player, held) || !HH_Points.Take(player, price)) {
                player.A_StartSound("hh/denied", CHAN_AUTO);
                return false;
            }
            manager.FillAmmo(GetDefaultByType(held).ammoType1);
        } else {
            if (!HH_Points.Take(player, self.CurrentCost())) {
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
