// A key: equipment that opens the doors it is made for when swung at them, for nothing, and is
// gone after; swung at anything else it hits like a knife. A game subclasses it for each door (or
// set of doors) with HH_Key.Door, their TID, and its own sprites.

class HH_Key : HH_Weapon {
    const RANGE = 72;

    meta int door;              // the TID of the doors it opens; 0 opens none
    bool spent;

    property Door: door;

    Default {
        Tag "$HH_TAG_KEY";
        HH_Weapon.Equipment true;
        HH_Weapon.Counted false;
        HH_Weapon.BoxWeight 0;
        +WEAPON.NOALERT
        +WEAPON.MELEEWEAPON
    }

    // Its doors in reach open; then it hits whatever is in front
    action void HH_KeySwing() {
        let player = PlayerPawn(self);
        if (invoker.door != 0 && player != null) {
            let doors = level.CreateActorIterator(invoker.door, 'HH_Door');
            Actor found;
            while (found = doors.Next()) {
                let door = HH_Door(found);
                if (door != null && self.Distance2D(door) <= HH_Key.RANGE + door.radius) {
                    self.A_StartSound("hh/purchase", CHAN_AUTO);
                    door.OpenFor(player, 0);
                    invoker.spent = true;
                }
            }
        }
        A_CustomPunch(HH_Settings.Int("hh_kick_damage"), true, CPF_NOTURN, "HH_KeyPuff", HH_Key.RANGE);
    }

    action State WhenSpent(StateLabel label) {
        return invoker.When(invoker.spent, label);
    }

    // Used up: put away for good
    action void HH_SpendKey() {
        let manager = HH_InventoryManager.Of(self);
        if (manager != null) {
            manager.Abandon(invoker);
            manager.SelectBest();
        }
        self.TakeInventory(invoker.GetClass(), 1);
    }

    States {
    Spawn:
        HHKY A -1;
        Stop;
    Select:
        HHKH A 1 A_Raise;
        Loop;
    Deselect:
        HHKH A 1 A_Lower;
        Loop;
    Ready:
        HHKH A 1 A_WeaponReady;
        Loop;
    Fire:
        HHKH B 3;
        HHKH C 3 HH_KeySwing;
        HHKH C 4;
        HHKH B 3;
        TNT1 A 0 WhenSpent("Spent");
        Goto Ready;
    Spent:
        TNT1 A 0 HH_SpendKey;
        TNT1 A 1;
        Wait;
    }
}

class HH_KeyPuff : BulletPuff {
    Default {
        AttackSound "hh/kick";
        DamageType "Melee";
        +NODECAL
        +PUFFONACTORS
    }
}
