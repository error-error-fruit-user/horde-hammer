// Weapons lying in the world (dropped by a player, or offered by the mystery box), and dropping them

class HH_Pickup : HH_Interactable {
    class<Inventory> item;
    int ammoCarried;            // the reserve ammo that comes with a dropped weapon
    bool fullAmmo;              // the box's: taken with a full reserve

    Default {
        Radius 20;
        Height 24;
    }

    // The sprite, frame and scale to show an item with: its own spawn sprite, or a question mark
    static int, int, Vector2 GetInfo(readonly<Inventory> item) {
        let spawn = item.SpawnState;
        if (spawn != null && spawn.sprite != 0 && spawn.GetSpriteTexture(0).Exists()) {
            return spawn.sprite, spawn.frame, item.scale;
        }
        let unknown = GetDefaultByType('HH_NullPickup');
        return unknown.SpawnState.sprite, unknown.SpawnState.frame, unknown.scale;
    }

    // A pickup holding `given`, where the giver stands, with its share of the giver's ammo: the
    // reserve split evenly between every weapon they hold that uses it
    static HH_Pickup TakeFrom(Actor giver, Weapon given) {
        let ammo = given.ammoType1;
        let share = 0;
        if (ammo != null) {
            let sharing = 0;
            for (let item = giver.Inv; item != null; item = item.Inv) {
                let weapon = Weapon(item);
                if (weapon != null && weapon.ammoType1 == ammo) {
                    ++sharing;
                }
            }
            share = giver.CountInv(ammo) / max(1, sharing);
            giver.TakeInventory(ammo, share);
        }
        let pickup = HH_Pickup(Actor.Spawn('HH_Pickup', giver.pos, ALLOW_REPLACE));
        pickup.item = given.GetClass();
        pickup.AddInventory(given);
        pickup.ammoCarried = share;
        [pickup.sprite, pickup.frame, pickup.scale] = HH_Pickup.GetInfo(given);
        return pickup;
    }

    bool CanTake(PlayerPawn player, HH_InventoryManager manager) {
        if (self.item == null) {
            return false;
        }
        let weaponType = (class<Weapon>)(self.item);
        if (weaponType != null) {
            return HH_InventoryManager.Held(player, weaponType) == null;
        }
        return player.FindInventory(self.item) == null;
    }

    override void DoTouch(PlayerPawn player, HH_InventoryManager manager) {
        if (self.CanTake(player, manager)) {
            manager.hud.SetHint("$HH_HINT_PICKUP", GetDefaultByType(self.item).GetTag());
        }
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (!self.CanTake(player, manager)) {
            return false;
        }
        self.GiveTo(player, manager);
        return true;
    }

    // The taker gets the weapon (HH_InventoryManager brings it up, if it has ammo)
    virtual void GiveTo(PlayerPawn taker, HH_InventoryManager manager) {
        let weaponType = (class<Weapon>)(self.item);
        let taken = Weapon(self.FindInventory(self.item));
        let ammo = weaponType != null? GetDefaultByType(weaponType).ammoType1: null;
        if (taken != null) {
            // The weapon itself, with its magazine and the ammo that came with it
            manager.HandlePickup(taken);
            taker.AddInventory(taken);
            if (ammo != null && self.ammoCarried > 0) {
                taker.GiveInventory(ammo, self.ammoCarried);
            }
        } else {
            taker.GiveInventory(self.item, 1);
            if (!(self.item is 'HH_Weapon') && ammo != null) {
                taker.GiveInventory(ammo, GetDefaultByType(ammo).MaxAmount / 3);
            }
        }
        if (self.fullAmmo && weaponType != null) {
            manager.FillAmmo(ammo);
            manager.FillAmmo(GetDefaultByType(weaponType).ammoType2);
        }
        self.Destroy();
    }

    States {
    Spawn:
        #### # 2100;
        Stop;
    }
}

class HH_NullPickup : Inventory {
    States {
    Spawn:
        HHNL A -1;
        Stop;
    }
}

// Double tap the drop key to drop the weapon in hand, for hh_drop_weapon_cost points (never into
// debt). A bottle already drunk drops for nothing: it looks like any other, but gives no perk.
class HH_PickupDropper : Inventory {
    const DOUBLE_TAP_TICS = 35;

    int ticsSincePress;

    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
        +INVENTORY.UNCLEARABLE
        +INVENTORY.PERSISTENTPOWER
    }

    override void DoEffect() {
        super.DoEffect();
        ++self.ticsSincePress;
    }

    void HandlePress() {
        if (self.ticsSincePress > 0 && self.ticsSincePress <= HH_PickupDropper.DOUBLE_TAP_TICS) {
            self.DropPickup();
        }
        self.ticsSincePress = 0;
    }

    void DropPickup() {
        let player = PlayerPawn(self.owner);
        let manager = HH_InventoryManager.Of(player);
        if (player == null || manager == null || player.player.ReadyWeapon == null) {
            return;
        }
        let weapon = player.player.ReadyWeapon;
        let drink = HH_Drink(weapon);
        if (!manager.Owns(weapon) && drink == null) {
            return;
        }
        // the bottle keeps whether it was drunk, so whoever takes an empty one drinks nothing
        let cost = drink != null && drink.consumed? 0: HH_Settings.Int("hh_drop_weapon_cost");
        if (HH_Points.Take(player, cost)) {
            manager.Abandon(weapon);
            HH_Pickup.TakeFrom(player, weapon);
            manager.SelectBest();
        }
    }
}
