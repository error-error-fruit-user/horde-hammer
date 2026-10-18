// Shared helpers: who is playing, and who can be targeted

const HH_VERSION = "0.1.0";

class HH_Util play {
    // Whether player number `number` is in the game and has a body
    clearscope static bool InGame(int number) {
        return number >= 0 && number < MAXPLAYERS && playeringame[number] && players[number].mo != null;
    }

    clearscope static HH_InventoryManager ManagerOf(int number) {
        if (!HH_Util.InGame(number)) {
            return null;
        }
        return HH_InventoryManager(players[number].mo.FindInventory('HH_InventoryManager'));
    }

    // Alive, not down, not spectating: someone zombies chase and the game is still going for
    clearscope static bool IsActive(int number) {
        let manager = HH_Util.ManagerOf(number);
        return manager != null && manager.IsActive();
    }

    clearscope static int CountInGame() {
        let count = 0;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.InGame(i)) {
                ++count;
            }
        }
        return count;
    }

    clearscope static int CountActive() {
        let count = 0;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.IsActive(i)) {
                ++count;
            }
        }
        return count;
    }

    clearscope static String NameOf(int number) {
        if (number < 0 || number >= MAXPLAYERS || !playeringame[number]) {
            return "";
        }
        return players[number].GetUserName();
    }

    // The closest active player to `from`, or null when nobody is
    static PlayerPawn NearestActive(Actor from) {
        PlayerPawn nearest = null;
        let best = double.infinity;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.IsActive(i)) {
                let pawn = players[i].mo;
                let distance = from.Distance3D(pawn);
                if (distance < best) {
                    best = distance;
                    nearest = pawn;
                }
            }
        }
        return nearest;
    }

    // The first actor of `type` in the map, or null
    static Actor FindFirst(class<Actor> type) {
        let iterator = ThinkerIterator.Create(type);
        return Actor(iterator.Next());
    }

    // A localized string with its %d or %s filled in, for the HUD and messages
    clearscope static String Localized(String id, String argument = "") {
        let text = StringTable.Localize(id);
        if (argument != "") {
            text.Replace("%d", argument);
            text.Replace("%s", argument);
        }
        return text;
    }
}
