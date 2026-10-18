// What map scripts can ask of Horde Hammer, through ACS's ScriptCall:
//
//     int round = ScriptCall("HH_Acs", "CurrentRound");
//     ScriptCall("HH_Acs", "Listen", "round_started", "MyRoundScript");
//
// Players are ACS player numbers (PlayerNumber(), 0 for the first). ../acs/hh.acs in the repository
// wraps every call in a function (HH_CurrentRound() and so on) for a map's scripts to #include.
// The events Listen takes are listed in events.zs.

class HH_Acs play {
    // The game

    static int CurrentRound() {
        let rounds = HH_Rounds.Get();
        return rounds != null? rounds.currentRound: 0;
    }

    static int ZombiesLeft() {
        let rounds = HH_Rounds.Get();
        return rounds != null? max(0, rounds.zombiesLeft): 0;
    }

    static int ZombiesAlive() {
        let spawning = HH_Spawning.Get();
        return spawning != null? spawning.zombies.Size(): 0;
    }

    static bool IsStarted() {
        let rounds = HH_Rounds.Get();
        return rounds != null && rounds.IsStarted();
    }

    static bool IsOver() {
        let rounds = HH_Rounds.Get();
        return rounds != null && rounds.IsOver();
    }

    static bool IsBetweenRounds() {
        let rounds = HH_Rounds.Get();
        return rounds != null && rounds.IsBetweenRounds();
    }

    // Round 1, for a game that set hh_auto_start off to play an intro first
    static void StartGame() {
        let rounds = HH_Rounds.Get();
        if (rounds != null) {
            rounds.StartGame();
        }
    }

    static void EndGame() {
        let rounds = HH_Rounds.Get();
        if (rounds != null) {
            rounds.EndGame();
        }
    }

    // Skips to the next round straight away, wherever the current one is
    static void NextRound() {
        let rounds = HH_Rounds.Get();
        if (rounds != null && rounds.IsStarted() && !rounds.IsOver()) {
            rounds.NextRound();
        }
    }

    // Zombies

    static void OpenZone(int zone) {
        let spawning = HH_Spawning.Get();
        if (spawning != null) {
            spawning.OpenZone(zone);
        }
    }

    static bool IsZoneOpen(int zone) {
        let spawning = HH_Spawning.Get();
        return spawning != null && spawning.IsZoneOpen(zone);
    }

    static void PauseSpawning(bool paused) {
        let spawning = HH_Spawning.Get();
        if (spawning != null) {
            spawning.paused = paused;
        }
    }

    static void KillAllZombies() {
        let spawning = HH_Spawning.Get();
        if (spawning != null) {
            spawning.KillAll();
        }
    }

    // Players

    static int GetPoints(int player) {
        return HH_Util.InGame(player)? HH_Points.CountOf(players[player].mo): 0;
    }

    // Exact amounts (Double Points doesn't apply)
    static void GivePoints(int player, int amount) {
        if (HH_Util.InGame(player)) {
            HH_Points.Give(players[player].mo, amount, true);
        }
    }

    static bool TakePoints(int player, int amount) {
        return HH_Util.InGame(player) && HH_Points.Take(players[player].mo, amount);
    }

    static bool IsActive(int player) {
        return HH_Util.IsActive(player);
    }

    static bool IsDown(int player) {
        let manager = HH_Util.ManagerOf(player);
        return manager != null && manager.lastStand;
    }

    static bool IsSpectating(int player) {
        let manager = HH_Util.ManagerOf(player);
        return manager != null && manager.spectating;
    }

    static void RevivePlayer(int player) {
        if (HH_Util.InGame(player)) {
            let lastStand = HH_LastStand(players[player].mo.FindInventory('HH_LastStand'));
            if (lastStand != null) {
                lastStand.Revive(-1);
            }
        }
    }

    // A perk without its drink, by class name ("HH_Juggernog")
    static bool GivePerk(int player, String perk) {
        class<HH_Perk> type = perk;
        let manager = HH_Util.ManagerOf(player);
        if (type == null || manager == null || !manager.IsActive()) {
            return false;
        }
        players[player].mo.GiveInventory(type, 1);
        return true;
    }

    // The box

    static void MoveBox() {
        let boxes = HH_MysteryBoxHandler.Get();
        if (boxes != null) {
            boxes.MoveActiveBox();
        }
    }

    static void StartFireSale() {
        let boxes = HH_MysteryBoxHandler.Get();
        if (boxes != null) {
            boxes.StartFireSale();
        }
    }

    // Events: run `script` (a named script) with the event's numbers whenever `event` happens

    static void Listen(String event, String script) {
        let events = HH_Events.Get();
        if (events != null) {
            events.Listen(event, script);
        }
    }

    static void Unlisten(String event, String script) {
        let events = HH_Events.Get();
        if (events != null) {
            events.Unlisten(event, script);
        }
    }
}
