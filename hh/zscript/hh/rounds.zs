// Rounds: how many zombies, how strong, repulsion between rounds, and the end of the game

class HH_Rounds : EventHandler {
    enum EPhase {
        PHASE_WAITING,      // before round 1 (hh_auto_start, or a game starting it itself)
        PHASE_ROUND,        // zombies are coming
        PHASE_DELAY,        // the last zombie died; repulsion is on its way
        PHASE_REPULSION,    // the repulse key holds off the next round
        PHASE_GAME_OVER
    }

    int phase;
    int phaseTics;
    int currentRound;
    int zombieHealth;
    double zombieSpeedBonus;
    int unspawnedZombies;
    int zombiesLeft;
    int lastRepulse[MAXPLAYERS];

    clearscope static HH_Rounds Get() {
        return HH_Rounds(EventHandler.Find('HH_Rounds'));
    }

    clearscope bool IsStarted() const {
        return self.phase != PHASE_WAITING;
    }

    clearscope bool IsOver() const {
        return self.phase == PHASE_GAME_OVER;
    }

    clearscope bool IsBetweenRounds() const {
        return self.phase == PHASE_DELAY || self.phase == PHASE_REPULSION;
    }

    bool ReadyToSpawn() {
        return self.phase == PHASE_ROUND && self.unspawnedZombies > 0;
    }

    override void WorldTick() {
        ++self.phaseTics;
        switch (self.phase) {
        case PHASE_WAITING:
            if (HH_Settings.Bool("hh_auto_start") && self.phaseTics >= HH_Settings.Int("hh_start_delay") && HH_Util.CountInGame() != 0) {
                self.StartGame();
            }
            break;
        case PHASE_DELAY:
            if (self.phaseTics >= HH_Settings.Int("hh_round_delay")) {
                self.BeginRepulsion();
            }
            break;
        case PHASE_REPULSION:
            if (self.RepulsionIsOver()) {
                self.NextRound();
            }
            break;
        }
        if (self.IsStarted() && !self.IsOver() && Level.maptime % TICRATE == 0) {
            self.CheckGameOver();
        }
    }

    void StartGame() {
        if (self.phase != PHASE_WAITING) {
            return;
        }
        self.NextRound();
        HH_Events.Fire('game_started', self.currentRound);
    }

    void NextRound() {
        ++self.currentRound;
        let previous = self.currentRound - 1;
        self.zombieHealth = max(1, HH_Settings.Int("hh_zombie_health_base") + HH_Settings.Int("hh_zombie_health_per_round") * previous);
        let extraPlayers = max(0, HH_Util.CountInGame() - 1);
        self.unspawnedZombies = max(1, HH_Settings.Int("hh_zombie_count_base") + HH_Settings.Int("hh_zombie_count_per_round") * previous + HH_Settings.Int("hh_zombie_count_per_player") * extraPlayers);
        self.zombiesLeft = self.unspawnedZombies;
        self.zombieSpeedBonus = HH_Settings.Float("hh_zombie_speed_per_round") * previous;
        if (HH_Settings.Float("hh_zombie_speed_max") > 0) {
            self.zombieSpeedBonus = min(self.zombieSpeedBonus, HH_Settings.Float("hh_zombie_speed_max"));
        }
        self.phase = PHASE_ROUND;
        self.phaseTics = 0;

        let drops = HH_DropPool.Get();
        if (drops != null) {
            drops.OnRoundStarted();
        }
        S_StartSound(self.currentRound == 1? "hh/game_start": "hh/round_start", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        HH_Players.RespawnSpectators();
        HH_Events.Fire('round_started', self.currentRound);
    }

    void OnZombieKilled() {
        --self.zombiesLeft;
        if (self.phase == PHASE_ROUND && self.zombiesLeft <= 0 && self.unspawnedZombies <= 0) {
            self.EndRound();
        }
    }

    // A zombie went away without dying (removed by a script, fell out of the map): spawn it again
    void OnZombieLost() {
        if (self.phase == PHASE_ROUND) {
            ++self.unspawnedZombies;
        }
    }

    void EndRound() {
        self.phase = PHASE_DELAY;
        self.phaseTics = 0;
        S_StartSound("hh/round_end", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE, pitch: 0.5);
        HH_Events.Fire('round_ended', self.currentRound);
    }

    void BeginRepulsion() {
        self.phase = PHASE_REPULSION;
        self.phaseTics = 0;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            self.lastRepulse[i] = Level.maptime;
        }
    }

    // Repulsion is over when any active player hasn't pressed the repulse key for
    // hh_repulsion_time, so holding off the next round takes everybody
    bool RepulsionIsOver() {
        let anyone = false;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.IsActive(i)) {
                anyone = true;
                if (Level.maptime - self.lastRepulse[i] >= HH_Settings.Int("hh_repulsion_time")) {
                    return true;
                }
            }
        }
        return !anyone;
    }

    void Repulse(int number) {
        if (self.phase == PHASE_REPULSION && number >= 0 && number < MAXPLAYERS) {
            self.lastRepulse[number] = Level.maptime;
        }
    }

    // Nobody left standing, and nobody coming back by themselves (solo Quick Revive)
    void CheckGameOver() {
        if (HH_Util.CountInGame() == 0 || HH_Util.CountActive() != 0) {
            return;
        }
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.InGame(i)) {
                let lastStand = HH_LastStand(players[i].mo.FindInventory('HH_LastStand'));
                if (lastStand != null && lastStand.solo) {
                    return;
                }
            }
        }
        self.EndGame();
    }

    void EndGame() {
        if (self.phase == PHASE_GAME_OVER) {
            return;
        }
        self.phase = PHASE_GAME_OVER;
        self.phaseTics = 0;
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.InGame(i)) {
                players[i].mo.GiveInventory('HH_GameOverSpectate', 1);
            }
        }
        S_StartSound("hh/game_over", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        HH_Events.Fire('game_over', self.currentRound);
    }
}
