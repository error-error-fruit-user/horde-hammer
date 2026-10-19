// Players entering, leaving and coming back, and the keys that go through network events

// An optional player class for a game that wants one; any player class works with Horde Hammer
// (it gives its items to whatever player enters), so a game normally subclasses its own or this
class HH_Player : DoomPlayer {
    Default {
        Player.DisplayName "Survivor";
    }
}

// Where a player comes back at a new round, instead of the map's player starts (which a game may
// keep somewhere else, like nacht's intro room). Argument 0 picks the player: 1 for the first, 2 for
// the second..., 0 for anyone without a spot of their own.
class HH_RespawnSpot : Actor {
    Default {
        //$Category "Horde Hammer"
        //$Title "Respawn Spot"
        //$Sprite HHRSA0
        //$Arg0 "Player"
        //$Arg0Tooltip "1 for the first player, 2 for the second...; 0 for anyone"
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

class HH_Players : EventHandler {
    clearscope static HH_Players Get() {
        return HH_Players(EventHandler.Find('HH_Players'));
    }

    // The items every player needs; giving them again does nothing
    static void Equip(Actor pawn) {
        pawn.GiveInventory('HH_InventoryManager', 1);
        pawn.GiveInventory('HH_Regen', 1);
        pawn.GiveInventory('HH_PickupDropper', 1);
        pawn.GiveInventory('HH_KickItem', 1);
    }

    override void PlayerEntered(PlayerEvent e) {
        let pawn = players[e.PlayerNumber].mo;
        if (pawn == null) {
            return;
        }
        let fresh = pawn.FindInventory('HH_InventoryManager') == null;
        HH_Players.Equip(pawn);
        if (fresh) {
            pawn.SetInventory('HH_Points', HH_Settings.Int("hh_start_points"));
            pawn.A_SetHealth(HH_Settings.Int("hh_health"));
        }

        // Joining a game already going: watch until the next round
        let rounds = HH_Rounds.Get();
        if (rounds != null && rounds.IsStarted() && !e.IsReturn) {
            pawn.GiveInventory(rounds.IsOver()? 'HH_GameOverSpectate': 'HH_Spectate', 1);
            HH_Players.Message("$HH_MSG_JOINS_NEXT_ROUND", e.PlayerNumber);
        }
    }

    // A player who died anyway (crushed, telefragged, the kill command) comes back watching
    override void PlayerRespawned(PlayerEvent e) {
        let pawn = players[e.PlayerNumber].mo;
        if (pawn == null) {
            return;
        }
        HH_Players.Equip(pawn);
        let rounds = HH_Rounds.Get();
        if (rounds != null && rounds.IsStarted()) {
            pawn.GiveInventory(rounds.IsOver()? 'HH_GameOverSpectate': 'HH_Spectate', 1);
        }
    }

    override void PlayerDisconnected(PlayerEvent e) {
        // Anything waiting on this player checks for them itself; the game may be over now
        let rounds = HH_Rounds.Get();
        if (rounds != null && rounds.IsStarted() && !rounds.IsOver()) {
            rounds.CheckGameOver();
        }
    }

    // The respawn spot for player `number`: their own, else one of the shared ones, else null
    static HH_RespawnSpot SpotFor(int number) {
        Array<HH_RespawnSpot> shared;
        let iterator = ThinkerIterator.Create('HH_RespawnSpot');
        HH_RespawnSpot spot;
        while (spot = HH_RespawnSpot(iterator.Next())) {
            if (spot.args[0] == number + 1) {
                return spot;
            } else if (spot.args[0] == 0) {
                shared.Push(spot);
            }
        }
        return shared.Size() != 0? shared[number % shared.Size()]: null;
    }

    // Puts a player at their respawn spot, or at a player start when the map has none
    static void MoveToSpawn(Actor pawn) {
        let number = pawn.PlayerNumber();
        let spot = HH_Players.SpotFor(number);
        Vector3 position;
        double angle;
        if (spot != null) {
            position = spot.pos;
            angle = spot.angle;
        } else {
            [position, angle] = Level.PickPlayerStart(number);
        }
        pawn.SetOrigin(position, false);
        pawn.angle = angle;
        pawn.vel = (0, 0, 0);
    }

    // A new round: everyone watching comes back
    static void RespawnSpectators() {
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.InGame(i) && players[i].mo.FindInventory('HH_Spectate') != null) {
                let pawn = players[i].mo;
                pawn.TakeInventory('HH_Spectate', 1);
                let manager = HH_InventoryManager.Of(pawn);
                if (manager != null) {
                    manager.Respawn();
                }
                HH_Events.Fire('player_respawned', i);
            }
        }
    }

    // A message on every player's screen, like "Tyler went down!": `id` is a LANGUAGE id whose
    // %s is the player's name
    static void Message(String id, int number) {
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (playeringame[i]) {
                EventHandler.SendInterfaceEvent(i, "hh_message:"..id, number);
            }
        }
    }
}

class HH_Input : EventHandler {
    static ui bool IsKeyFor(int key, String command) {
        Array<int> keys;
        Bindings.GetAllKeysForCommand(keys, command);
        return keys.Find(key) != keys.Size();
    }

    override bool InputProcess(InputEvent e) {
        if (e.Type != InputEvent.Type_KeyDown || HH_Util.ManagerOf(consolePlayer) == null) {
            return false;
        }
        let key = e.KeyScan;
        if (HH_Input.IsKeyFor(key, "weapdrop")) {
            EventHandler.SendNetworkEvent("hh_drop");
            return true;
        }
        if (!HH_Settings.Bool("hh_weapon_switching")) {
            return false;
        }
        for (let slot = 0; slot <= 9; ++slot) {
            if (HH_Input.IsKeyFor(key, "slot "..slot)) {
                EventHandler.SendNetworkEvent("hh_slot", slot);
                return true;
            }
        }
        if (HH_Input.IsKeyFor(key, "weapnext")) {
            EventHandler.SendNetworkEvent("hh_next");
            return true;
        }
        if (HH_Input.IsKeyFor(key, "weapprev")) {
            EventHandler.SendNetworkEvent("hh_prev");
            return true;
        }
        return false;
    }

    // Every machine runs this for every player's event, so it checks everything before acting
    override void NetworkProcess(ConsoleEvent e) {
        let manager = HH_Util.ManagerOf(e.Player);
        if (manager == null) {
            return;
        }
        let pawn = players[e.Player].mo;

        if (e.Name == 'hh_repulse') {
            let rounds = HH_Rounds.Get();
            if (rounds != null && manager.IsActive()) {
                rounds.Repulse(e.Player);
            }
            // Always told, so a game can use the key for itself too (nacht skips its intro with it)
            HH_Events.Fire('repulse_pressed', e.Player);
        } else if (e.Name == 'HH_Settings.Bool("hh_kick_enabled")') {
            let kick = HH_KickItem(pawn.FindInventory('HH_KickItem'));
            if (HH_Settings.Bool("hh_kick_enabled") && kick != null && manager.IsActive()) {
                kick.Kick();
            }
        } else if (e.Name == 'hh_drop') {
            let dropper = HH_PickupDropper(pawn.FindInventory('HH_PickupDropper'));
            if (dropper != null && manager.IsActive()) {
                dropper.HandlePress();
            }
        } else if (e.Name == 'hh_slot' || e.Name == 'hh_next' || e.Name == 'hh_prev') {
            if (!HH_Settings.Bool("hh_weapon_switching") || !manager.IsActive() || !manager.switchWeapon || manager.ticsSinceSwitch <= manager.Default.ticsSinceSwitch) {
                return;
            }
            manager.ticsSinceSwitch = 0;
            if (e.Name == 'hh_slot') {
                manager.SelectWeapon(e.Args[0]);
            } else if (e.Name == 'hh_next') {
                manager.NextWeapon();
            } else {
                manager.PreviousWeapon();
            }
        }
    }
}
