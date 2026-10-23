// Points: earned by hurting and killing zombies, spent on everything

class HH_Points : Inventory {
    Default {
        Inventory.MaxAmount 999999;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
        +INVENTORY.UNCLEARABLE
        +INVENTORY.KEEPDEPLETED
    }

    clearscope static int CountOf(Actor player) {
        return player == null? 0: player.CountInv('HH_Points');
    }

    // Gives points, doubled by Double Points unless `exact`; nothing for players who are down or
    // spectating
    static void Give(Actor player, int amount, bool exact = false) {
        let manager = HH_InventoryManager.Of(player);
        if (manager == null || amount <= 0 || !manager.IsActive()) {
            return;
        }
        if (!exact) {
            amount <<= min(player.CountInv('HH_DoublePointsPower'), 8);
        }
        player.GiveInventory('HH_Points', amount);
        manager.hud.AddDelta(amount);
    }

    // Takes `cost` points if the player has them, and says whether they did
    static bool Take(Actor player, int cost) {
        let manager = HH_InventoryManager.Of(player);
        if (manager == null || player.CountInv('HH_Points') < cost) {
            return false;
        }
        if (cost > 0) {
            player.TakeInventory('HH_Points', cost);
            manager.hud.AddDelta(-cost);
        }
        return true;
    }

    // Takes `cost` points even if the player has fewer, into debt (kicking a spinning box);
    // what they earn pays it back
    static void Charge(Actor player, int cost) {
        let manager = HH_InventoryManager.Of(player);
        if (manager == null || cost <= 0) {
            return;
        }
        let points = player.FindInventory('HH_Points');
        if (points == null) {
            player.GiveInventory('HH_Points', 1);
            points = player.FindInventory('HH_Points');
            if (points == null) {
                return;
            }
            points.amount = 0;
        }
        points.amount -= cost;
        manager.hud.AddDelta(-cost);
    }
}

class HH_PointsHandler : EventHandler {
    override void WorldThingDamaged(WorldEvent e) {
        let player = PlayerPawn(e.DamageSource);
        if (player == null || e.Thing == null || !e.Thing.bIsMonster || e.DamageType == 'None') {
            return;
        }
        HH_Points.Give(player, HH_Settings.Int("hh_points_hit"));
        if (e.Thing.health <= 0 || player.CountInv('HH_InstakillPower') != 0) {
            if (e.DamageType == 'HH_Bottle') {
                HH_Points.Give(player, HH_Settings.Int("hh_points_bottle"));
            } else if (e.DamageType == 'HH_Kick' || e.DamageType == 'Melee') {
                HH_Points.Give(player, HH_Settings.Int("hh_points_melee"));
            } else if (e.DamageType == 'HH_Headshot') {
                HH_Points.Give(player, HH_Settings.Int("hh_points_headshot"));
            } else {
                HH_Points.Give(player, HH_Settings.Int("hh_points_kill"));
            }
        }
    }
}
