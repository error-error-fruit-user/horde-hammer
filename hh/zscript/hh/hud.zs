// The HUD. Everything is drawn from an event handler's RenderOverlay, on top of whatever status bar
// the game or another mod uses (Brutal Doom, Project Brutality), so Horde Hammer never needs its
// own. Each part's place, size and visibility are the player's own CVars (hh_hud_*), set in the
// "HUD Layout" menu; places are fractions of the screen, sizes scale with the screen's height.

class HH_PointsDelta play {
    int value;
    int ticsLeft;
    Vector2 offset;
    Vector2 velocity;
}

// What a player's HUD shows that isn't elsewhere in the game state: floating point changes, the
// current hint and the revive bar. Kept in play (in the player's HH_InventoryManager) and updated
// the same way on every machine.
class HH_HudState play {
    const DELTA_TICS = 55;
    const HINT_TICS = 35;

    Array<HH_PointsDelta> deltas;
    String hintId;
    String hintArgument;
    int hintTics;
    double revive;
    String rosterName;          // the weapon the box's roster shows, while they bump the box
    bool rosterGives;           // whether the box can give it to this player
    int rosterTics;

    void AddDelta(int value) {
        let delta = new('HH_PointsDelta');
        delta.value = value;
        delta.ticsLeft = HH_HudState.DELTA_TICS;
        if (value > 0) {
            delta.velocity = (FRandom[HH_Hud](0.4, 1.4), FRandom[HH_Hud](-0.2, 0.4));
        } else {
            delta.velocity = (0, 0.1);
        }
        self.deltas.Push(delta);
    }

    void SetHint(String id, String argument = "") {
        self.hintId = id;
        self.hintArgument = argument;
        self.hintTics = HH_HudState.HINT_TICS;
    }

    void ClearHint() {
        self.hintTics = 0;
    }

    void SetRoster(String name, bool gives) {
        self.rosterName = name;
        self.rosterGives = gives;
        self.rosterTics = HH_HudState.HINT_TICS;
    }

    void SetRevive(double fraction) {
        self.revive = clamp(fraction, 0, 1);
    }

    void Update() {
        for (let i = self.deltas.Size() - 1; i >= 0; --i) {
            let delta = self.deltas[i];
            delta.offset += delta.velocity;
            if (--delta.ticsLeft <= 0) {
                self.deltas.Delete(i);
            }
        }
        if (self.hintTics > 0) {
            --self.hintTics;
        }
        if (self.rosterTics > 0) {
            --self.rosterTics;
        }
    }
}

// A game without a status bar of its own can use this one: it draws nothing itself, leaving the
// screen to Horde Hammer's HUD
class HH_Hud : BaseStatusBar {}

class HH_Message ui {
    String text;
    int ticsLeft;
}

class HH_MessageLog ui {
    const MESSAGE_TICS = 140;
    const FADE_TICS = 35;
    const MOST = 4;

    Array<HH_Message> messages;

    void Add(String text) {
        let message = new('HH_Message');
        message.text = text;
        message.ticsLeft = HH_MessageLog.MESSAGE_TICS;
        self.messages.Push(message);
        while (self.messages.Size() > HH_MessageLog.MOST) {
            self.messages.Delete(0);
        }
    }

    void Tick() {
        for (let i = self.messages.Size() - 1; i >= 0; --i) {
            if (--self.messages[i].ticsLeft <= 0) {
                self.messages.Delete(i);
            }
        }
    }
}

class HH_HudHandler : EventHandler {
    const POINTS_COLOR = Font.CR_GOLD;
    const GAIN_COLOR = Font.CR_YELLOW;
    const BIG_GAIN_COLOR = Font.CR_ORANGE;
    const LOSS_COLOR = Font.CR_DARKRED;
    const ROUND_COLOR = Font.CR_RED;
    const AMMO_COLOR = Font.CR_WHITE;
    const HINT_COLOR = Font.CR_LIGHTBLUE;
    const MESSAGE_COLOR = Font.CR_WHITE;
    const ICON_SIZE = 12;
    const ICON_GAP = 2;
    const REVIVE_WIDTH = 82;

    // The parts of the HUD and the settings each has, for the reset
    static const String PARTS[] = { "points", "round", "ammo", "perks", "powerups", "hint", "revive", "messages" };
    static const String SETTINGS[] = { "show", "x", "y", "scale" };

    transient ui HH_MessageLog messageLog;

    ui HH_MessageLog Log() {
        if (self.messageLog == null) {
            self.messageLog = new('HH_MessageLog');
        }
        return self.messageLog;
    }

    override void UiTick() {
        self.Log().Tick();
    }

    override void InterfaceProcess(ConsoleEvent e) {
        // this player's roster unlocks, in their own hh_unlocked for the session, never saved
        // (HH_InventoryManager.SaveUnlocked)
        if (e.Name.Left(12) == "hh_unlocked:") {
            let saved = CVar.FindCVar("hh_unlocked");
            if (saved != null) {
                saved.SetString(e.Name.Mid(12));
            }
            return;
        }
        if (e.Name.Left(11) == "hh_message:") {
            self.Log().Add(HH_Util.Localized(e.Name.Mid(11), HH_Util.NameOf(e.Args[0])));
        } else if (e.Name == "hh_powerup_taken") {
            let id = "HH_MSG_POWERUP_"..e.Args[1];
            let text = StringTable.Localize("$"..id);
            if (text != id) {
                self.Log().Add(text);
            }
        }
    }

    // `event hh_reset_hud` (the menu's reset) puts every part back
    override void ConsoleProcess(ConsoleEvent e) {
        if (e.Name != "hh_reset_hud") {
            return;
        }
        CVar.FindCVar("hh_hud_scale").ResetToDefault();
        CVar.FindCVar("hh_hud_alpha").ResetToDefault();
        for (let i = 0; i < HH_HudHandler.PARTS.Size(); ++i) {
            for (let j = 0; j < HH_HudHandler.SETTINGS.Size(); ++j) {
                let cvar = CVar.FindCVar("hh_hud_"..HH_HudHandler.PARTS[i].."_"..HH_HudHandler.SETTINGS[j]);
                if (cvar != null) {
                    cvar.ResetToDefault();
                }
            }
        }
    }

    // The player's own settings (user CVars are read through CVar, never by name)
    static ui double Setting(String name, double fallback = 1.0) {
        let cvar = CVar.FindCVar(name);
        return cvar != null? cvar.GetFloat(): fallback;
    }

    // Whether a part shows (hh_hud_<part>_show; the ammo's is a number, 0 for never)
    static ui int Shows(String part) {
        let cvar = CVar.FindCVar("hh_hud_"..part.."_show");
        return cvar != null? cvar.GetInt(): 1;
    }

    // How big a part is drawn: its size times the HUD scale, at 1 for a 200-pixel-high screen
    static ui double ScaleOf(String part) {
        let partScale = part == ""? 1.0: HH_HudHandler.Setting("hh_hud_"..part.."_scale");
        return Screen.GetHeight() / 200.0 * HH_HudHandler.Setting("hh_hud_scale") * partScale;
    }

    // Where a part is, from its fractions of the screen
    static ui Vector2 PlaceOf(String part) {
        return (HH_HudHandler.Setting("hh_hud_"..part.."_x", 0.5) * Screen.GetWidth(), HH_HudHandler.Setting("hh_hud_"..part.."_y", 0.5) * Screen.GetHeight());
    }

    static ui Vector2 PlaceAt(double x, double y) {
        return (x * Screen.GetWidth(), y * Screen.GetHeight());
    }

    // Text with its left edge (align -1), middle (0) or right edge (1) at `place`
    static ui void Text(Font font, int color, Vector2 place, String text, int align, double scale, double alpha = 1.0) {
        let width = font.StringWidth(text) * scale;
        let x = place.x - (align == 0? width / 2: align > 0? width: 0);
        Screen.DrawText(font, color, x, place.y, text, DTA_ScaleX, scale, DTA_ScaleY, scale, DTA_Alpha, alpha * HH_HudHandler.Setting("hh_hud_alpha"));
    }

    static ui void Picture(TextureID texture, double x, double y, double width, double height, double alpha = 1.0) {
        if (!texture.IsValid()) {
            return;
        }
        Screen.DrawTexture(texture, false, x, y, DTA_DestWidthF, width, DTA_DestHeightF, height,
            DTA_LeftOffset, 0, DTA_TopOffset, 0, DTA_Alpha, alpha * HH_HudHandler.Setting("hh_hud_alpha"));
    }

    // The font for numbers: the big font, unless a game's or IWAD's big font is missing digits,
    // then the engine's own, which has everything
    static ui Font NumberFont() {
        return bigFont.CanPrint("0123456789/-+")? bigFont: NewSmallFont;
    }

    // A picture's width for a height (or the other way around), keeping its own proportions, so a
    // game's art of any size fits
    static ui double WidthFor(TextureID texture, double height) {
        let [width, tall] = TexMan.GetSize(texture);
        return tall > 0? height * width / tall: height;
    }

    static ui double HeightFor(TextureID texture, double width) {
        let [wide, height] = TexMan.GetSize(texture);
        return wide > 0? width * height / wide: width;
    }

    override void RenderOverlay(RenderEvent e) {
        if (automapactive) {
            return;
        }
        // In the HUD layout menu every part shows, with stand-in contents, so it can be placed
        if (HH_HudHandler.Previewing()) {
            self.DrawPreview();
            return;
        }
        let manager = HH_Util.ManagerOf(consolePlayer);
        if (manager == null) {
            return;
        }
        let rounds = HH_Rounds.Get();
        if (rounds != null && !rounds.IsStarted() && !HH_Settings.Bool("hh_hud_before_start")) {
            return;
        }
        if (manager.gameOver) {
            self.DrawGameOver(rounds);
            return;
        }
        self.DrawRound(rounds);
        self.DrawMessages();
        if (manager.spectating) {
            self.DrawSpectating();
            return;
        }
        self.DrawPoints(manager);
        self.DrawPowerups(manager);
        self.DrawRevive(manager);
        if (manager.lastStand) {
            Screen.Dim("Red", 0.3, 0, 0, Screen.GetWidth(), Screen.GetHeight());
            return;
        }
        self.DrawAmmo(manager);
        self.DrawPerks(manager);
        self.DrawHint(manager);
        self.DrawRoster(manager);
    }

    // Whether the HUD layout menu is open
    static ui bool Previewing() {
        let menu = OptionMenu(Menu.GetCurrentMenu());
        return menu != null && menu.mDesc != null && menu.mDesc.mMenuName == 'HH_HudOptions';
    }

    // Every part the player shows, with stand-in contents: the game's own perk and power-up icons
    ui void DrawPreview() {
        if (HH_HudHandler.Shows("round")) {
            HH_HudHandler.RoundText(5, HH_HudHandler.ROUND_COLOR, 1.0);
        }
        if (HH_HudHandler.Shows("messages")) {
            HH_HudHandler.MessageLine(0, StringTable.Localize("$HH_HUD_PREVIEW_MESSAGE"), 1.0);
            HH_HudHandler.MessageLine(1, StringTable.Localize("$HH_HUD_PREVIEW_MESSAGE"), 0.5);
        }
        if (HH_HudHandler.Shows("points")) {
            HH_HudHandler.PointsText(1500);
            HH_HudHandler.PointsDelta(50, (0, 0), 1.0);
            HH_HudHandler.PointsDelta(10, (6, -8), 0.6);
        }
        if (HH_HudHandler.Shows("ammo") > 0) {
            HH_HudHandler.AmmoText("8 / 32");
        }
        Array<TextureID> perks;
        Array<TextureID> powerups;
        foreach (type : AllActorClasses) {
            if (Actor.GetReplacement(type) != type) {
                continue;
            }
            let perk = (class<HH_Perk>)(type);
            let power = (class<HH_Powerup>)(type);
            if (perk != null) {
                HH_HudHandler.AddIcon(perks, GetDefaultByType(perk).Icon);
            } else if (power != null) {
                HH_HudHandler.AddIcon(powerups, GetDefaultByType(power).Icon);
            }
        }
        if (HH_HudHandler.Shows("perks")) {
            HH_HudHandler.PerkIcons(perks);
        }
        if (HH_HudHandler.Shows("powerups")) {
            Array<bool> drawn;
            foreach (icon : powerups) {
                drawn.Push(true);
            }
            HH_HudHandler.PowerupIcons(powerups, drawn);
        }
        if (HH_HudHandler.Shows("hint")) {
            HH_HudHandler.HintText(HH_Util.Localized("$HH_HINT_COST", "1000"));
            HH_HudHandler.RosterText(StringTable.Localize("$HH_HUD_PREVIEW_WEAPON"), HH_HudHandler.HINT_COLOR);
        }
        if (HH_HudHandler.Shows("revive")) {
            HH_HudHandler.ReviveBar(0.6);
        }
    }

    // An icon for the preview, once each
    static ui void AddIcon(out Array<TextureID> icons, TextureID icon) {
        if (icon.IsValid() && icons.Find(icon) == icons.Size()) {
            icons.Push(icon);
        }
    }

    ui void DrawPoints(HH_InventoryManager manager) {
        if (!HH_HudHandler.Shows("points")) {
            return;
        }
        HH_HudHandler.PointsText(HH_Points.CountOf(manager.owner));
        foreach (delta : manager.hud.deltas) {
            HH_HudHandler.PointsDelta(delta.value, delta.offset, double(delta.ticsLeft) / HH_HudState.DELTA_TICS);
        }
    }

    static ui void PointsText(int points) {
        HH_HudHandler.Text(HH_HudHandler.NumberFont(), HH_HudHandler.POINTS_COLOR, HH_HudHandler.PlaceOf("points"), String.Format("%d", points), -1, HH_HudHandler.ScaleOf("points"));
    }

    // A change of points floating off to the right of them
    static ui void PointsDelta(int value, Vector2 offset, double alpha) {
        let scale = HH_HudHandler.ScaleOf("points");
        let tint = value < 0? HH_HudHandler.LOSS_COLOR: value >= 100? HH_HudHandler.BIG_GAIN_COLOR: HH_HudHandler.GAIN_COLOR;
        let text = value < 0? String.Format("-%d", -value): String.Format("+%d", value);
        let at = HH_HudHandler.PlaceOf("points") + (45 + offset.x, 3 + offset.y) * scale;
        HH_HudHandler.Text(smallFont, tint, at, text, -1, scale * 0.75, alpha);
    }

    ui void DrawRound(HH_Rounds rounds) {
        if (!HH_HudHandler.Shows("round") || rounds == null || rounds.currentRound == 0) {
            return;
        }
        let alpha = 1.0;
        let tint = HH_HudHandler.ROUND_COLOR;
        if (rounds.IsBetweenRounds()) {
            let period = TICRATE * 2;
            alpha = abs((rounds.phaseTics % period) - period / 2) / double(period / 2);
            tint = Font.CR_UNTRANSLATED;
        }
        HH_HudHandler.RoundText(rounds.currentRound, tint, alpha);
    }

    static ui void RoundText(int round, int tint, double alpha) {
        HH_HudHandler.Text(HH_HudHandler.NumberFont(), tint, HH_HudHandler.PlaceOf("round"), String.Format("%d", round), 1, HH_HudHandler.ScaleOf("round"), alpha);
    }

    ui void DrawAmmo(HH_InventoryManager manager) {
        if (HH_HudHandler.Shows("ammo") <= 0 || manager.owner.player == null) {
            return;
        }
        let weapon = manager.owner.player.ReadyWeapon;
        if (weapon == null || weapon is 'HH_Drink') {
            return;
        }
        let zombiesWeapon = HH_Weapon(weapon);
        if (zombiesWeapon == null && HH_HudHandler.Shows("ammo") < 2) {
            return;
        }
        let reserve = weapon.ammoType1 != null? manager.owner.CountInv(weapon.ammoType1): -1;
        if (zombiesWeapon != null && zombiesWeapon.Default.activeAmmo > 0) {
            HH_HudHandler.AmmoText(String.Format("%d / %d", zombiesWeapon.activeAmmo, max(reserve, 0)));
        } else if (reserve >= 0) {
            HH_HudHandler.AmmoText(String.Format("%d", reserve));
        }
    }

    static ui void AmmoText(String text) {
        HH_HudHandler.Text(HH_HudHandler.NumberFont(), HH_HudHandler.AMMO_COLOR, HH_HudHandler.PlaceOf("ammo"), text, 1, HH_HudHandler.ScaleOf("ammo"));
    }

    ui void DrawPerks(HH_InventoryManager manager) {
        if (!HH_HudHandler.Shows("perks")) {
            return;
        }
        Array<TextureID> icons;
        for (let i = 0; i < manager.perks.Size(); ++i) {
            icons.Push(GetDefaultByType(manager.perks[i]).Icon);
        }
        HH_HudHandler.PerkIcons(icons);
    }

    // The perks in a row, left to right
    static ui void PerkIcons(Array<TextureID> icons) {
        let scale = HH_HudHandler.ScaleOf("perks");
        let place = HH_HudHandler.PlaceOf("perks");
        let size = HH_HudHandler.ICON_SIZE * scale;
        let x = place.x;
        foreach (icon : icons) {
            let width = HH_HudHandler.WidthFor(icon, size);
            HH_HudHandler.Picture(icon, x, place.y, width, size);
            x += width + HH_HudHandler.ICON_GAP * scale;
        }
    }

    ui void DrawPowerups(HH_InventoryManager manager) {
        if (!HH_HudHandler.Shows("powerups")) {
            return;
        }
        Array<TextureID> icons;
        Array<bool> drawn;
        for (let item = manager.owner.Inv; item != null; item = item.Inv) {
            let power = HH_Powerup(item);
            if (power != null && power.EffectTics > 0) {
                // Blinking for the last three seconds, faster for the last one
                let tics = power.EffectTics;
                icons.Push(power.Icon);
                drawn.Push(tics >= TICRATE * 3 || (tics / (tics < TICRATE? 4: 8)) % 2 != 0);
            }
        }
        HH_HudHandler.PowerupIcons(icons, drawn);
    }

    // The power-ups in a row, centred; the ones not drawn (blinking) keep their place
    static ui void PowerupIcons(Array<TextureID> icons, Array<bool> drawn) {
        if (icons.Size() == 0) {
            return;
        }
        let scale = HH_HudHandler.ScaleOf("powerups");
        let place = HH_HudHandler.PlaceOf("powerups");
        let size = HH_HudHandler.ICON_SIZE * 1.5 * scale;
        let gap = HH_HudHandler.ICON_GAP * scale;
        let total = -gap;
        foreach (icon : icons) {
            total += HH_HudHandler.WidthFor(icon, size) + gap;
        }
        let x = place.x - total / 2;
        for (let i = 0; i < icons.Size(); ++i) {
            let width = HH_HudHandler.WidthFor(icons[i], size);
            if (drawn[i]) {
                HH_HudHandler.Picture(icons[i], x, place.y, width, size);
            }
            x += width + gap;
        }
    }

    ui void DrawHint(HH_InventoryManager manager) {
        if (!HH_HudHandler.Shows("hint") || manager.hud.hintTics <= 0 || manager.hud.hintId == "") {
            return;
        }
        HH_HudHandler.HintText(HH_Util.Localized(manager.hud.hintId, manager.hud.hintArgument));
    }

    static ui void HintText(String text) {
        HH_HudHandler.Text(conFont, HH_HudHandler.HINT_COLOR, HH_HudHandler.PlaceOf("hint"), text, 0, HH_HudHandler.ScaleOf("hint"));
    }

    // The roster's weapon, over the hint: blinking red when the box can't give it
    ui void DrawRoster(HH_InventoryManager manager) {
        if (!HH_HudHandler.Shows("hint") || manager.hud.rosterTics <= 0 || manager.hud.rosterName == "") {
            return;
        }
        if (!manager.hud.rosterGives && (level.maptime / 8) % 2 == 1) {
            return;
        }
        HH_HudHandler.RosterText(manager.hud.rosterName, manager.hud.rosterGives? HH_HudHandler.HINT_COLOR: Font.CR_RED);
    }

    static ui void RosterText(String name, int tint) {
        let scale = HH_HudHandler.ScaleOf("hint");
        let place = HH_HudHandler.PlaceOf("hint") - (0, 14 * scale);
        HH_HudHandler.Text(bigFont, tint, place, name, 0, scale * 0.75);
    }

    ui void DrawRevive(HH_InventoryManager manager) {
        if (!HH_HudHandler.Shows("revive") || manager.hud.revive <= 0) {
            return;
        }
        HH_HudHandler.ReviveBar(manager.hud.revive);
    }

    // The revive bar, `done` (0 to 1) of it filled
    static ui void ReviveBar(double done) {
        let scale = HH_HudHandler.ScaleOf("revive");
        let place = HH_HudHandler.PlaceOf("revive");
        let back = TexMan.CheckForTexture("HHRVBACK");
        let fore = TexMan.CheckForTexture("HHRVFORE");
        let width = HH_HudHandler.REVIVE_WIDTH * scale;
        let height = HH_HudHandler.HeightFor(back, width);
        let left = place.x - width / 2;
        HH_HudHandler.Picture(back, left, place.y, width, height);
        // The front shows as much of itself as the revive has done
        if (fore.IsValid()) {
            Screen.DrawTexture(fore, false, left, place.y, DTA_DestWidthF, width, DTA_DestHeightF, height,
                DTA_LeftOffset, 0, DTA_TopOffset, 0, DTA_ClipRight, int(left + width * done),
                DTA_Alpha, HH_HudHandler.Setting("hh_hud_alpha"));
        }
    }

    ui void DrawMessages() {
        if (!HH_HudHandler.Shows("messages") || self.messageLog == null) {
            return;
        }
        for (let i = 0; i < self.messageLog.messages.Size(); ++i) {
            let message = self.messageLog.messages[i];
            HH_HudHandler.MessageLine(i, message.text, min(1.0, message.ticsLeft / double(HH_MessageLog.FADE_TICS)));
        }
    }

    // The message log's `index`th line
    static ui void MessageLine(int index, String text, double alpha) {
        let scale = HH_HudHandler.ScaleOf("messages");
        let lineHeight = smallFont.GetHeight() * scale * 1.2;
        HH_HudHandler.Text(smallFont, HH_HudHandler.MESSAGE_COLOR, HH_HudHandler.PlaceOf("messages") + (0, index * lineHeight), text, 0, scale, alpha);
    }

    ui void DrawSpectating() {
        let manager = HH_Util.ManagerOf(consolePlayer);
        let spectate = manager != null? HH_Spectate(manager.owner.FindInventory('HH_Spectate')): null;
        String text = StringTable.Localize("$HH_HUD_SPECTATING");
        if (spectate != null && spectate.watching >= 0) {
            text = HH_Util.Localized("$HH_HUD_SPECTATING_WHO", HH_Util.NameOf(spectate.watching));
        }
        let scale = HH_HudHandler.ScaleOf("");
        HH_HudHandler.Text(smallFont, Font.CR_GRAY, HH_HudHandler.PlaceAt(0.5, 0.85), text, 0, scale);
    }

    ui void DrawGameOver(HH_Rounds rounds) {
        let alpha = rounds != null? min(1.0, rounds.phaseTics / double(TICRATE * 2)): 1.0;
        let scale = HH_HudHandler.ScaleOf("") * 1.5;
        HH_HudHandler.Text(bigFont, Font.CR_RED, HH_HudHandler.PlaceAt(0.5, 0.4), StringTable.Localize("$HH_HUD_GAME_OVER"), 0, scale, alpha);
        if (rounds != null && rounds.currentRound > 0) {
            let text = rounds.currentRound == 1? StringTable.Localize("$HH_HUD_SURVIVED_ONE"): HH_Util.Localized("$HH_HUD_SURVIVED", String.Format("%d", rounds.currentRound));
            HH_HudHandler.Text(smallFont, Font.CR_WHITE, HH_HudHandler.PlaceAt(0.5, 0.52), text, 0, HH_HudHandler.ScaleOf(""), alpha);
        }
    }
}
