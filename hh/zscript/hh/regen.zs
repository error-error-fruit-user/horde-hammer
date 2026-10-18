// Health that comes back after a while without taking damage

class HH_Regen : Inventory {
    int maxHealth;
    int ticsTillHealing;

    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
        +INVENTORY.UNCLEARABLE
        +INVENTORY.PERSISTENTPOWER
    }

    override void AttachToOwner(Actor other) {
        super.AttachToOwner(other);
        self.maxHealth = HH_Settings.Int("hh_health");
    }

    override void ModifyDamage(int damage, Name damageType, out int newDamage, bool passive, Actor inflictor, Actor source, int flags) {
        if (passive && damage > 0) {
            self.ticsTillHealing = HH_Settings.Int("hh_regen_delay");
        }
    }

    override void DoEffect() {
        super.DoEffect();
        let manager = HH_InventoryManager.Of(self.owner);
        if (!HH_Settings.Bool("hh_health_regen") || manager == null || !manager.IsActive()) {
            return;
        }
        if (self.ticsTillHealing > 0) {
            --self.ticsTillHealing;
        } else if (self.owner.health < self.maxHealth) {
            self.owner.A_SetHealth(min(self.maxHealth, self.owner.health + HH_Settings.Int("hh_regen_rate")));
        }
    }

    // Juggernog raises the most health there is, and heals to it
    void SetMaxHealth(int value) {
        self.maxHealth = value;
        if (self.owner != null && self.owner.health > value) {
            self.owner.A_SetHealth(value);
        }
        self.ticsTillHealing = 0;
    }
}
