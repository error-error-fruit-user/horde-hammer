// Watching: after bleeding out or joining late until the next round, and at the end of the game

// Where spectators' bodies wait (optional: without one they stay where they were, hidden)
class HH_SpectatorSpot : Actor {
    Default {
        //$Category "Horde Hammer"
        //$Title "Spectator Spot"
        //$Sprite HHSSA0
        RenderStyle "None";
        +NOBLOCKMAP
        +NOGRAVITY
        +DONTSPLASH
        +NOTONAUTOMAP
    }

    States {
    Spawn:
        TNT1 A -1;
        Stop;
    }
}

// What everyone sees when the game is over (optional: without one they see where they stood)
class HH_GameOverCamera : Actor {
    Default {
        //$Category "Horde Hammer"
        //$Title "Game Over Camera"
        //$Sprite HHGCA0
        RenderStyle "None";
        +NOBLOCKMAP
        +NOGRAVITY
        +DONTSPLASH
        +NOTONAUTOMAP
    }

    States {
    Spawn:
        TNT1 A -1;
        Stop;
    }
}

class HH_Spectate : Inventory {
    int watching;               // the player number whose view this player sees, -1 for their own

    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
    }

    // Hides the body: no shooting, no being hit or blocked, nothing to chase
    static void Hide(Actor pawn, bool hide) {
        pawn.bInvisible = hide;
        pawn.bShootable = !hide;
        pawn.bSolid = !hide;
        pawn.bNoTarget = hide;
        pawn.bNoGravity = hide;
        pawn.bNoClip = hide;
        if (pawn.player != null) {
            if (hide) {
                pawn.player.cheats |= CF_TOTALLYFROZEN;
            } else {
                pawn.player.cheats &= ~CF_TOTALLYFROZEN;
            }
        }
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        if (manager != null) {
            manager.spectating = true;
            manager.weapons.Clear();
        }
        // Weapons go now (the next round gives the class's starting ones back)
        for (let item = other.Inv; item != null;) {
            let next = item.Inv;
            if (item is 'Weapon') {
                item.Destroy();
            }
            item = next;
        }
        HH_Spectate.Hide(other, true);
        let spot = HH_Util.FindFirst('HH_SpectatorSpot');
        if (spot != null) {
            other.SetOrigin(spot.pos, false);
        }
        other.vel = (0, 0, 0);
        self.watching = other.PlayerNumber();
        self.WatchNext();
    }

    override void DoEffect() {
        super.DoEffect();
        if (self.owner == null || self.owner.player == null) {
            return;
        }
        let tapped = (self.owner.GetPlayerInput(MODINPUT_OLDBUTTONS) & BT_USE) && !(self.owner.GetPlayerInput(MODINPUT_BUTTONS) & BT_USE);
        if (tapped || !HH_Util.IsActive(self.watching)) {
            self.WatchNext();
        }
    }

    // The next active player after the one being watched, or nobody (the player's own view)
    void WatchNext() {
        let me = self.owner.PlayerNumber();
        for (let step = 1; step <= MAXPLAYERS; ++step) {
            let candidate = (max(self.watching, 0) + step) % MAXPLAYERS;
            if (candidate != me && HH_Util.IsActive(candidate)) {
                self.watching = candidate;
                self.owner.player.camera = players[candidate].mo;
                return;
            }
        }
        self.watching = -1;
        self.owner.player.camera = self.owner;
    }

    override void DetachFromOwner() {
        let manager = HH_InventoryManager.Of(self.owner);
        if (manager != null && !manager.gameOver) {
            manager.spectating = false;
            HH_Spectate.Hide(self.owner, false);
            if (self.owner.player != null) {
                self.owner.player.camera = self.owner;
            }
        }
        super.DetachFromOwner();
    }
}

class HH_GameOverSpectate : Inventory {
    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
        +INVENTORY.UNCLEARABLE
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        let manager = HH_InventoryManager.Of(other);
        if (manager != null) {
            manager.gameOver = true;
        }
        other.TakeInventory('HH_LastStand', 1);
        other.TakeInventory('HH_Spectate', 1);
        HH_Spectate.Hide(other, true);
        let camera = HH_Util.FindFirst('HH_GameOverCamera');
        if (other.player != null) {
            other.player.camera = camera != null? camera: other;
        }
    }
}
