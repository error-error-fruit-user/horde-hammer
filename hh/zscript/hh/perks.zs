// Perks: a machine sells a drink, drinking it gives the perk, going down loses them all

class HH_PerkMachine : HH_Interactable abstract {
    meta class<HH_Drink> drink;
    meta int cost;

    property Drink: drink;
    property Cost: cost;

    Default {
        Radius 20;
        Height 80;
        +SOLID
        +WALLSPRITE
    }

    virtual class<HH_Drink> CurrentDrink() {
        return self.drink;
    }

    virtual int CurrentCost() {
        return self.cost;
    }

    bool CanBuy(PlayerPawn player, HH_InventoryManager manager) {
        let drink = self.CurrentDrink();
        return drink != null && manager.CanTakePerk() && player.FindInventory(drink) == null
            && player.FindInventory(GetDefaultByType(drink).perk) == null;
    }

    override void DoTouch(PlayerPawn player, HH_InventoryManager manager) {
        if (self.CanBuy(player, manager)) {
            HH_Interactable.HintCost(manager, self.CurrentCost());
        }
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (!self.CanBuy(player, manager)) {
            return false;
        }
        if (!HH_Points.Take(player, self.CurrentCost())) {
            player.A_StartSound("hh/denied", CHAN_AUTO);
            return false;
        }
        let drink = self.CurrentDrink();
        player.GiveInventory(drink, 1);
        player.A_SelectWeapon(drink);
        self.A_StartSound("hh/purchase", CHAN_AUTO);
        HH_Events.Fire('perk_bought', player.PlayerNumber(), self.tid);
        self.Bought();
        return true;
    }

    virtual void Bought() {}
}

class HH_Perk : Inventory {
    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        if (manager != null && manager.perks.Find(self.GetClass()) == manager.perks.Size()) {
            manager.perks.Push(self.GetClass());
        }
    }

    override void DetachFromOwner() {
        let manager = HH_InventoryManager.Of(self.owner);
        if (manager != null) {
            let index = manager.perks.Find(self.GetClass());
            if (index != manager.perks.Size()) {
                manager.perks.Delete(index);
            }
        }
        super.DetachFromOwner();
    }
}

class HH_DrinkAmmo : Ammo {
    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.IGNORESKILL
    }
}

// The bottle in hand. Its Ready states play the drinking; Consume gives the perk partway through.
// A game draws its own drinking by replacing Ready; nacht's way, a long animation over three
// sprites, is supported by a "Sprites" state listing them and LoadSprites(0..2) switching between
// them with #### frames.
class HH_Drink : HH_Weapon {
    meta class<HH_Perk> perk;
    int sprites[3];
    bool consumed;

    property Perk: perk;

    Default {
        HH_Weapon.Counted false;
        HH_Weapon.ReloadFrameRate 2;
        Weapon.AmmoType "HH_DrinkAmmo";
        Weapon.AmmoGive 1;
        Weapon.SelectionOrder 9999;
        +WEAPON.CHEATNOTWEAPON
    }

    override void BeginPlay() {
        super.BeginPlay();
        let spriteState = self.FindState("Sprites");
        for (let i = 0; i < 3 && spriteState != null; ++i) {
            self.sprites[i] = spriteState.sprite;
            spriteState = spriteState.NextState;
        }
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        if (manager != null) {
            manager.switchWeapon = false;
        }
    }

    override void DetachFromOwner() {
        let manager = HH_InventoryManager.Of(self.owner);
        if (manager != null) {
            manager.switchWeapon = true;
        }
        super.DetachFromOwner();
    }

    action void LoadSprites(int index) {
        let layer = self.player.FindPSprite(PSP_WEAPON);
        if (layer != null && index >= 0 && index < 3 && invoker.sprites[index] != 0) {
            layer.sprite = invoker.sprites[index];
        }
    }

    // Drinking frames: fire still throws the bottle, and they last FR tics (Speed Cola drinks faster)
    action void DrinkReady() {
        A_WeaponReady(WRF_NOSWITCH | WRF_NOBOB);
        FR();
    }

    action void Consume() {
        if (!invoker.consumed) {
            A_StartSound("hh/swallow", CHAN_AUTO);
            self.GiveInventory(invoker.perk, 1);
            invoker.consumed = true;
        }
    }

    action void Discard() {
        self.TakeInventory(invoker.ammoType1, 1);
        let manager = HH_InventoryManager.Of(self);
        if (manager != null) {
            manager.switchWeapon = true;
            manager.SelectBest();
        }
        self.TakeInventory(invoker.GetClass(), 1);
    }

    // Throwing a full bottle at a zombie: worth hh_points_bottle points if it kills
    action void Throw() {
        let bottle = A_FireProjectile("HH_Bottle", useAmmo: false);
        let spawn = invoker.Default.SpawnState;
        if (bottle != null && spawn != null && spawn.sprite != 0) {
            bottle.sprite = spawn.sprite;
        }
    }

    States {
    Spawn:
        HHBT A -1;
        Stop;
    Select:
        TNT1 A 0 A_Raise;
        Wait;
    Deselect:
        TNT1 A 0 Discard;
        Stop;
    Ready:
        HHDK A 0 A_StartSound("hh/drink", CHAN_AUTO);
        HHDK ABCD 8 DrinkReady;
        HHDK D 0 Consume;
        HHDK DDCBA 8 DrinkReady;
        TNT1 A 0 A_StartSound("hh/bottle_break", CHAN_AUTO);
        Goto Deselect;
    Fire:
        TNT1 A 0 Throw;
        Goto Deselect;
    }
}

class HH_Bottle : Actor {
    Default {
        Projectile;
        Scale 0.5;
        Radius 5;
        Height 5;
        Speed 25;
        Damage 300;
        DamageType "HH_Bottle";
        DeathSound "hh/bottle_break";
        Gravity 0.5;
        -NOGRAVITY
        +FLATSPRITE
    }

    States {
    Spawn:
        HHBT A 1 { self.pitch += 25; }
        Loop;
    Death:
        TNT1 A 1;
        Stop;
    }
}

// Quick Revive: revives teammates faster; alone, it brings you back from going down
class HH_QuickReviveMachine : HH_PerkMachine {
    int soloBuys;

    Default {
        //$Category "Horde Hammer"
        //$Title "Quick Revive Machine"
        //$Sprite HHQRA0
        HH_PerkMachine.Cost 1500;
        HH_PerkMachine.Drink "HH_QuickReviveDrink";
    }

    override class<HH_Drink> CurrentDrink() {
        return multiplayer? self.drink: (class<HH_Drink>)('HH_SoloReviveDrink');
    }

    override int CurrentCost() {
        return multiplayer? self.cost: HH_Settings.Int("hh_solo_quick_revive_cost");
    }

    override void Bought() {
        if (!multiplayer && ++self.soloBuys >= HH_Settings.Int("hh_solo_revives")) {
            self.Destroy();
        }
    }

    States {
    Spawn:
        HHQR A -1;
        Stop;
    }
}

class HH_QuickReviveDrink : HH_Drink {
    Default {
        HH_Drink.Perk "HH_QuickRevive";
        Tag "$HH_TAG_QUICK_REVIVE";
    }
}

class HH_SoloReviveDrink : HH_QuickReviveDrink {
    Default {
        HH_Drink.Perk "HH_SoloRevive";
    }
}

class HH_QuickRevive : HH_Perk {
    Default {
        Inventory.Icon "HHIQR";
    }
}

class HH_SoloRevive : HH_QuickRevive {}

// Juggernog: more health
class HH_JuggernogMachine : HH_PerkMachine {
    Default {
        //$Category "Horde Hammer"
        //$Title "Juggernog Machine"
        //$Sprite HHJGA0
        HH_PerkMachine.Cost 2500;
        HH_PerkMachine.Drink "HH_JuggernogDrink";
    }

    States {
    Spawn:
        HHJG A -1;
        Stop;
    }
}

class HH_JuggernogDrink : HH_Drink {
    Default {
        HH_Drink.Perk "HH_Juggernog";
        Tag "$HH_TAG_JUGGERNOG";
    }
}

class HH_Juggernog : HH_Perk {
    Default {
        Inventory.Icon "HHIJG";
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let regen = HH_Regen(other.FindInventory('HH_Regen'));
        if (regen != null) {
            regen.SetMaxHealth(HH_Settings.Int("hh_jugg_health"));
        }
    }

    override void DetachFromOwner() {
        let regen = self.owner != null? HH_Regen(self.owner.FindInventory('HH_Regen')): null;
        if (regen != null) {
            regen.SetMaxHealth(HH_Settings.Int("hh_health"));
        }
        super.DetachFromOwner();
    }
}

// Speed Cola: faster reloads (and faster drinking)
class HH_SpeedColaMachine : HH_PerkMachine {
    Default {
        //$Category "Horde Hammer"
        //$Title "Speed Cola Machine"
        //$Sprite HHSCA0
        HH_PerkMachine.Cost 3000;
        HH_PerkMachine.Drink "HH_SpeedColaDrink";
    }

    States {
    Spawn:
        HHSC A -1;
        Stop;
    }
}

class HH_SpeedColaDrink : HH_Drink {
    Default {
        HH_Drink.Perk "HH_SpeedCola";
        Tag "$HH_TAG_SPEED_COLA";
    }
}

class HH_SpeedCola : HH_Perk {
    Default {
        Inventory.Icon "HHISC";
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        if (manager != null) {
            manager.SetFastReload(true);
        }
    }

    override void DetachFromOwner() {
        let manager = HH_InventoryManager.Of(self.owner);
        if (manager != null) {
            manager.SetFastReload(false);
        }
        super.DetachFromOwner();
    }
}

// Double Tap: faster firing and double bullet damage
class HH_DoubleTapMachine : HH_PerkMachine {
    Default {
        //$Category "Horde Hammer"
        //$Title "Double Tap Machine"
        //$Sprite HHDTA0
        HH_PerkMachine.Cost 4000;
        HH_PerkMachine.Drink "HH_DoubleTapDrink";
    }

    States {
    Spawn:
        HHDT A -1;
        Stop;
    }
}

class HH_DoubleTapDrink : HH_Drink {
    Default {
        HH_Drink.Perk "HH_DoubleTap";
        Tag "$HH_TAG_DOUBLE_TAP";
    }
}

class HH_DoubleTap : HH_Perk {
    Default {
        Inventory.Icon "HHIDT";
    }

    override void ModifyDamage(int damage, Name damageType, out int newDamage, bool passive, Actor inflictor, Actor source, int flags) {
        if (!passive && inflictor != null && !inflictor.bMissile && source != self.owner) {
            newDamage = damage * 2;
        }
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        if (manager != null) {
            manager.SetDoubleFire(true);
        }
    }

    override void DetachFromOwner() {
        let manager = HH_InventoryManager.Of(self.owner);
        if (manager != null) {
            manager.SetDoubleFire(false);
        }
        super.DetachFromOwner();
    }
}
