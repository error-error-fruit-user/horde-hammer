// Spawning: spawners in zones, the zombies they spawn, and keeping them after the players

class HH_Spawner : Actor {
    Default {
        //$Category "Horde Hammer"
        //$Title "Zombie Spawner"
        //$Sprite HHSPA0
        //$Arg0 "Zone"
        //$Arg0Tooltip "0: spawns from the start. Others start spawning when a door opens their zone."
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

// Spawns one of its DropItems at random as a zombie, like nacht's rogues gallery. Any random
// zombie set must subclass this, so the zombie it picks is counted.
class HH_ZombieSpawner : RandomSpawner {
    override void PostSpawn(Actor spawned) {
        super.PostSpawn(spawned);
        let spawning = HH_Spawning.Get();
        if (spawning != null && spawned != null) {
            spawning.Adopt(spawned);
        }
    }
}

class HH_VariedZombie : HH_ZombieSpawner {
    Default {
        DropItem "ShotgunGuy";
        DropItem "DoomImp";
        DropItem "Demon";
        DropItem "ChaingunGuy";
        DropItem "ZombieMan";
        DropItem "Revenant";
    }
}

class HH_Spawning : EventHandler {
    Array<HH_Spawner> spawners;
    Array<int> openZones;
    Array<Actor> zombies;
    int ticsTillSpawn;
    bool paused;
    bool warnedClass;

    clearscope static HH_Spawning Get() {
        return HH_Spawning(EventHandler.Find('HH_Spawning'));
    }

    override void WorldLoaded(WorldEvent e) {
        if (e.IsSaveGame) {
            return;
        }
        let iterator = ThinkerIterator.Create('HH_Spawner');
        HH_Spawner spawner;
        while (spawner = HH_Spawner(iterator.Next())) {
            self.spawners.Push(spawner);
        }
        self.openZones.Push(0);
        self.CountDown();
    }

    override void WorldTick() {
        let rounds = HH_Rounds.Get();
        if (rounds == null) {
            return;
        }
        if (!self.paused && rounds.ReadyToSpawn() && self.zombies.Size() < HH_Settings.Int("hh_max_horde") && --self.ticsTillSpawn <= 0) {
            self.TrySpawn(rounds);
            self.CountDown();
        }
        if (Level.maptime % TICRATE == 0) {
            self.Retarget();
            // A safety net: a round can't hang on zombies that never arrived
            if (rounds.phase == HH_Rounds.PHASE_ROUND && rounds.unspawnedZombies <= 0 && self.zombies.Size() == 0 && rounds.zombiesLeft > 0) {
                rounds.unspawnedZombies = rounds.zombiesLeft;
            }
        }
    }

    void CountDown() {
        self.ticsTillSpawn = Random[HH_Spawning](HH_Settings.Int("hh_spawn_delay_min"), max(HH_Settings.Int("hh_spawn_delay_min"), HH_Settings.Int("hh_spawn_delay_max")));
    }

    void TrySpawn(HH_Rounds rounds) {
        Array<HH_Spawner> open;
        foreach (spawner : self.spawners) {
            if (spawner != null && self.IsZoneOpen(spawner.args[0])) {
                open.Push(spawner);
            }
        }
        if (open.Size() == 0) {
            return;
        }
        let spawner = open[Random[HH_Spawning](0, open.Size() - 1)];
        if (self.SpawnZombie(spawner.pos, spawner.angle)) {
            --rounds.unspawnedZombies;
        }
    }

    class<Actor> ZombieClass() {
        class<Actor> type = HH_Settings.Str("hh_zombie_class");
        if (type != null) {
            return type;
        }
        // A bad CVar value: the game's own zombie, else the library's
        type = HH_Settings.Default("hh_zombie_class");
        if (!self.warnedClass) {
            Console.Printf("Horde Hammer: hh_zombie_class \"%s\" isn't a class; spawning %s", HH_Settings.Str("hh_zombie_class"), type != null? type.GetClassName(): 'HH_Zombie');
            self.warnedClass = true;
        }
        return type != null? type: (class<Actor>)('HH_Zombie');
    }

    // Spawns a zombie and says whether it fit; a random zombie set counts once it has picked
    bool SpawnZombie(Vector3 position, double angle) {
        let zombie = Actor.Spawn(self.ZombieClass(), position, ALLOW_REPLACE);
        if (zombie == null) {
            return false;
        }
        zombie.angle = angle;
        if (zombie is 'RandomSpawner') {
            return true;
        }
        if (!zombie.TestMobjLocation()) {
            zombie.Destroy();
            return false;
        }
        self.Adopt(zombie);
        return true;
    }

    void Adopt(Actor zombie) {
        let rounds = HH_Rounds.Get();
        if (rounds != null) {
            zombie.StartHealth = rounds.zombieHealth;
            zombie.health = rounds.zombieHealth;
            zombie.speed += rounds.zombieSpeedBonus;
        }
        zombie.bDropOff = true;
        self.zombies.Push(zombie);
        self.Target(zombie);
    }

    override void WorldThingDied(WorldEvent e) {
        let index = self.zombies.Find(e.Thing);
        if (index == self.zombies.Size()) {
            return;
        }
        self.zombies.Delete(index);
        let rounds = HH_Rounds.Get();
        if (rounds != null) {
            rounds.OnZombieKilled();
        }
        let drops = HH_DropPool.Get();
        if (drops != null) {
            drops.OnZombieKilled(e.Thing);
        }
    }

    override void WorldThingDestroyed(WorldEvent e) {
        let index = self.zombies.Find(e.Thing);
        if (index == self.zombies.Size()) {
            return;
        }
        self.zombies.Delete(index);
        let rounds = HH_Rounds.Get();
        if (rounds != null) {
            rounds.OnZombieLost();
        }
    }

    override void WorldThingSpawned(WorldEvent e) {
        let item = Inventory(e.Thing);
        if (HH_Settings.Bool("hh_remove_items") && item != null && item.owner == null && !(item is 'HH_Drop')) {
            item.Destroy();
        }
    }

    clearscope static bool IsGoodTarget(Actor target) {
        return target != null && target.player != null && target.health > 0 && HH_Util.IsActive(target.PlayerNumber());
    }

    void Target(Actor zombie) {
        if (zombie == null || zombie.health <= 0 || HH_Spawning.IsGoodTarget(zombie.target)) {
            return;
        }
        let player = HH_Util.NearestActive(zombie);
        zombie.target = player;
        if (player != null && zombie.SeeState != null && zombie.InStateSequence(zombie.CurState, zombie.SpawnState)) {
            zombie.SetState(zombie.SeeState);
        }
    }

    // Zombies chasing someone who went down, left or is spectating go after someone else
    void Retarget() {
        foreach (zombie : self.zombies) {
            self.Target(zombie);
        }
    }

    void OpenZone(int zone) {
        if (!self.IsZoneOpen(zone)) {
            self.openZones.Push(zone);
            HH_Events.Fire('zone_opened', zone);
        }
    }

    clearscope bool IsZoneOpen(int zone) const {
        return self.openZones.Find(zone) != self.openZones.Size();
    }

    // Ka-Boom: every zombie dies (and counts)
    void KillAll() {
        Array<Actor> doomed;
        doomed.Copy(self.zombies);
        foreach (zombie : doomed) {
            if (zombie != null && zombie.health > 0) {
                zombie.DamageMobj(null, null, zombie.health, 'Massacre', DMG_FORCED | DMG_NO_PROTECT);
            }
        }
    }
}
