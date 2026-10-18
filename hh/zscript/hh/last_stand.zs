// Going down: crawling with a pistol until a teammate revives you (or solo Quick Revive does), or
// bleeding out and watching until the next round

class HH_LastStand : Inventory {
    const SPEED = 0.2;
    const VIEW_HEIGHT = 5;
    const HEIGHT = 7;
    const ATTACK_Z_OFFSET = -18;
    const VIEW_BOB = 0.25;

    bool solo;
    bool revived;
    int reviver;
    int ticsLeft;
    class<Weapon> pistol;
    bool pistolOut;
    HH_ReviveHandle handle;

    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
    }

    // The pistol for going down: the held HH_Weapon with the highest LastStand, else the starting weapon
    static class<Weapon> ChoosePistol(Actor player, HH_InventoryManager manager) {
        class<Weapon> best = null;
        let bestRank = 0;
        for (let item = player.Inv; item != null; item = item.Inv) {
            let weapon = HH_Weapon(item);
            if (weapon != null && weapon.lastStand > bestRank) {
                best = weapon.GetClass();
                bestRank = weapon.lastStand;
            }
        }
        return best != null? best: manager.startingWeapon;
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        let pawn = PlayerPawn(other);
        if (manager == null || pawn == null) {
            return;
        }
        let number = other.PlayerNumber();
        manager.lastStand = true;
        manager.switchWeapon = false;
        self.reviver = -1;
        self.solo = other.FindInventory('HH_SoloRevive') != null;
        self.ticsLeft = self.solo? HH_Settings.Int("hh_solo_last_stand_time"): HH_Settings.Int("hh_bleed_out_time");

        pawn.speed = HH_LastStand.SPEED;
        pawn.ViewHeight = HH_LastStand.VIEW_HEIGHT;
        pawn.height = HH_LastStand.HEIGHT;
        pawn.AttackZOffset = HH_LastStand.ATTACK_Z_OFFSET;
        pawn.ViewBob = HH_LastStand.VIEW_BOB;
        pawn.JumpZ = 0;
        pawn.bInvulnerable = true;
        pawn.bNoThrustWhenInvul = true;

        // The pistol comes out on the first tick: a weapon chosen while the damage that downed the
        // player is still being dealt doesn't stay chosen
        self.pistol = HH_LastStand.ChoosePistol(other, manager);
        self.pistolOut = false;
        if (!self.solo) {
            self.handle = HH_ReviveHandle.SpawnFor(self);
        }

        HH_Players.Message("$HH_MSG_DOWNED", number);
        HH_Events.Fire('player_downed', number);
        let spawning = HH_Spawning.Get();
        if (spawning != null) {
            spawning.Retarget();
        }
    }

    override void Tick() {
        super.Tick();
        if (self.owner == null || self.bDestroyed) {
            return;
        }
        if (!self.pistolOut) {
            self.pistolOut = true;
            let manager = HH_InventoryManager.Of(self.owner);
            if (manager != null) {
                manager.GiveTemporary(self.pistol);
            }
        }
        if (self.handle != null && self.handle.progress > 0) {
            return;     // nobody bleeds out while being revived
        }
        if (--self.ticsLeft <= 0) {
            if (self.solo) {
                self.Revive(-1);
            } else {
                self.BleedOut();
            }
        }
    }

    void Revive(int reviver) {
        self.revived = true;
        self.reviver = reviver;
        self.Destroy();
    }

    void BleedOut() {
        self.Destroy();
    }

    override void DetachFromOwner() {
        let manager = HH_InventoryManager.Of(self.owner);
        let pawn = PlayerPawn(self.owner);
        if (self.handle != null) {
            self.handle.Destroy();
        }
        if (manager == null || pawn == null) {
            super.DetachFromOwner();
            return;
        }
        let number = pawn.PlayerNumber();
        manager.lastStand = false;

        pawn.speed = HH_Settings.Float("hh_player_speed") > 0? HH_Settings.Float("hh_player_speed"): pawn.Default.speed;
        pawn.ViewHeight = pawn.Default.ViewHeight;
        pawn.height = pawn.Default.height;
        pawn.AttackZOffset = pawn.Default.AttackZOffset;
        pawn.ViewBob = pawn.Default.ViewBob;
        pawn.JumpZ = pawn.Default.JumpZ;
        pawn.bInvulnerable = false;
        pawn.bNoThrustWhenInvul = false;

        let game = HH_Rounds.Get();
        let gameOver = manager.gameOver || (game != null && game.IsOver());
        if (self.revived && !gameOver) {
            manager.ClearPerks();
            manager.RemoveTemporary(self.pistol);
            manager.switchWeapon = true;
            pawn.A_SetHealth(HH_Settings.Int("hh_health"));
            pawn.A_SetBlend("Red", 0.4, TICRATE * 3);
            HH_Players.Message("$HH_MSG_REVIVED", number);
            HH_Events.Fire('player_revived', number, self.reviver);
        } else if (!gameOver) {
            HH_Players.Message("$HH_MSG_BLED_OUT", number);
            HH_Events.Fire('player_bled_out', number);
            super.DetachFromOwner();
            pawn.GiveInventory('HH_Spectate', 1);
            return;
        }
        super.DetachFromOwner();
    }
}

// Follows a downed player; an active teammate holding Use next to them revives them
class HH_ReviveHandle : Actor {
    const RANGE = 64;

    HH_LastStand lastStand;
    int reviver;
    int progress;
    int needed;

    Default {
        +NOINTERACTION
        +NOBLOCKMAP
        RenderStyle "None";
    }

    static HH_ReviveHandle SpawnFor(HH_LastStand lastStand) {
        let handle = HH_ReviveHandle(Actor.Spawn('HH_ReviveHandle', lastStand.owner.pos));
        handle.lastStand = lastStand;
        handle.reviver = -1;
        return handle;
    }

    override void Tick() {
        super.Tick();
        if (self.bDestroyed) {
            return;
        }
        if (self.lastStand == null || self.lastStand.owner == null) {
            self.Destroy();
            return;
        }
        let downed = self.lastStand.owner;
        self.SetOrigin(downed.pos, true);

        // Hints for everyone close enough, and the revive goes on while the reviver holds Use
        let holder = -1;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (i == downed.PlayerNumber() || !HH_Util.IsActive(i)) {
                continue;
            }
            let pawn = players[i].mo;
            if (pawn.Distance3D(downed) > HH_ReviveHandle.RANGE) {
                continue;
            }
            let manager = HH_InventoryManager.Of(pawn);
            if (self.reviver != i) {
                manager.hud.SetHint("$HH_HINT_REVIVE");
            }
            if ((pawn.GetPlayerInput(MODINPUT_BUTTONS) & BT_USE) && (holder == -1 || i == self.reviver)) {
                holder = i;
            }
        }

        if (holder != self.reviver) {
            self.ResetRevive();
            if (holder != -1) {
                self.reviver = holder;
                self.needed = players[holder].mo.FindInventory('HH_QuickRevive') != null? HH_Settings.Int("hh_quick_revive_time"): HH_Settings.Int("hh_revive_time");
                self.progress = 0;
            }
        }
        if (self.reviver == -1) {
            return;
        }
        ++self.progress;
        let fraction = double(self.progress) / max(1, self.needed);
        HH_InventoryManager.Of(players[self.reviver].mo).hud.SetRevive(fraction);
        HH_InventoryManager.Of(downed).hud.SetRevive(fraction);
        if (self.progress >= self.needed) {
            let who = self.reviver;
            self.ResetRevive();
            self.lastStand.Revive(who);
        }
    }

    // The reviver let go (or left): the bars go away and progress starts over
    void ResetRevive() {
        if (self.reviver != -1) {
            let manager = HH_Util.ManagerOf(self.reviver);
            if (manager != null) {
                manager.hud.SetRevive(0);
            }
        }
        if (self.lastStand != null) {
            let manager = HH_InventoryManager.Of(self.lastStand.owner);
            if (manager != null) {
                manager.hud.SetRevive(0);
            }
        }
        self.reviver = -1;
        self.progress = 0;
    }

    States {
    Spawn:
        TNT1 A -1;
        Stop;
    }
}
