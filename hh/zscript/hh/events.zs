// Events a game can react to without patching the library.
//
// Every event goes two ways:
//   - to ZScript, as an interface event named "hh_<event>" on every machine, for that machine's
//     player (EventHandler.InterfaceProcess; e.Args[0..2] are the event's numbers)
//   - to ACS, by running the named scripts the map asked for with HH_Acs.Listen, with the same
//     numbers as the script's arguments
//
// The events and their numbers:
//   game_started      round
//   round_started     round
//   round_ended       round
//   game_over         round reached
//   player_downed     player
//   player_revived    player, reviver (-1 for solo Quick Revive)
//   player_bled_out   player
//   player_respawned  player
//   door_opened       player, the door's TID, its cost
//   perk_bought       player, the machine's TID
//   box_opened        player
//   box_moved         -
//   powerup_taken     player, the drop's event id (1 Insta-Kill, 2 Double Points, 3 Max Ammo,
//                     4 Ka-Boom, 5 Fire Sale, a game's own drops their own)
//   zone_opened       zone
//   repulse_pressed   player (whenever the repulse key is pressed, repulsion or not)

class HH_Listener {
    Name event;
    Name script;
}

class HH_Events : EventHandler {
    // The line special number of ACS_ExecuteAlways
    const ACS_EXECUTE_ALWAYS = 226;

    Array<HH_Listener> listeners;

    clearscope static HH_Events Get() {
        return HH_Events(EventHandler.Find('HH_Events'));
    }

    static void Fire(Name event, int arg1 = 0, int arg2 = 0, int arg3 = 0) {
        let interfaceName = "hh_"..event;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (playeringame[i]) {
                EventHandler.SendInterfaceEvent(i, interfaceName, arg1, arg2, arg3);
            }
        }

        let self = HH_Events.Get();
        if (self == null) {
            return;
        }
        foreach (listener : self.listeners) {
            if (listener.event == event) {
                Level.ExecuteSpecial(HH_Events.ACS_EXECUTE_ALWAYS, null, null, false, -int(listener.script), 0, arg1, arg2, arg3);
            }
        }
    }

    void Listen(Name event, Name script) {
        foreach (listener : self.listeners) {
            if (listener.event == event && listener.script == script) {
                return;
            }
        }
        let listener = new('HH_Listener');
        listener.event = event;
        listener.script = script;
        self.listeners.Push(listener);
    }

    void Unlisten(Name event, Name script) {
        for (let i = self.listeners.Size() - 1; i >= 0; --i) {
            if (self.listeners[i].event == event && self.listeners[i].script == script) {
                self.listeners.Delete(i);
            }
        }
    }
}
