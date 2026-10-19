// Settings: every server setting is a CVar (CVARINFO.txt) that starts at -1 (or "") for "the game's
// default". The defaults come from HH_Defaults below; a game changes any of them by subclassing it:
//
//     class Nacht_Defaults : HH_Defaults {
//         override void Fill(HH_SettingsHandler settings) {
//             super.Fill(settings);
//             settings.Set("hh_zombie_class", "Nacht_Zombie");
//             settings.Set("hh_player_speed", "0.5");
//         }
//     }
//
// If several subclasses exist, the deepest wins, and between equals the one loaded last (so a game
// beats a helper loaded before it). A host who sets a CVar overrides both.

class HH_Defaults play {
    virtual void Fill(HH_SettingsHandler settings) {
        settings.Set("hh_start_points", "500");  // points a player starts with
        settings.Set("hh_respawn_points", "1500");  // the least a player has after respawning at a new round
        settings.Set("hh_max_weapons", "2");  // weapons a player can carry, not counting melee and drinks
        settings.Set("hh_perk_limit", "0");  // perks a player can hold at once, 0 for no limit
        settings.Set("hh_player_speed", "0");  // player speed, 0 to leave the player class's own
        settings.Set("hh_health", "150");  // health without Juggernog
        settings.Set("hh_jugg_health", "300");  // health with Juggernog
        settings.Set("hh_health_regen", "1");  // health comes back after a while without damage
        settings.Set("hh_regen_delay", "105");  // tics without damage before healing starts
        settings.Set("hh_regen_rate", "5");  // health healed per tic
        settings.Set("hh_weapon_switching", "1");  // Horde Hammer handles the weapon slot keys (turn off for mods with their own)
        settings.Set("hh_remove_items", "1");  // remove items that appear in the world (monster drops, map items)
        settings.Set("hh_kick_enabled", "1");  // the kick key works
        settings.Set("hh_kick_damage", "40");
        settings.Set("hh_hud_before_start", "1");  // the HUD shows before round 1 (a game with an intro turns it off)
        settings.Set("hh_drop_weapon_cost", "750");  // points to drop a weapon (double tap the drop key)
        settings.Set("hh_auto_start", "1");  // start round 1 by itself (a game with an intro turns it off and starts it itself)
        settings.Set("hh_start_delay", "105");  // tics before round 1 when it starts by itself
        settings.Set("hh_round_delay", "350");  // tics between the last zombie dying and repulsion
        settings.Set("hh_repulsion_time", "175");  // tics of repulsion before the next round; the repulse key starts it again
        settings.Set("hh_zombie_health_base", "25");  // zombie health in round 1
        settings.Set("hh_zombie_health_per_round", "20");  // added each round
        settings.Set("hh_zombie_count_base", "4");  // zombies in round 1
        settings.Set("hh_zombie_count_per_round", "3");  // added each round
        settings.Set("hh_zombie_count_per_player", "0");  // added each round for every player after the first
        settings.Set("hh_zombie_speed_per_round", "0");  // added to zombie speed each round
        settings.Set("hh_zombie_speed_max", "0");  // the most speed rounds can give, 0 for no limit
        settings.Set("hh_max_horde", "32");  // zombies alive at once
        settings.Set("hh_spawn_delay_min", "30");  // tics between spawns
        settings.Set("hh_spawn_delay_max", "70");
        settings.Set("hh_zombie_class", "HH_Zombie");  // what spawners spawn (an HH_ZombieSpawner subclass picks one at random)
        settings.Set("hh_points_hit", "10");
        settings.Set("hh_points_kill", "50");
        settings.Set("hh_points_headshot", "90");
        settings.Set("hh_points_melee", "120");
        settings.Set("hh_points_bottle", "150");
        settings.Set("hh_box_cost", "950");
        settings.Set("hh_box_fire_sale_cost", "10");
        settings.Set("hh_box_min_spins", "4");  // spins before the box can move
        settings.Set("hh_box_move_chance", "3");  // after that, it moves 1 time in this many
        settings.Set("hh_box_pickup_time", "350");  // tics to take the weapon
        settings.Set("hh_wall_ammo_divisor", "2");  // ammo costs the weapon's cost divided by this
        settings.Set("hh_wall_upgraded_ammo_cost", "4500");
        settings.Set("hh_drops_per_round", "4");
        settings.Set("hh_drop_chance", "7");  // a kill drops a power-up 1 time in this many
        settings.Set("hh_drop_lifetime", "1050");  // tics a drop stays on the floor
        settings.Set("hh_powerup_duration", "1050");  // tics a power-up lasts
        settings.Set("hh_kaboom_points", "400");
        settings.Set("hh_bleed_out_time", "1050");  // tics a downed player waits for a revive
        settings.Set("hh_revive_time", "175");  // tics to revive someone
        settings.Set("hh_quick_revive_time", "105");  // with Quick Revive
        settings.Set("hh_solo_last_stand_time", "350");  // tics before solo Quick Revive brings the player back
        settings.Set("hh_solo_revives", "3");  // solo Quick Revive can be bought this many times
        settings.Set("hh_solo_quick_revive_cost", "500");
    }
}

class HH_SettingsHandler : EventHandler {
    Array<String> keys;
    Array<String> values;

    clearscope static HH_SettingsHandler Get() {
        return HH_SettingsHandler(EventHandler.Find('HH_SettingsHandler'));
    }

    override void OnRegister() {
        self.Build();
    }

    override void WorldLoaded(WorldEvent e) {
        // A save may come from before the game changed its defaults
        if (e.IsSaveGame) {
            self.Build();
        }
    }

    void Build() {
        self.keys.Clear();
        self.values.Clear();
        // The deepest subclass wins; between equals, the one loaded last (the game, after anything
        // loaded before it)
        class<HH_Defaults> chosen = 'HH_Defaults';
        let chosenDepth = 0;
        foreach (type : AllClasses) {
            let defaults = (class<HH_Defaults>)(type);
            if (defaults == null) {
                continue;
            }
            let depth = HH_SettingsHandler.Depth(defaults);
            if (depth >= chosenDepth) {
                chosen = defaults;
                chosenDepth = depth;
            }
        }
        HH_Defaults(new(chosen)).Fill(self);
    }

    static int Depth(class<Object> type) {
        let depth = 0;
        for (let parent = type; parent != null && parent != 'HH_Defaults'; parent = parent.GetParentClass()) {
            ++depth;
        }
        return depth;
    }

    static bool Derives(class<Object> type, class<Object> ancestor) {
        for (let parent = type; parent != null; parent = parent.GetParentClass()) {
            if (parent == ancestor) {
                return true;
            }
        }
        return false;
    }

    void Set(String key, String value) {
        let index = self.keys.Find(key);
        if (index == self.keys.Size()) {
            self.keys.Push(key);
            self.values.Push(value);
        } else {
            self.values[index] = value;
        }
    }

    clearscope String Lookup(String key) const {
        for (let i = 0; i < self.keys.Size(); ++i) {
            if (self.keys[i] == key) {
                return self.values[i];
            }
        }
        return "";
    }
}

// Reads a setting: the CVar when someone set it, else the game's default
class HH_Settings {
    clearscope static String Default(String name) {
        let handler = HH_SettingsHandler.Get();
        return handler != null? handler.Lookup(name): "";
    }

    clearscope static int Int(String name) {
        let cvar = CVar.FindCVar(name);
        if (cvar != null && cvar.GetInt() >= 0) {
            return cvar.GetInt();
        }
        return HH_Settings.Default(name).ToInt();
    }

    clearscope static double Float(String name) {
        let cvar = CVar.FindCVar(name);
        if (cvar != null && cvar.GetFloat() >= 0) {
            return cvar.GetFloat();
        }
        return HH_Settings.Default(name).ToDouble();
    }

    clearscope static bool Bool(String name) {
        return HH_Settings.Int(name) != 0;
    }

    clearscope static String Str(String name) {
        let cvar = CVar.FindCVar(name);
        if (cvar != null && cvar.GetString() != "") {
            return cvar.GetString();
        }
        return HH_Settings.Default(name);
    }
}
