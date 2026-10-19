// The default zombie: a melee-only walker with headshots, drawn with the IWAD's former human
// sprites so it works with Doom 2 and Freedoom. A game gives it its own look by subclassing it and
// replacing the states (and setting hh_zombie_class in its HH_Defaults).

class HH_Zombie : Actor {
    // How far below the top of the zombie a hit still counts as the head
    const HEAD_SIZE = 10;
    const HEADSHOT_MULTIPLIER = 1.5;

    Default {
        //$Category "Horde Hammer"
        //$Title "Zombie"
        Obituary "$HH_OB_ZOMBIE";
        Health 100;
        Radius 12;
        Height 45;
        MaxDropOffHeight 92;
        Mass 200;
        Speed 3;
        MeleeRange 48;
        DamageType "Melee";
        ActiveSound "hh/zombie_active";
        SeeSound "hh/zombie_sight";
        PainSound "hh/zombie_pain";
        DeathSound "hh/zombie_death";
        Monster;
        +FLOORCLIP
        +NEVERRESPAWN
        +NOINFIGHTING
        +DONTHARMSPECIES
    }

    override int DamageMobj(Actor inflictor, Actor source, int damage, Name meansOfDeath, int flags, double angle) {
        if (inflictor != null && meansOfDeath != 'HH_Kick' && meansOfDeath != 'Massacre') {
            let top = self.pos.z + self.height;
            if (inflictor.pos.z >= top - HH_Zombie.HEAD_SIZE && inflictor.pos.z <= top) {
                meansOfDeath = 'HH_Headshot';
                damage = int(damage * HH_Zombie.HEADSHOT_MULTIPLIER);
            }
        }
        return super.DamageMobj(inflictor, source, damage, meansOfDeath, flags, angle);
    }

    States {
    Spawn:
        POSS AB 10 A_Look;
        Loop;
    See:
        POSS AABBCCDD 3 A_Chase;     // into Melee when next to its target (it has no Missile)
        Loop;
    Melee:
        POSS E 6 A_FaceTarget;
        POSS F 4 A_CustomMeleeAttack(50, "hh/zombie_attack", "", "Melee");
        POSS E 10;
        Goto See;
    Pain:
        POSS G 3;
        POSS G 3 A_Pain;
        Goto See;
    Death:
        POSS H 5;
        POSS I 5 A_Scream;
        POSS J 5 A_NoBlocking;
        POSS K 5;
        POSS L 512;
        Stop;
    XDeath:
        POSS M 5;
        POSS N 5 A_XScream;
        POSS O 5 A_NoBlocking;
        POSS PQRST 5;
        POSS U 512;
        Stop;
    }
}
