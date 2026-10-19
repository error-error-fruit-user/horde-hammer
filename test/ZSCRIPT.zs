version "5.0.0"

// Test-only helpers: console network events that drive the game and print its state, so a headless
// run can check the systems without anyone pressing keys. Never part of the library.

class HHTest_Defaults : HH_Defaults {
    override void Fill(HH_SettingsHandler settings) {
        super.Fill(settings);
        settings.Set("hh_start_points", "7777");
        settings.Set("hh_start_delay", "35");
    }
}

class HHTest_Handler : EventHandler {
    override void NetworkProcess(ConsoleEvent e) {
        if (!HH_Util.InGame(e.Player)) {
            return;
        }
        let player = players[e.Player].mo;
        let manager = HH_InventoryManager.Of(player);
        if (e.Name == 'hhtest_settings') {
            let handler = HH_SettingsHandler.Get();
            let cvar = CVar.FindCVar("hh_start_points");
            Console.Printf("test: handler %d keys %d default '%s' cvar %d int %d", handler != null, handler != null? handler.keys.Size(): -1,
                HH_Settings.Default("hh_start_points"), cvar != null? cvar.GetInt(): -999, HH_Settings.Int("hh_start_points"));
        } else if (e.Name == 'hhtest_state') {
            self.PrintState(player, manager);
        } else if (e.Name.Left(10) == "hhtest_use") {
            // hhtest_use:<class> uses the nearest one of that class
            self.UseNearest(player, e.Name.Mid(11));
        } else if (e.Name == 'hhtest_down') {
            player.DamageMobj(null, null, player.health + 1000, 'None');
            Console.Printf("test: after down pending %s", player.player.PendingWeapon != null && player.player.PendingWeapon != WP_NOCHANGE? player.player.PendingWeapon.GetClassName(): 'none');
        } else if (e.Name == 'hhtest_killall') {
            let spawning = HH_Spawning.Get();
            if (spawning != null) {
                spawning.KillAll();
            }
        } else if (e.Name == 'hhtest_ammo') {
            let ammo = player.FindInventory('HHTest_RifleAmmo');
            let rifle = HHTest_Rifle(player.FindInventory('HHTest_Rifle'));
            Console.Printf("test: rifle %d magazine %d reserve %d", rifle != null, rifle != null? rifle.activeAmmo: -1, ammo != null? ammo.amount: -1);
            if (ammo != null) {
                ammo.amount = 1;
            }
        } else if (e.Name == 'hhtest_pistol') {
            let choice = HH_LastStand.ChoosePistol(player, manager);
            let rifle = HH_Weapon(player.FindInventory('HHTest_Rifle'));
            Console.Printf("test: last stand pistol %s, rifle rank %d", choice != null? choice.GetClassName(): 'none', rifle != null? rifle.lastStand: -1);
            let selected = player.A_SelectWeapon('HHTest_Rifle');
            Console.Printf("test: select rifle %d pending %s", selected, player.player.PendingWeapon != null && player.player.PendingWeapon != WP_NOCHANGE? player.player.PendingWeapon.GetClassName(): 'none');
        } else if (e.Name == 'hhtest_mag') {
            let weapon = HH_Weapon(player.player.ReadyWeapon);
            if (weapon != null) {
                let state = player.player.FindPSprite(PSP_WEAPON);
                Console.Printf("test: %s magazine %d reserve %d state %s", weapon.GetClassName(), weapon.activeAmmo,
                    weapon.ammoType1 != null? player.CountInv(weapon.ammoType1): -1, state != null && state.CurState != null? String.Format("%d", weapon.InStateSequence(state.CurState, weapon.FindState("Reload"))): "?");
            }
        } else if (e.Name == 'hhtest_zombies') {
            String kinds = "";
            foreach (zombie : HH_Spawning.Get().zombies) {
                kinds = kinds..zombie.GetClassName().." ";
            }
            Console.Printf("test: zombies %s", kinds);
        } else if (e.Name == 'hhtest_repulse_wait') {
            Console.Printf("phase %d", HH_Rounds.Get().phase);
        }
    }

    void UseNearest(PlayerPawn player, String className) {
        class<Actor> type = className;
        if (type == null) {
            Console.Printf("test: no class %s", className);
            return;
        }
        Actor nearest = null;
        let iterator = ThinkerIterator.Create(type);
        Actor thing;
        while (thing = Actor(iterator.Next())) {
            if (nearest == null || player.Distance3D(thing) < player.Distance3D(nearest)) {
                nearest = thing;
            }
        }
        if (nearest == null) {
            Console.Printf("test: no %s in the map", className);
            return;
        }
        nearest.Touch(player);
        nearest.Used(player);
        Console.Printf("test: used %s", nearest.GetClassName());
    }

    void PrintState(PlayerPawn player, HH_InventoryManager manager) {
        let rounds = HH_Rounds.Get();
        let spawning = HH_Spawning.Get();
        String weapons = "";
        foreach (weapon : manager.weapons) {
            weapons = weapons..weapon.GetClassName().." ";
        }
        String perks = "";
        foreach (perk : manager.perks) {
            perks = perks..perk.GetClassName().." ";
        }
        String pendingName = "none";
        if (player.player.PendingWeapon != null && player.player.PendingWeapon != WP_NOCHANGE) {
            pendingName = player.player.PendingWeapon.GetClassName();
        }
        String readyName = "none";
        if (player.player.ReadyWeapon != null) {
            readyName = player.player.ReadyWeapon.GetClassName();
        }
        String meleeName = "none";
        if (manager.melee != null) {
            meleeName = manager.melee.GetClassName();
        }
        String startName = "none";
        if (manager.startingWeapon != null) {
            startName = manager.startingWeapon.GetClassName();
        }
        Console.Printf("test: at %d %d", int(player.pos.x), int(player.pos.y));
        Console.Printf("test: round %d phase %d left %d unspawned %d alive %d | points %d health %d | active %d down %d spectating %d over %d | ready %s pending %s | weapons %s| perks %s| melee %s start %s",
            rounds.currentRound, rounds.phase, rounds.zombiesLeft, rounds.unspawnedZombies, spawning.zombies.Size(),
            HH_Points.CountOf(player), player.health,
            manager.IsActive(), manager.lastStand, manager.spectating, manager.gameOver,
            readyName, pendingName, weapons, perks, meleeName, startName);
    }
}
