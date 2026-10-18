// Things a player touches to see a hint and uses to buy

class HH_Interactable : Actor abstract {
    Default {
        +SPECIAL
    }

    override void Touch(Actor toucher) {
        let manager = HH_InventoryManager.Of(toucher);
        if (manager != null && manager.IsActive()) {
            self.DoTouch(PlayerPawn(toucher), manager);
        }
    }

    override bool Used(Actor user) {
        let manager = HH_InventoryManager.Of(user);
        if (manager != null && manager.IsActive() && self.bSpecial && self.DoUse(PlayerPawn(user), manager)) {
            manager.hud.ClearHint();
        }
        return false;
    }

    // Shows "[Cost: <cost>]"
    static void HintCost(HH_InventoryManager manager, int cost) {
        manager.hud.SetHint("$HH_HINT_COST", String.Format("%d", cost));
    }

    abstract void DoTouch(PlayerPawn player, HH_InventoryManager manager);
    abstract bool DoUse(PlayerPawn player, HH_InventoryManager manager);
}
