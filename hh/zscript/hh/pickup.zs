// Weapons lying in the world (dropped by a player, or offered by the mystery box), and dropping them

class HH_Pickup : HH_Interactable {
    class<Inventory> item;

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

    // A pickup holding `given` (and the giver's ammo for it), where the giver stands
    static HH_Pickup TakeFrom(Actor giver, Weapon given) {
        let pickup = HH_Pickup(Actor.Spawn('HH_Pickup', giver.pos, ALLOW_REPLACE));
        pickup.item = given.GetClass();
        pickup.AddInventory(given);
        [pickup.sprite, pickup.frame, pickup.scale] = HH_Pickup.GetInfo(given);
        let ammo = given.Default.ammoType1;
        if (ammo != null) {
            let owned = giver.FindInventory(ammo);
            if (owned != null) {
                pickup.AddInventory(owned);
            }
        }
        return pickup;
    }

    bool CanTake(PlayerPawn player, HH_InventoryManager manager) {
        return self.item != null && player.FindInventory(self.item) == null;
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

    virtual void GiveTo(PlayerPawn taker, HH_InventoryManager manager) {
        let weaponType = (class<Weapon>)(self.item);
        let taken = Weapon(self.FindInventory(self.item));
        let ammo = weaponType != null? GetDefaultByType(weaponType).ammoType1: null;
        if (taken != null) {
            // The weapon itself, with its magazine and the ammo that came with it
            manager.HandlePickup(taken);
            taker.AddInventory(taken);
            if (ammo != null) {
                let carried = self.FindInventory(ammo);
                if (carried != null) {
                    taker.GiveInventory(ammo, carried.amount);
                    carried.Destroy();
                }
            }
        } else {
            taker.GiveInventory(self.item, 1);
            if (!(self.item is 'HH_Weapon') && ammo != null) {
                taker.GiveInventory(ammo, GetDefaultByType(ammo).MaxAmount / 3);
            }
        }
        if (weaponType != null) {
            taker.A_SelectWeapon(weaponType);
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

// Double tap the drop key to drop the weapon in hand, for hh_drop_weapon_cost points
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
        if (manager.Owns(weapon) || (drink != null && !drink.consumed)) {
            if (HH_Points.Take(player, HH_Settings.Int("hh_drop_weapon_cost"))) {
                manager.Abandon(weapon);
                HH_Pickup.TakeFrom(player, weapon);
                manager.SelectBest();
            }
        }
    }
}
