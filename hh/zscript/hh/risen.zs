// Risen: a player revived where the floor hurts (a sector that does damage) rises with
// hh_risen_time to get out of it, unhurt by it meanwhile; still in it when the time is up, they
// die. Once every hh_risen_rounds rounds per player; otherwise they get up into the hurt.

class HH_Risen : HH_Drop {
    Default {
        HH_Drop.EventId 6;
        HH_Drop.Pool 0;
    }

    // Whether `thing` stands where the floor hurts
    static bool Hazardous(Actor thing) {
        return thing != null && thing.CurSector != null && thing.CurSector.damageamount > 0;
    }

    // A revived player who may rise gets it at once (the floor would down them again before
    // they could walk over a drop)
    static void Revived(PlayerPawn pawn, HH_InventoryManager manager) {
        let rounds = HH_Rounds.Get();
        if (!HH_Risen.Hazardous(pawn) || rounds == null) {
            return;
        }
        if (manager.risenRound > 0 && rounds.currentRound - manager.risenRound < HH_Settings.Int("hh_risen_rounds")) {
            return;
        }
        manager.risenRound = max(1, rounds.currentRound);
        pawn.A_StartSound("hh/powerup_grab", CHAN_AUTO);
        pawn.GiveInventory('HH_Risen', 1);
    }

    override void Taken(Actor taker) {
        taker.GiveInventory('HH_RisenPower', 1);
    }

    States {
    Spawn:
        HHRN A -1 Bright;
        Stop;
    }
}

class HH_RisenPower : HH_Powerup {
    Default {
        Inventory.Icon "HHIRN";
    }

    override void InitEffect() {
        super.InitEffect();
        self.EffectTics = HH_Settings.Int("hh_risen_time");
    }

    // Time's up: still standing in it, they die
    override void EndEffect() {
        let pawn = PlayerPawn(self.owner);
        let manager = HH_InventoryManager.Of(pawn);
        let expired = self.EffectTics <= 0;
        super.EndEffect();
        if (expired && manager != null && manager.IsActive() && HH_Risen.Hazardous(pawn)) {
            manager.Perish();
        }
    }
}
