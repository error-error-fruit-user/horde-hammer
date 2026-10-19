// The kick: a quick melee on its own key (hh_kick, F by default) that works with any weapon in
// hand, drawn on its own layer under the weapon. A game turns it off with hh_kick_enabled, or gives it its
// own leg by replacing the HHKK sprites.

class HH_KickItem : CustomInventory {
    const LAYER = -77;
    const COOLDOWN_TICS = 22;
    const RANGE = 72;
    const PUSH = 6;

    int cooldown;

    Default {
        Inventory.MaxAmount 1;
        +INVENTORY.UNDROPPABLE
        +INVENTORY.UNTOSSABLE
        +INVENTORY.UNCLEARABLE
        +INVENTORY.PERSISTENTPOWER
    }

    override void DoEffect() {
        super.DoEffect();
        if (self.cooldown > 0) {
            --self.cooldown;
        }
    }

    void Kick() {
        if (self.cooldown == 0 && self.owner != null && self.owner.player != null) {
            self.cooldown = HH_KickItem.COOLDOWN_TICS;
            self.owner.UseInventory(self);
        }
    }

    // Hits what is in front, and pushes a zombie back
    action void HH_KickHit() {
        FTranslatedLineTarget victim;
        self.LineAttack(self.angle, HH_KickItem.RANGE, self.pitch, HH_Settings.Int("hh_kick_damage"), 'HH_Kick', 'HH_KickPuff', LAF_ISMELEEATTACK, victim);
        if (victim.linetarget != null && victim.linetarget.bIsMonster && !victim.linetarget.bDontThrust) {
            victim.linetarget.Thrust(HH_KickItem.PUSH, self.angle);
        }
    }

    States {
    Use:
        TNT1 A 0 A_Overlay(HH_KickItem.LAYER, "Kick");
        TNT1 A 0 A_OverlayOffset(HH_KickItem.LAYER, 0, 32);
        Fail;
    Kick:
        HHKK AB 2;
        HHKK C 2;
        HHKK D 2 HH_KickHit;
        HHKK D 4;
        HHKK CBA 2;
        Stop;
    }
}

class HH_KickPuff : BulletPuff {
    Default {
        AttackSound "hh/kick";
        DamageType "HH_Kick";
        +NODECAL
        +PUFFONACTORS
    }
}
