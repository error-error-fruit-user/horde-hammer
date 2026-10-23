// The mystery box: pay, watch it spin, take the weapon it gives. Sometimes it moves instead.
//
// Kicked, it does more: a spinning box spins again for hh_box_respin_cost (the only thing that can
// put a player in debt); the weapon it offers falls to the floor for anyone, for
// hh_box_kick_drop_cost; and a box shot
// on both sides by the kicker shortly before shows its roster (HH_MysteryBoxRoster). Explosions
// and projectiles knock it around.

class HH_MysteryBox : HH_Interactable {
    const KNOCK_MOST = 14.0;    // the fastest a hit sends it, in map units per tic
    const SPIN_DECAY = 0.9;     // what is left of its turning each tic
    const MELEE_REACH = 128;    // how close a melee weapon's hit lands to count as one

    HH_MysteryBoxLocation location;
    bool shouldFade;
    bool canMove;
    int spinCount;
    HH_MysteryBoxSpin spin;
    HH_MysteryBoxPickup offer;
    HH_MysteryBoxRoster roster;
    double turning;             // degrees a tic, from being knocked
    int leftShot[MAXPLAYERS];   // when each player last shot each side (level.maptime + 1)
    int rightShot[MAXPLAYERS];

    Default {
        Radius 40;
        Height 40;
        Health 1000;
        BounceType "Doom";
        BounceFactor 0.35;
        WallBounceFactor 0.6;
        +WALLSPRITE
        +SOLID
        +SHOOTABLE
        +NOBLOOD
        +NOTAUTOAIMED
        +DONTTHRUST
        +BOUNCEONACTORS
        -BOUNCEAUTOOFF
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
        if (self.roster != null) {
            self.roster.Bump(player);
            return;
        }
        HH_Interactable.HintCost(manager, self.Cost());
    }

    override bool DoUse(PlayerPawn player, HH_InventoryManager manager) {
        if (self.roster != null) {
            self.roster.Use(player);
            return false;
        }
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
        self.spin = HH_MysteryBoxSpin.SpawnFor(self, receiver);
        self.SetStateLabel("Open");
    }

    void Close() {
        if (self.roster != null) {
            self.roster.Destroy();
            self.roster = null;
        }
        self.SetStateLabel("Close");
    }

    // Hits: the kick does what the box is doing allows; a shot from a player marks the side it
    // hit; explosions and projectiles knock the box. Nothing hurts it.
    override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle) {
        let player = PlayerPawn(source);
        let at = inflictor != null? inflictor.pos: source != null? source.pos: self.pos;
        if (player != null && HH_MysteryBox.IsMelee(player, inflictor, mod)) {
            self.Kicked(player);
            return 0;
        }
        if (player != null && player.player != null && !(flags & DMG_EXPLOSION)) {
            let number = player.PlayerNumber();
            if (self.SideOf(at) < 0) {
                self.leftShot[number] = level.maptime + 1;
            } else {
                self.rightShot[number] = level.maptime + 1;
            }
        }
        if ((flags & DMG_EXPLOSION) || (inflictor != null && inflictor.bMissile)) {
            HH_MysteryBox.Knock(self, at, damage);
        }
        return 0;
    }

    // Whether a hit is melee: the kick, any weapon's melee damage (the fist, the chainsaw, knives),
    // a mod's own kick or punch, or a close hit from a melee weapon in hand
    static bool IsMelee(PlayerPawn player, Actor inflictor, Name mod) {
        if (inflictor != null && inflictor.bMissile) {
            return false;
        }
        String kind = mod;
        kind = kind.MakeLower();
        if (kind.IndexOf("kick") >= 0 || kind.IndexOf("melee") >= 0 || kind.IndexOf("punch") >= 0 || kind.IndexOf("fist") >= 0) {
            return true;
        }
        let weapon = player.player != null? player.player.ReadyWeapon: null;
        return weapon != null && weapon.bMeleeWeapon && (inflictor == null || player.Distance2D(inflictor) <= HH_MysteryBox.MELEE_REACH);
    }

    // Which side of the box a point is on, as the box faces: below 0 its left, above its right
    double SideOf(Vector3 point) {
        let right = Actor.AngleToVector(self.angle - 90);
        let offset = level.Vec2Diff(self.pos.xy, point.xy);
        return offset dot right;
    }

    // Sends a box flying away from `from`, turning it by where it was hit: an explosion's or a
    // projectile's work, or anything a game's weapon calls it for (a hit that does no damage).
    // Does nothing to anything but a box.
    static void Knock(Actor thing, Vector3 from, double force) {
        let box = HH_MysteryBox(thing);
        if (box == null || !HH_Settings.Bool("hh_box_push")) {
            return;
        }
        let away = level.Vec2Diff(from.xy, box.pos.xy);
        let direction = away.Length() > 1? away.Unit(): Actor.AngleToVector(box.angle + 180);
        let speed = clamp(force * 0.05, 3, HH_MysteryBox.KNOCK_MOST);
        box.vel += (direction.x * speed, direction.y * speed, speed * 0.6);
        let length = box.vel.xy.Length();
        if (length > HH_MysteryBox.KNOCK_MOST) {
            box.vel.xy *= HH_MysteryBox.KNOCK_MOST / length;
        }
        box.turning += (box.SideOf(from) < 0? -1: 1) * speed * 2;
    }

    override void Tick() {
        super.Tick();
        if (self.bDestroyed) {
            return;
        }
        if (abs(self.turning) > 0.05) {
            self.angle += self.turning;
            self.turning *= HH_MysteryBox.SPIN_DECAY;
        } else {
            self.turning = 0;
        }
    }

    // Whether `player` shot both sides of the box within the reveal time
    bool Marked(PlayerPawn player) {
        let number = player.PlayerNumber();
        let window = HH_Settings.Int("hh_roster_reveal_time");
        let left = self.leftShot[number];
        let right = self.rightShot[number];
        return left > 0 && right > 0 && level.maptime + 1 - min(left, right) <= window;
    }

    void Kicked(PlayerPawn player) {
        let manager = HH_InventoryManager.Of(player);
        if (manager == null || !manager.IsActive()) {
            return;
        }
        if (self.spin != null) {
            HH_Points.Charge(player, HH_Settings.Int("hh_box_respin_cost"));
            self.spin.Restart();
            self.A_StartSound("hh/box_open", CHAN_AUTO, volume: 0.5);
        } else if (self.offer != null) {
            if (HH_Points.Take(player, HH_Settings.Int("hh_box_kick_drop_cost"))) {
                self.offer.KnockToFloor();
            } else {
                player.A_StartSound("hh/denied", CHAN_AUTO);
            }
        } else if (self.roster != null) {
            self.roster.Kicked(player);
        } else if (self.bSpecial && self.Marked(player)) {
            let number = player.PlayerNumber();
            self.leftShot[number] = 0;
            self.rightShot[number] = 0;
            self.roster = HH_MysteryBoxRoster.SpawnFor(self, player);
            self.A_StartSound("hh/box_open", CHAN_AUTO, volume: 0.5);
            self.SetStateLabel("Open");
            HH_Events.Fire('box_roster_shown', player.PlayerNumber());
        }
    }

    void FinishClosing() {
        self.bSpecial = true;
    }

    // Goes away: now if nobody is using it, else once it closes
    void Fade() {
        self.shouldFade = true;
        if (self.roster != null) {
            self.roster.Destroy();
            self.roster = null;
            self.SetStateLabel("Close");
        }
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

    // Stays over the box, wherever it is knocked
    override void Tick() {
        super.Tick();
        if (!self.bDestroyed && self.box != null) {
            self.SetOrigin(self.box.OfferPosition(), true);
            self.angle = self.box.angle;
        }
    }

    // Kicked while spinning: it starts over
    void Restart() {
        self.SetStateLabel("Spawn");
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
        self.box.spin = null;
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
        self.box.offer = HH_MysteryBoxPickup.SpawnFor(self.box, item, self.receiver);
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
        if (self.box != null) {
            let over = self.box.OfferPosition();
            self.SetOrigin((over.xy, self.pos.z), true);
        }
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
        pickup.fullAmmo = true;
        [pickup.sprite, pickup.frame, pickup.scale] = HH_Pickup.GetInfo(GetDefaultByType(item));
        pickup.particles = Actor.Spawn('BlackParticleFountain', (box.pos.xy, box.floorz), ALLOW_REPLACE);
        return pickup;
    }

    override void Tick() {
        super.Tick();
        if (self.bDestroyed) {
            return;
        }
        if (self.box != null) {
            self.SetOrigin(self.box.OfferPosition(), true);
            self.angle = self.box.angle;
            if (self.particles != null) {
                self.particles.SetOrigin((self.box.pos.xy, self.box.floorz), true);
            }
        }
        if (--self.ticsLeft <= 0) {
            self.CloseBox();
        }
    }

    // Kicked: the weapon falls in front of the box, for anyone to take
    void KnockToFloor() {
        let dropped = HH_Pickup(Actor.Spawn('HH_Pickup', self.pos, ALLOW_REPLACE));
        if (dropped != null) {
            dropped.item = self.item;
            dropped.fullAmmo = true;
            dropped.angle = self.angle;
            [dropped.sprite, dropped.frame, dropped.scale] = HH_Pickup.GetInfo(GetDefaultByType(self.item));
            dropped.vel = (Actor.AngleToVector(self.angle, 3), 3);
        }
        self.CloseBox();
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
            box.offer = null;
            box.Close();
        }
        if (particles != null) {
            particles.Destroy();
        }
        return true;
    }

    void CloseBox() {
        if (self.box != null) {
            self.box.offer = null;
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

// The box's roster: every weapon the loaded files have, one at a time over the box, its name on
// the HUD of everyone near (blinking red when the box can't give it to them). It pages by itself;
// whoever opened it pages it with Use (crouched, backwards) and kicks the shown weapon to unlock
// it for hh_unlock_cost, or to turn an unlocked one off and on again (HH_InventoryManager keeps
// unlocks in the player's hh_unlocked). It closes once it has shown every weapon and nobody has
// bumped or used it for hh_roster_idle_time. An opener who walks away or goes down lets it go:
// the next player to use it takes it over.
class HH_MysteryBoxRoster : Actor {
    const SEEN_RANGE = 512;     // how near the HUD shows the name
    const HOLD_RANGE = 384;     // how far its opener can go and keep it

    HH_MysteryBox box;
    PlayerPawn opener;
    Array<class<Weapon> > weapons;
    int index;
    int pageTics;
    int pagesShown;
    int idleTics;

    Default {
        +NOGRAVITY
        +WALLSPRITE
        +NOBLOCKMAP
        +NOINTERACTION
        +BRIGHT
    }

    static HH_MysteryBoxRoster SpawnFor(HH_MysteryBox box, PlayerPawn opener) {
        let roster = HH_MysteryBoxRoster(Actor.Spawn('HH_MysteryBoxRoster', box.OfferPosition(), ALLOW_REPLACE));
        roster.box = box;
        roster.opener = opener;
        roster.angle = box.angle;
        HH_WeaponPool.Everything(roster.weapons);
        roster.Show();
        return roster;
    }

    class<Weapon> Shown() {
        return self.weapons.Size() != 0? self.weapons[self.index]: null;
    }

    void Show() {
        let shown = self.Shown();
        if (shown != null) {
            [self.sprite, self.frame, self.scale] = HH_Pickup.GetInfo(GetDefaultByType(shown));
        }
    }

    void Page(int step) {
        let count = self.weapons.Size();
        if (count == 0) {
            return;
        }
        self.index = (self.index + step + count) % count;
        self.Show();
    }

    bool Controls(PlayerPawn player) {
        return player != null && player == self.opener;
    }

    void Bump(PlayerPawn player) {
        if (self.Controls(player)) {
            self.idleTics = 0;
        }
    }

    void Use(PlayerPawn player) {
        if (self.opener == null) {
            self.opener = player;
        }
        if (!self.Controls(player) || player.player == null) {
            return;
        }
        let back = (player.player.cmd.buttons & BT_CROUCH) != 0 || player.player.crouchFactor < 1;
        self.Page(back? -1: 1);
        self.idleTics = 0;
        self.pageTics = 0;
        player.A_StartSound("hh/box_open", CHAN_AUTO, volume: 0.3);
    }

    // The kick: unlock what the box can't give, or turn an unlocked weapon off or on again
    void Kicked(PlayerPawn player) {
        let manager = HH_InventoryManager.Of(player);
        let shown = self.Shown();
        if (!self.Controls(player) || manager == null || shown == null) {
            return;
        }
        self.idleTics = 0;
        if (manager.IsUnlocked(shown)) {
            manager.ToggleUnlocked(shown);
            player.A_StartSound("hh/purchase", CHAN_AUTO);
        } else if (HH_WeaponPool.Gives(player, shown, false)) {
            player.A_StartSound("hh/denied", CHAN_AUTO);
        } else if (HH_Points.Take(player, HH_Settings.Int("hh_unlock_cost"))) {
            manager.Unlock(shown);
            player.A_StartSound("hh/purchase", CHAN_AUTO);
            HH_Events.Fire('weapon_unlocked', player.PlayerNumber());
        } else {
            player.A_StartSound("hh/denied", CHAN_AUTO);
        }
    }

    override void Tick() {
        super.Tick();
        if (self.bDestroyed) {
            return;
        }
        if (self.box == null || self.weapons.Size() == 0) {
            self.Destroy();
            return;
        }
        self.SetOrigin(self.box.OfferPosition(), true);
        self.angle = self.box.angle;

        // an opener who left or went down lets it go
        let manager = HH_InventoryManager.Of(self.opener);
        if (self.opener != null && (manager == null || !manager.IsActive() || self.opener.Distance3D(self.box) > HH_MysteryBoxRoster.HOLD_RANGE)) {
            self.opener = null;
        }

        ++self.idleTics;
        // it pages by itself while nobody is paging it
        if (self.idleTics >= HH_Settings.Int("hh_roster_page_time") && ++self.pageTics >= HH_Settings.Int("hh_roster_page_time")) {
            self.pageTics = 0;
            ++self.pagesShown;
            self.Page(1);
        }
        if (self.pagesShown >= self.weapons.Size() && self.idleTics >= HH_Settings.Int("hh_roster_idle_time")) {
            let box = self.box;
            box.roster = null;
            self.Destroy();
            box.Close();
            return;
        }

        let shown = self.Shown();
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (!HH_Util.InGame(i)) {
                continue;
            }
            let pawn = players[i].mo;
            let viewer = HH_InventoryManager.Of(pawn);
            if (viewer != null && viewer.IsActive() && pawn.Distance3D(self) <= HH_MysteryBoxRoster.SEEN_RANGE) {
                viewer.hud.SetRoster(GetDefaultByType(shown).GetTag(), HH_WeaponPool.Gives(pawn, shown));
            }
        }
    }

    States {
    Spawn:
        #### # -1 Bright;
        Stop;
    }
}
