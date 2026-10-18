// Doors and debris: bought once, they vanish and open the zones in their arguments

class HH_Door : HH_Interactable {
    meta int cost;

    property Cost: cost;

    Default {
        //$Category "Horde Hammer"
        //$Title "Door"
        //$Sprite HHDRA0
        //$Arg0 "Opens zone"
        //$Arg1 "Opens zone"
        //$Arg2 "Opens zone"
        //$Arg3 "Opens zone"
        //$Arg4 "Cost"
        //$Arg4Tooltip "0: the class's own (1000)"
        HH_Door.Cost 1000;
        Radius 20;
        Height 128;
        +SOLID
        +WALLSPRITE
    }

    int CurrentCost() {
        return self.args[4] > 0? self.args[4]: self.cost;
    }

    override void DoTouch(PlayerPawn player, HH_InventoryManager manager) {
        HH_Interactable.HintCost(manager, self.CurrentCost());
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        let cost = self.CurrentCost();
        if (!HH_Points.Take(player, cost)) {
            player.A_StartSound("hh/denied", CHAN_AUTO);
            return false;
        }
        player.A_StartSound("hh/purchase", CHAN_AUTO);
        let spawning = HH_Spawning.Get();
        for (let i = 0; i < 4; ++i) {
            if (spawning != null && self.args[i] != 0) {
                spawning.OpenZone(self.args[i]);
            }
        }
        HH_Events.Fire('door_opened', player.PlayerNumber(), self.tid, cost);
        self.Open();
        return true;
    }

    // What buying does to the door itself; a game can play an animation instead
    virtual void Open() {
        self.Destroy();
    }

    States {
    Spawn:
        HHDR A -1;
        Stop;
    }
}

class HH_Debris : HH_Door {
    Default {
        //$Title "Debris"
        //$Sprite HHDBA0
        Radius 32;
        Height 48;
        -WALLSPRITE
    }

    States {
    Spawn:
        HHDB A -1;
        Stop;
    }
}
