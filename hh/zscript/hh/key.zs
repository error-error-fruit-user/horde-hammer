// A key: equipment that opens the doors it is made for when swung at them, for nothing, and is
// gone after; swung at anything else it hits like a knife. A game subclasses it for each door (or
// set of doors) with HH_Key.Door, their TID. It is the IWAD's red keycard, held up big in hand; a
// subclass can be another key (RKEY, YSKU...) by replacing its states.

class HH_Key : HH_Weapon {
    const RANGE = 72;
    const HELD_SCALE = 3.0;     // a pickup's sprite, held up in hand, is drawn this much bigger

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

    // Held up big: the keycard is a pickup's sprite, small and with a pickup's offsets
    action void HH_HoldKey() {
        A_OverlayScale(PSP_WEAPON, HH_Key.HELD_SCALE, HH_Key.HELD_SCALE);
    }

    // The keycard is held up at the bottom of the screen
    States {
    Spawn:
        RKEY A 10;
        RKEY B 10 Bright;
        Loop;
    Select:
        RKEY A 0 HH_HoldKey;
        RKEY A 1 Offset(150, 150) A_Raise(256);
        Wait;
    Deselect:
        RKEY A 1 Offset(150, 150) A_Lower(256);
        Wait;
    Ready:
        // A_WeaponReady puts the weapon back at 0, WEAPONTOP to bob it: held up again after
        RKEY A 1 {
            A_WeaponReady();
            A_WeaponOffset(150, 150);
        }
        Loop;
    Fire:
        RKEY A 3 Offset(150, 158);
        RKEY B 3 Bright Offset(150, 130) HH_KeySwing;
        RKEY B 4 Bright Offset(150, 130);
        RKEY A 3 Offset(150, 154);
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
