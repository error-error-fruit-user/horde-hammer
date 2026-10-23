// Each player's state in a zombies game: the weapons they carry, their perks, whether they are
// down or spectating, and what their HUD shows. Every player gets one when they enter (HH_Players).

class HH_InventoryManager : Inventory {
    bool lastStand, spectating, gameOver;
    bool switchWeapon;                  // whether the weapon keys work (not while drinking or down)
    bool fastReload, doubleFire;        // Speed Cola and Double Tap
    int ticsSinceSwitch;

    Array<class<HH_Perk> > perks;
    Array<Weapon> weapons;              // the weapons that count against hh_max_weapons, in slot order
    class<Weapon> melee, startingWeapon;
    bool scanned;                       // weapons and melee found after the player got their items
    bool skipPickup;                    // giving a weapon that shouldn't count (last stand)

    HH_HudState hud;
    // Weapons unlocked from the box's roster, by class name, "-" in front when turned off; kept in
    // the player's hh_unlocked so they stay unlocked whenever that class is loaded again
    Array<String> unlocked;

    property SwitchDelay: ticsSinceSwitch;

    Default {
        HH_InventoryManager.SwitchDelay 5;
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
        +INVENTORY.UNCLEARABLE
        +INVENTORY.PERSISTENTPOWER
    }

    clearscope static HH_InventoryManager Of(Actor player) {
        if (player == null) {
            return null;
        }
        return HH_InventoryManager(player.FindInventory('HH_InventoryManager'));
    }

    // Whether a weapon class counts against hh_max_weapons: melee and drinks don't
    static bool Counts(class<Weapon> type) {
        if (type == null) {
            return false;
        }
        let zombiesWeapon = (class<HH_Weapon>)(type);
        if (zombiesWeapon != null) {
            return GetDefaultByType(zombiesWeapon).counted;
        }
        return GetDefaultByType(type).ammoType1 != null;
    }

    // The weapon the player holds that is `type` as far as they can tell: that class, one derived
    // from it or one it derives from (Brutal Doom's purist versions), or its upgrade or what it
    // upgrades; null when there is none
    static Weapon Held(Actor player, class<Weapon> type) {
        if (player == null || type == null) {
            return null;
        }
        let upgrade = HH_InventoryManager.UpgradeOf(type);
        for (let item = player.Inv; item != null; item = item.Inv) {
            let weapon = Weapon(item);
            if (weapon == null) {
                continue;
            }
            let held = weapon.GetClass();
            if (HH_InventoryManager.Related(held, type) || held == upgrade || HH_InventoryManager.UpgradeOf(held) == type) {
                return weapon;
            }
        }
        return null;
    }

    static class<Weapon> UpgradeOf(class<Weapon> type) {
        let zombiesWeapon = (class<HH_Weapon>)(type);
        return zombiesWeapon != null? GetDefaultByType(zombiesWeapon).upgrade: null;
    }

    // One class is the other or derives from it
    static bool Related(class<Weapon> one, class<Weapon> other) {
        for (Class<Object> parent = one; parent != null; parent = parent.GetParentClass()) {
            if (parent == other) {
                return true;
            }
        }
        for (Class<Object> parent = other; parent != null; parent = parent.GetParentClass()) {
            if (parent == one) {
                return true;
            }
        }
        return false;
    }

    clearscope bool IsActive() const {
        return self.owner != null && self.owner.health > 0 && !self.lastStand && !self.spectating && !self.gameOver;
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        self.hud = new('HH_HudState');
        self.switchWeapon = true;
        if (other.player != null) {
            let saved = CVar.GetCVar('hh_unlocked', other.player);
            if (saved != null && saved.GetString() != "") {
                saved.GetString().Split(self.unlocked, ",", TOK_SKIPEMPTY);
            }
        }
        if (HH_Settings.Float("hh_player_speed") > 0) {
            other.speed = HH_Settings.Float("hh_player_speed");
        }
    }

    override void Tick() {
        super.Tick();
        if (self.owner == null) {
            return;
        }
        ++self.ticsSinceSwitch;
        if (!self.scanned && self.owner.player != null && self.owner.player.ReadyWeapon != null) {
            self.Scan();
        }
        self.hud.Update();
    }

    // Finds the weapons the player started with: the first counted one is the starting weapon,
    // one without ammo is melee
    void Scan() {
        self.scanned = true;
        self.weapons.Clear();
        for (let item = self.owner.Inv; item != null; item = item.Inv) {
            let weapon = Weapon(item);
            if (weapon == null || weapon is 'HH_Drink') {
                continue;
            }
            if (HH_InventoryManager.Counts(weapon.GetClass())) {
                self.weapons.Push(weapon);
            } else if (self.melee == null && weapon.ammoType1 == null) {
                // equipment the player starts with (grenades) has ammo, and isn't melee
                self.melee = weapon.GetClass();
            }
        }
        let ready = self.owner.player.ReadyWeapon;
        if (ready != null && HH_InventoryManager.Counts(ready.GetClass())) {
            self.startingWeapon = ready.GetClass();
        } else if (self.weapons.Size() != 0) {
            self.startingWeapon = self.weapons[0].GetClass();
        }
    }

    override bool HandlePickup(Inventory item) {
        if (self.skipPickup) {
            return super.HandlePickup(item);
        }
        let drink = HH_Drink(item);
        if (drink != null) {
            if (self.fastReload) {
                drink.ActivateFastReload();
            }
            return super.HandlePickup(item);
        }
        let weapon = Weapon(item);
        if (weapon != null && self.scanned && !self.lastStand && self.owner.FindInventory(weapon.GetClass()) == null
                && HH_InventoryManager.Counts(weapon.GetClass())) {
            if (self.AtCapacity()) {
                self.DropCurrent();
            }
            let zombiesWeapon = HH_Weapon(weapon);
            if (zombiesWeapon != null) {
                if (self.fastReload) {
                    zombiesWeapon.ActivateFastReload();
                }
                if (self.doubleFire) {
                    zombiesWeapon.ActivateDoubleFire();
                }
            }
            self.weapons.Push(weapon);
        }
        return super.HandlePickup(item);
    }

    // Throws away the weapon in hand (or the one coming up) to make room for a new one
    void DropCurrent() {
        let current = self.owner.player.ReadyWeapon;
        if (current == null || !self.Owns(current)) {
            current = self.owner.player.PendingWeapon;
        }
        if (current == null || current == WP_NOCHANGE || !self.Owns(current)) {
            current = self.weapons[self.weapons.Size() - 1];
        }
        self.Abandon(current);
        if (current.ammoType1 != null) {
            self.owner.SetInventory(current.ammoType1, 0);
        }
        current.Destroy();
    }

    override void ModifyDamage(int damage, Name damageType, out int newDamage, bool passive, Actor inflictor, Actor source, int flags) {
        if (!passive || self.owner == null) {
            return;
        }
        if (!self.IsActive()) {
            newDamage = 0;
        } else if (damage >= self.owner.health) {
            newDamage = 0;
            self.GoDown();
        }
    }

    // Down with Quick Revive, down waiting for a teammate, or the end of the game when nobody is left
    void GoDown() {
        if (self.owner.FindInventory('HH_SoloRevive') != null) {
            self.owner.GiveInventory('HH_LastStand', 1);
            return;
        }
        let number = self.owner.PlayerNumber();
        for (let i = 0; i < MAXPLAYERS; ++i) {
            if (i != number && HH_Util.IsActive(i)) {
                self.owner.GiveInventory('HH_LastStand', 1);
                return;
            }
        }
        let rounds = HH_Rounds.Get();
        if (rounds != null) {
            rounds.EndGame();
        }
    }

    // Back in the game at a new round: the class's starting items, at least hh_respawn_points
    // points, at a respawn spot (or a player start)
    void Respawn() {
        self.owner.ClearInventory();
        self.weapons.Clear();
        self.perks.Clear();
        self.fastReload = false;
        self.doubleFire = false;
        self.lastStand = false;
        self.spectating = false;
        self.switchWeapon = true;
        self.scanned = false;

        let pawn = PlayerPawn(self.owner);
        if (pawn != null) {
            pawn.GiveDefaultInventory();
        }
        HH_Players.Equip(self.owner);
        if (self.owner.CountInv('HH_Points') < HH_Settings.Int("hh_respawn_points")) {
            self.owner.SetInventory('HH_Points', HH_Settings.Int("hh_respawn_points"));
        }
        self.owner.A_SetHealth(HH_Settings.Int("hh_health"));

        HH_Players.MoveToSpawn(self.owner);
        if (self.startingWeapon != null) {
            self.owner.A_SelectWeapon(self.startingWeapon);
        }
    }

    // Gives a weapon that doesn't count against the limit (the last stand pistol) and selects it
    void GiveTemporary(class<Weapon> type) {
        if (type == null) {
            return;
        }
        if (self.owner.FindInventory(type) == null) {
            self.skipPickup = true;
            self.owner.GiveInventory(type, 1);
            self.skipPickup = false;
        }
        self.owner.A_SelectWeapon(type);
    }

    // Takes back a weapon given by GiveTemporary, unless the player owns one of their own
    void RemoveTemporary(class<Weapon> type) {
        let weapon = Weapon(self.owner.FindInventory(type));
        if (weapon != null && !self.Owns(weapon)) {
            weapon.Destroy();
        }
        self.SelectBest();
    }

    void SelectBest() {
        if (self.weapons.Size() != 0) {
            self.owner.A_SelectWeapon(self.weapons[0].GetClass());
        } else if (self.melee != null) {
            self.owner.A_SelectWeapon(self.melee);
        }
    }

    // The weapon keys: next and previous go through the carried weapons then melee
    void NextWeapon() {
        if (self.weapons.Size() == 0) {
            return;
        }
        let index = self.weapons.Find(self.owner.player.ReadyWeapon);
        if (index == self.weapons.Size()) {
            self.owner.A_SelectWeapon(self.weapons[0].GetClass());
        } else if (index == self.weapons.Size() - 1) {
            if (self.melee != null && self.owner.FindInventory(self.melee) != null) {
                self.owner.A_SelectWeapon(self.melee);
            } else {
                self.owner.A_SelectWeapon(self.weapons[0].GetClass());
            }
        } else {
            self.owner.A_SelectWeapon(self.weapons[index + 1].GetClass());
        }
    }

    void PreviousWeapon() {
        if (self.weapons.Size() == 0) {
            return;
        }
        let last = self.weapons.Size() - 1;
        let index = self.weapons.Find(self.owner.player.ReadyWeapon);
        if (index == self.weapons.Size()) {
            self.owner.A_SelectWeapon(self.weapons[last].GetClass());
        } else if (index == 0) {
            if (self.melee != null && self.owner.FindInventory(self.melee) != null) {
                self.owner.A_SelectWeapon(self.melee);
            } else {
                self.owner.A_SelectWeapon(self.weapons[last].GetClass());
            }
        } else {
            self.owner.A_SelectWeapon(self.weapons[index - 1].GetClass());
        }
    }

    // Slot 1 is the first carried weapon, slot 2 the second...; slot 0 (the 0 key) is melee
    void SelectWeapon(int slot) {
        if (slot == 0) {
            if (self.melee != null && self.owner.FindInventory(self.melee) != null) {
                self.owner.A_SelectWeapon(self.melee);
            }
        } else if (slot <= self.weapons.Size()) {
            self.owner.A_SelectWeapon(self.weapons[slot - 1].GetClass());
        }
    }

    bool Owns(Weapon weapon) {
        return weapon != null && self.weapons.Find(weapon) != self.weapons.Size();
    }

    void Abandon(Weapon weapon) {
        let index = self.weapons.Find(weapon);
        if (index != self.weapons.Size()) {
            self.weapons.Delete(index);
        }
    }

    bool AtCapacity() {
        return self.weapons.Size() >= max(1, HH_Settings.Int("hh_max_weapons"));
    }

    // Max Ammo: every weapon the player holds gets full reserve ammo, whatever its ammo types
    void FillWeapons() {
        for (let item = self.owner.Inv; item != null; item = item.Inv) {
            let weapon = Weapon(item);
            if (weapon != null && !(weapon is 'HH_Drink')) {
                self.FillAmmo(weapon.ammoType1);
                self.FillAmmo(weapon.ammoType2);
            }
        }
    }

    void FillAmmo(class<Ammo> type) {
        if (type == null) {
            return;
        }
        let owned = self.owner.FindInventory(type);
        let most = owned != null? owned.MaxAmount: GetDefaultByType(type).MaxAmount;
        self.owner.SetInventory(type, most);
    }

    void SetFastReload(bool on) {
        self.fastReload = on;
        foreach (weapon : self.weapons) {
            let zombiesWeapon = HH_Weapon(weapon);
            if (zombiesWeapon != null) {
                if (on) {
                    zombiesWeapon.ActivateFastReload();
                } else {
                    zombiesWeapon.DeactivateFastReload();
                }
            }
        }
    }

    void SetDoubleFire(bool on) {
        self.doubleFire = on;
        foreach (weapon : self.weapons) {
            let zombiesWeapon = HH_Weapon(weapon);
            if (zombiesWeapon != null) {
                if (on) {
                    zombiesWeapon.ActivateDoubleFire();
                } else {
                    zombiesWeapon.DeactivateDoubleFire();
                }
            }
        }
    }

    // The weapon an unlocked entry names, when it is on and that class is loaded
    static class<Weapon> UnlockedType(String token) {
        if (token.Left(1) == "-") {
            return null;
        }
        return (class<Weapon>)(token);
    }

    int UnlockIndex(class<Weapon> type) {
        String name = type.GetClassName();
        for (let i = 0; i < self.unlocked.Size(); ++i) {
            let entry = self.unlocked[i];
            if (entry.Left(1) == "-") {
                entry = entry.Mid(1);
            }
            if (entry ~== name) {
                return i;
            }
        }
        return -1;
    }

    bool IsUnlocked(class<Weapon> type) {
        return type != null && self.UnlockIndex(type) >= 0;
    }

    void Unlock(class<Weapon> type) {
        if (type != null && !self.IsUnlocked(type)) {
            self.unlocked.Push(type.GetClassName());
            self.SaveUnlocked();
        }
    }

    void ToggleUnlocked(class<Weapon> type) {
        let index = self.UnlockIndex(type);
        if (index < 0) {
            return;
        }
        let entry = self.unlocked[index];
        self.unlocked[index] = entry.Left(1) == "-"? entry.Mid(1): "-"..entry;
        self.SaveUnlocked();
    }

    // Only the player's own machine can write their CVar: it is told, and keeps it
    void SaveUnlocked() {
        String joined = "";
        foreach (entry : self.unlocked) {
            joined = joined == ""? entry: joined..","..entry;
        }
        if (self.owner != null && self.owner.player != null) {
            EventHandler.SendInterfaceEvent(self.owner.PlayerNumber(), "hh_unlocked:"..joined);
        }
    }

    bool CanTakePerk() {
        return HH_Settings.Int("hh_perk_limit") <= 0 || self.perks.Size() < HH_Settings.Int("hh_perk_limit");
    }

    void ClearPerks() {
        for (let i = self.perks.Size() - 1; i >= 0; --i) {
            self.owner.TakeInventory(self.perks[i], 1);
        }
        self.perks.Clear();
    }
}
