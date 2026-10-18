// The mystery box: pay, watch it spin, take the weapon it gives. Sometimes it moves instead.

class HH_MysteryBox : HH_Interactable {
    HH_MysteryBoxLocation location;
    bool shouldFade;
    bool canMove;
    int spinCount;

    Default {
        Radius 40;
        Height 40;
        +WALLSPRITE
        +SOLID
    }

    static HH_MysteryBox SpawnAt(HH_MysteryBoxLocation location, bool canMove) {
        let box = HH_MysteryBox(Actor.Spawn('HH_MysteryBox', location.pos, ALLOW_REPLACE));
        box.location = location;
        box.angle = location.angle;
        box.canMove = canMove;
        return box;
    }

    int Cost() {
        let handler = HH_MysteryBoxHandler.Get();
        return handler != null && handler.fireSaleTics > 0? HH_Settings.Int("hh_box_fire_sale_cost"): HH_Settings.Int("hh_box_cost");
    }

    override void DoTouch(PlayerPawn player, HH_InventoryManager manager) {
        HH_Interactable.HintCost(manager, self.Cost());
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (!HH_Points.Take(player, self.Cost())) {
            player.A_StartSound("hh/denied", CHAN_AUTO);
            return false;
        }
        self.Open(player);
        HH_Events.Fire('box_opened', player.PlayerNumber());
        return true;
    }

    // Where the weapon floats: a little in front of the box, above it
    Vector3 OfferPosition() {
        let offset = Actor.AngleToVector(self.angle, 6);
        return self.pos + (offset.x, offset.y, 15);
    }

    bool ShouldMove() {
        return self.canMove && self.spinCount > HH_Settings.Int("hh_box_min_spins") && Random[HH_Box](1, max(1, HH_Settings.Int("hh_box_move_chance"))) == 1;
    }

    State WhenShouldFade(StateLabel label) {
        return self.shouldFade? ResolveState(label): ResolveState(null);
    }

    void Open(PlayerPawn receiver) {
        ++self.spinCount;
        self.bSpecial = false;
        HH_MysteryBoxSpin.SpawnFor(self, receiver);
        self.SetStateLabel("Open");
    }

    void Close() {
        self.SetStateLabel("Close");
    }

    void FinishClosing() {
        self.bSpecial = true;
    }

    // Goes away: now if nobody is using it, else once it closes
    void Fade() {
        self.shouldFade = true;
        if (self.bSpecial) {
            self.bSpecial = false;
            self.SetStateLabel("Fade");
        }
    }

    States {
    Close:
        HHBX B 20;
        TNT1 A 0 WhenShouldFade("Fade");
        TNT1 A 0 FinishClosing;
    Spawn:
        HHBX A -1;
        Stop;
    Open:
        TNT1 A 0 A_StartSound("hh/box_open", CHAN_AUTO, volume: 0.5);
        HHBX B -1 Bright;
        Stop;
    Fade:
        HHBX A 20;
        Stop;
    }
}

// The weapons flashing by while the box spins
class HH_MysteryBoxSpin : Actor {
    PlayerPawn receiver;
    HH_MysteryBox box;
    class<Weapon> shown;

    Default {
        +NOGRAVITY
        +WALLSPRITE
        +NOBLOCKMAP
    }

    static HH_MysteryBoxSpin SpawnFor(HH_MysteryBox box, PlayerPawn receiver) {
        let spin = HH_MysteryBoxSpin(Actor.Spawn('HH_MysteryBoxSpin', box.OfferPosition(), ALLOW_REPLACE));
        spin.receiver = receiver;
        spin.box = box;
        spin.angle = box.angle;
        return spin;
    }

    void Spin() {
        self.shown = HH_WeaponPool.Show(self.receiver, self.shown);
        if (self.shown != null) {
            [self.sprite, self.frame, self.scale] = HH_Pickup.GetInfo(GetDefaultByType(self.shown));
        }
    }

    void Finish() {
        if (self.box == null) {
            return;
        }
        if (self.box.ShouldMove()) {
            HH_MysteryBoxLock.SpawnFor(self.box, self.receiver);
            return;
        }
        let item = HH_WeaponPool.Choose(self.receiver, self.shown);
        if (item == null) {
            item = HH_WeaponPool.Choose(self.receiver);
        }
        if (item == null) {
            // Nothing left to give this player: their points back
            if (self.receiver != null) {
                HH_Points.Give(self.receiver, self.box.Cost(), true);
            }
            self.box.Close();
            return;
        }
        HH_MysteryBoxPickup.SpawnFor(self.box, item, self.receiver);
    }

    States {
    Spawn:
        HHNL A 0 NoDelay Spin;
        #### ###### 5 Bright Spin;
        #### #### 8 Bright Spin;
        #### ### 11 Bright Spin;
        #### ## 15 Bright Spin;
        #### # 19 Bright Spin;
        TNT1 A 0 Finish;
        Stop;
    }
}

// The box giving up on this spot: a lock spins faster and faster as it rises into the air, then
// the player gets their points back and the box goes somewhere else
class HH_MysteryBoxLock : Actor {
    const SPIN_START = 4.0;     // degrees per tic at first
    const SPIN_GAIN = 0.35;     // added each tic
    const SPIN_MOST = 40.0;
    const RISE_DELAY = 20;      // tics spinning in place before it rises
    const RISE_SPEED = 1.5;     // map units per tic

    PlayerPawn receiver;
    HH_MysteryBox box;
    double spinSpeed;
    int age;

    Default {
        RenderStyle "Translucent";
        Alpha 1.0;
        +NOGRAVITY
        +WALLSPRITE
        +NOBLOCKMAP
        +NOINTERACTION
    }

    static HH_MysteryBoxLock SpawnFor(HH_MysteryBox box, PlayerPawn receiver) {
        let lock = HH_MysteryBoxLock(Actor.Spawn('HH_MysteryBoxLock', box.OfferPosition(), ALLOW_REPLACE));
        lock.box = box;
        lock.receiver = receiver;
        lock.angle = box.angle;
        lock.spinSpeed = HH_MysteryBoxLock.SPIN_START;
        return lock;
    }

    override void Tick() {
        super.Tick();
        if (self.bDestroyed) {
            return;
        }
        ++self.age;
        self.angle += self.spinSpeed;
        self.spinSpeed = min(self.spinSpeed + HH_MysteryBoxLock.SPIN_GAIN, HH_MysteryBoxLock.SPIN_MOST);
        if (self.age > HH_MysteryBoxLock.RISE_DELAY) {
            self.SetZ(self.pos.z + HH_MysteryBoxLock.RISE_SPEED);
        }
    }

    void MoveBox() {
        if (self.receiver != null && self.box != null) {
            HH_Points.Give(self.receiver, HH_Settings.Int("hh_box_cost"), true);
        }
        let handler = HH_MysteryBoxHandler.Get();
        if (handler != null) {
            handler.MoveActiveBox();
        }
        if (self.box != null) {
            self.box.Close();
        }
        self.Destroy();
    }

    States {
    Spawn:
        HHLK A 90 Bright;
        HHLK AAAAAAAAAA 1 Bright A_FadeOut(0.1, FTF_CLAMP);
        TNT1 A 0 MoveBox;
        Stop;
    }
}

// The weapon the box gave, which only its receiver can take
class HH_MysteryBoxPickup : HH_Pickup {
    PlayerPawn receiver;
    HH_MysteryBox box;
    Actor particles;
    int ticsLeft;

    Default {
        FloatBobStrength 0.1;
        Radius 50;
        +NOGRAVITY
        +WALLSPRITE
        +FLOATBOB
    }

    static HH_MysteryBoxPickup SpawnFor(HH_MysteryBox box, class<Weapon> item, PlayerPawn receiver) {
        let pickup = HH_MysteryBoxPickup(Actor.Spawn('HH_MysteryBoxPickup', box.OfferPosition(), ALLOW_REPLACE));
        pickup.item = item;
        pickup.receiver = receiver;
        pickup.box = box;
        pickup.angle = box.angle;
        pickup.ticsLeft = HH_Settings.Int("hh_box_pickup_time");
        [pickup.sprite, pickup.frame, pickup.scale] = HH_Pickup.GetInfo(GetDefaultByType(item));
        pickup.particles = Actor.Spawn('BlackParticleFountain', (box.pos.xy, box.floorz), ALLOW_REPLACE);
        return pickup;
    }

    override void Tick() {
        super.Tick();
        if (--self.ticsLeft <= 0) {
            self.CloseBox();
        }
    }

    override void DoTouch(PlayerPawn player, HH_InventoryManager manager) {
        if (player == self.receiver) {
            super.DoTouch(player, manager);
        }
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (player != self.receiver || !self.CanTake(player, manager)) {
            return false;
        }
        let box = self.box;
        let particles = self.particles;
        self.GiveTo(player, manager);
        if (box != null) {
            box.Close();
        }
        if (particles != null) {
            particles.Destroy();
        }
        return true;
    }

    void CloseBox() {
        if (self.box != null) {
            self.box.Close();
        }
        if (self.particles != null) {
            self.particles.Destroy();
        }
        self.Destroy();
    }

    States {
    Spawn:
        #### # -1 Bright;
        Stop;
    }
}

class HH_MysteryBoxLocation : Actor {
    HH_MysteryBox box;

    Default {
        //$Category "Horde Hammer"
        //$Title "Mystery Box Location"
        //$Sprite HHBLA0
        //$Arg0 "Start"
        //$Arg0Type 11
        //$Arg0Enum { 0 = "Maybe"; 1 = "Always here first"; -1 = "Never here first"; }
        RenderStyle "None";
        +NOBLOCKMAP
        +NOGRAVITY
        +DONTSPLASH
        +NOTONAUTOMAP
    }

    void SpawnBox(bool canMove) {
        if (self.box == null) {
            self.box = HH_MysteryBox.SpawnAt(self, canMove);
        } else {
            self.box.canMove = canMove;
        }
    }

    void RemoveBox() {
        if (self.box != null) {
            self.box.Fade();
            self.box = null;
        }
    }

    States {
    Spawn:
        TNT1 A -1;
        Stop;
    }
}

class HH_MysteryBoxHandler : EventHandler {
    Array<HH_MysteryBoxLocation> locations;
    int activeIndex;
    int moveCount;
    int fireSaleTics;

    clearscope static HH_MysteryBoxHandler Get() {
        return HH_MysteryBoxHandler(EventHandler.Find('HH_MysteryBoxHandler'));
    }

    override void WorldLoaded(WorldEvent e) {
        if (e.IsSaveGame) {
            return;
        }
        Array<int> starts;
        Array<int> candidates;
        let iterator = ThinkerIterator.Create('HH_MysteryBoxLocation');
        HH_MysteryBoxLocation location;
        while (location = HH_MysteryBoxLocation(iterator.Next())) {
            let index = self.locations.Size();
            self.locations.Push(location);
            if (location.args[0] > 0) {
                starts.Push(index);
            } else if (location.args[0] == 0) {
                candidates.Push(index);
            }
        }
        if (self.locations.Size() == 0) {
            return;
        }
        if (starts.Size() != 0) {
            self.activeIndex = starts[0];
        } else if (candidates.Size() != 0) {
            self.activeIndex = candidates[Random[HH_Box](0, candidates.Size() - 1)];
        } else {
            self.activeIndex = Random[HH_Box](0, self.locations.Size() - 1);
        }
        self.locations[self.activeIndex].SpawnBox(self.locations.Size() > 1);
    }

    override void WorldTick() {
        if (self.fireSaleTics > 0 && --self.fireSaleTics == 0) {
            self.EndFireSale();
        }
    }

    void MoveActiveBox() {
        if (self.locations.Size() < 2) {
            return;
        }
        if (++self.moveCount == 1) {
            let drops = HH_DropPool.Get();
            if (drops != null) {
                drops.OnBoxMoved();
            }
        }
        self.locations[self.activeIndex].RemoveBox();
        let next = Random[HH_Box](0, self.locations.Size() - 2);
        if (next >= self.activeIndex) {
            ++next;
        }
        self.activeIndex = next;
        self.locations[next].SpawnBox(self.fireSaleTics == 0);
        S_StartSound("hh/box_move", CHAN_AUTO, CHANF_UI, attenuation: ATTN_NONE);
        HH_Events.Fire('box_moved');
    }

    // Fire Sale: a box at every location, cheap, until it runs out
    void StartFireSale() {
        self.fireSaleTics = HH_Settings.Int("hh_powerup_duration");
        for (let i = 0; i < self.locations.Size(); ++i) {
            self.locations[i].SpawnBox(false);
        }
    }

    void EndFireSale() {
        for (let i = 0; i < self.locations.Size(); ++i) {
            if (i == self.activeIndex) {
                self.locations[i].SpawnBox(self.locations.Size() > 1);
            } else {
                self.locations[i].RemoveBox();
            }
        }
    }
}
