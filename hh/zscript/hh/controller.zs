// The controller layout of Call of Duty zombies, offered to each player once, the first time they
// press a controller button. UZDoom binds most pad buttons by default, and neither KEYCONF's
// defaultbind nor a DEFBINDS lump can take a key that is already bound, so the binds are set here.
// The engine only lets menu input change bindings (anything else is a fatal error), so the offer
// is a yes/no message box, which sets them when it is answered. hh_pad_layout_set remembers the
// answer, so whatever a player rebinds afterwards stays theirs; the options menu asks again. A game
// turns the offer off with hh_pad_layout 0.
class HH_ControllerLayout ui {
    // Each pad button, and what it does at the same place in COMMANDS
    static const int KEYS[] = {
        InputEvent.Key_Pad_LTrigger,
        InputEvent.Key_Pad_RTrigger,
        InputEvent.Key_Pad_A,
        InputEvent.Key_Pad_B,
        InputEvent.Key_Pad_X,
        InputEvent.Key_Pad_Y,
        InputEvent.Key_Pad_RThumb,
        InputEvent.Key_Pad_LThumb,
        InputEvent.Key_Pad_LShoulder,
        InputEvent.Key_Pad_RShoulder,
        InputEvent.Key_Pad_DPad_Left,
        InputEvent.Key_Pad_DPad_Up,
        InputEvent.Key_Pad_DPad_Right,
        InputEvent.Key_Pad_DPad_Down,
        InputEvent.Key_Pad_Start,
        InputEvent.Key_Pad_Back
    };

    static const String COMMANDS[] = {
        "+zoom",
        "+attack",
        "+use",
        "+crouch",
        "+reload",
        "weapnext",
        "hh_kick",
        "+speed",
        "hh_repulse",
        "weapdrop",                     // twice, to drop the weapon
        "slot 1",                       // the d-pad goes clockwise from the left
        "slot 2",
        "slot 3",
        "hh_equipment",
        "pause",
        "menu_main"
    };

    // Whether this player hasn't been asked yet and the game wants them asked
    static bool IsDue() {
        let set = CVar.FindCVar("hh_pad_layout_set");
        return set != null && !set.GetBool() && HH_Settings.Bool("hh_pad_layout");
    }

    static bool IsPadKey(int key) {
        return key >= InputEvent.Key_Pad_LThumb_Right && key <= InputEvent.Key_Pad_Paddle4;
    }

    // Asks, on a controller button pressed while no menu is open, when it is due. Returns whether
    // it asked, which takes the press.
    static bool AskOnPress(InputEvent e) {
        if (e.Type != InputEvent.Type_KeyDown || menuactive || !HH_ControllerLayout.IsPadKey(e.KeyScan) || !HH_ControllerLayout.IsDue()) {
            return false;
        }
        let ask = new('HH_ControllerLayoutMenu');
        ask.Init(null, StringTable.Localize("$HH_PAD_LAYOUT_ASK"), 0, true);
        ask.ActivateMenu();
        return true;
    }
}

// The question: yes sets the layout, and either answer is remembered
class HH_ControllerLayoutMenu : MessageBoxMenu {
    override void HandleResult(bool res) {
        if (res) {
            for (let i = 0; i < HH_ControllerLayout.KEYS.Size(); ++i) {
                Bindings.SetBind(HH_ControllerLayout.KEYS[i], HH_ControllerLayout.COMMANDS[i]);
            }
        }
        CVar.FindCVar("hh_pad_layout_set").SetBool(true);
        self.Close();
        self.CloseSound();
    }
}
