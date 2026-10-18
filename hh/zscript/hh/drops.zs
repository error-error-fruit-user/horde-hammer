// Power-up drops: zombies sometimes drop one, and anyone who walks over it takes it for everybody.
// The pool is every HH_Drop with a Pool property, so a game adds its own by subclassing.

class HH_Drop : CustomInventory {
    const BLINK_TICS = 350;     // the last tics on the floor blink

    meta int eventId;           // the number powerup_taken passes along, and the HUD's message
    meta int pool;              // 0 never dropped, 1 from the start, 2 once the box has moved

    property EventId: eventId;
    property Pool: pool;

    int age;

    Default {
        Inventory.PickupMessage "";
        Inventory.PickupSound "hh/powerup_grab";
        FloatBobStrength 0.5;
        Scale 0.75;
        +INVENTORY.ALWAYSPICKUP
        +FLOATBOB
        +NOGRAVITY
    }

    override void Tick() {
        super.Tick();
        if (self.owner != null || self.bDestroyed) {
            return;
        }
        ++self.age;
        let left = HH_Settings.Int("hh_drop_lifetime") - self.age;
        if (left <= 0) {
            self.Destroy();
        } else if (left < HH_Drop.BLINK_TICS) {
            self.bInvisible = (left / (left < HH_Drop.BLINK_TICS / 3? 4: 8)) % 2 == 0;
        }
    }

    // What taking it does; `taker` is the player who walked over it
    virtual void Taken(Actor taker) {}

    static void GiveAll(class<Inventory> type, int amount = 1) {
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.InGame(i)) {
                players[i].mo.GiveInventory(type, amount);
            }
        }
    }

    action void HH_Take() {
        invoker.Taken(self);
        HH_Events.Fire('powerup_taken', self.PlayerNumber(), invoker.eventId);
    }

    States {
    Pickup:
        TNT1 A 0 HH_Take;
        Stop;
    }
}

class HH_Powerup : Powerup {
    Default {
        Powerup.Duration 1050;
        +INVENTORY.UNCLEARABLE
    }

    override void InitEffect() {
        super.InitEffect();
        self.EffectTics = HH_Settings.Int("hh_powerup_duration");
    }

    override void EndEffect() {
        if (self.owner != null) {
            self.owner.A_StartSound("hh/powerup_end", CHAN_AUTO, CHANF_LOCAL);
        }
        super.EndEffect();
    }
}

class HH_DropPool : EventHandler {
    Array<class<HH_Drop> > pool;
    int dropsLeft;
    bool boxMoved;

    clearscope static HH_DropPool Get() {
        return HH_DropPool(EventHandler.Find('HH_DropPool'));
    }

    // The drops that can come now, refilled once each has dropped
    void Fill() {
        self.pool.Clear();
        foreach (type : AllActorClasses) {
            let dropType = (class<HH_Drop>)(type);
            if (dropType == null) {
                continue;
            }
            let when = GetDefaultByType(dropType).pool;
            if (when == 1 || (when == 2 && self.boxMoved)) {
                self.pool.Push(dropType);
            }
        }
    }

    void OnRoundStarted() {
        self.dropsLeft = HH_Settings.Int("hh_drops_per_round");
    }

    void OnBoxMoved() {
        self.boxMoved = true;
        self.Fill();
    }

    void OnZombieKilled(Actor zombie) {
        if (zombie == null || zombie.CurSector.damageAmount != 0 || self.dropsLeft <= 0) {
            return;
        }
        if (Random[HH_Drops](1, max(1, HH_Settings.Int("hh_drop_chance"))) != 1) {
            return;
        }
        if (self.pool.Size() == 0) {
            self.Fill();
            if (self.pool.Size() == 0) {
                return;
            }
        }
        --self.dropsLeft;
        let index = Random[HH_Drops](0, self.pool.Size() - 1);
        let type = self.pool[index];
        self.pool.Delete(index);
        Actor.Spawn(type, zombie.pos + (0, 0, 16), ALLOW_REPLACE);
    }
}

// Insta-Kill: every hit kills
class HH_Instakill : HH_Drop {
    Default {
        HH_Drop.EventId 1;
        HH_Drop.Pool 1;
    }

    override void Taken(Actor taker) {
        S_StartSound("hh/instakill", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        HH_Drop.GiveAll('HH_InstakillPower');
    }

    States {
    Spawn:
        HHIK A -1 Bright;
        Stop;
    }
}

class HH_InstakillPower : HH_Powerup {
    Default {
        Inventory.Icon "HHIIK";
    }

    override void ModifyDamage(int damage, Name damageType, out int newDamage, bool passive, Actor inflictor, Actor source, int flags) {
        if (!passive && source != null && source != self.owner && source.bIsMonster) {
            newDamage = max(damage, source.health);
        }
    }
}

// Double Points: points are worth twice as much (twice again for each more taken while it lasts)
class HH_DoublePoints : HH_Drop {
    Default {
        HH_Drop.EventId 2;
        HH_Drop.Pool 1;
    }

    override void Taken(Actor taker) {
        S_StartSound("hh/double_points", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        HH_Drop.GiveAll('HH_DoublePointsPower');
    }

    States {
    Spawn:
        HHDP A -1 Bright;
        Stop;
    }
}

class HH_DoublePointsPower : HH_Powerup {
    Default {
        Inventory.Icon "HHIDP";
    }

    override bool HandlePickup(Inventory item) {
        if (item.GetClass() == self.GetClass()) {
            ++self.amount;
        }
        return super.HandlePickup(item);
    }
}

// Max Ammo: full reserve ammo for every weapon every player holds
class HH_MaxAmmo : HH_Drop {
    Default {
        HH_Drop.EventId 3;
        HH_Drop.Pool 1;
    }

    override void Taken(Actor taker) {
        S_StartSound("hh/max_ammo", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        for (let i = 0; i < MAXPLAYERS; ++i) {
            let manager = HH_Util.ManagerOf(i);
            if (manager != null && !manager.spectating) {
                manager.FillWeapons();
            }
        }
    }

    States {
    Spawn:
        HHMA A -1 Bright;
        Stop;
    }
}

// Ka-Boom: every zombie dies, and everyone gets points
class HH_Kaboom : HH_Drop {
    Default {
        HH_Drop.EventId 4;
        HH_Drop.Pool 1;
    }

    override void Taken(Actor taker) {
        S_StartSound("hh/kaboom", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (HH_Util.InGame(i)) {
                HH_Points.Give(players[i].mo, HH_Settings.Int("hh_kaboom_points"));
            }
        }
        let spawning = HH_Spawning.Get();
        if (spawning != null) {
            spawning.KillAll();
        }
    }

    States {
    Spawn:
        HHNK A -1 Bright;
        Stop;
    }
}

// Fire Sale: a cheap box at every location for a while (only once the box has moved)
class HH_FireSale : HH_Drop {
    Default {
        HH_Drop.EventId 5;
        HH_Drop.Pool 2;
    }

    override void Taken(Actor taker) {
        S_StartSound("hh/fire_sale", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        HH_Drop.GiveAll('HH_FireSalePower');
        let boxes = HH_MysteryBoxHandler.Get();
        if (boxes != null) {
            boxes.StartFireSale();
        }
    }

    States {
    Spawn:
        HHFS A -1 Bright;
        Stop;
    }
}

// Only shows on the HUD; the box handler keeps the Fire Sale's own time
class HH_FireSalePower : HH_Powerup {
    Default {
        Inventory.Icon "HHIFS";
    }
}
