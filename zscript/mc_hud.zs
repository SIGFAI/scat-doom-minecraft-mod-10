// SuperIntelligent Cat - a Minecraft HUD: hotbar (the 9 weapons, ammo as stack counts), hearts, armour, hunger,
// XP bar and level, crosshair, the Cat's chat at the bottom left, the quest tracker and advancement toasts.

class MCStatusBar : BaseStatusBar
{
	const VW = 560;
	const VH = 330;
	HUDFont mc;
	double k;
	static const Name SLOTS[] = { 'MCSword', 'MCPickaxe', 'MCBow', 'MCCrossbow', 'MCMultishot', 'MCDispenser', 'MCTNTCannon', 'MCFireChargeGun', 'MCCatFish' };
	static const String ICONS[] = { "WSWDA0", "WPCKA0", "WBOWA0", "WXBWA0", "WXB2A0", "WDSPA0", "WTNTA0", "WFCHA0", "WCODA0" };

	override void Init()
	{
		Super.Init();
		SetSize(0, VW, VH);
		mc = HUDFont.Create(Font.GetFont("mcfont"));
	}

	override void Draw(int state, double TicFrac)
	{
		Super.Draw(state, TicFrac);
		if (state == HUD_None || state == HUD_AltHud || !CPlayer || !CPlayer.mo) return;
		BeginHUD(1, false);
		// The fullscreen HUD has its own scale (uiscale): size everything so the HUD is VH units tall on any screen.
		Vector2 hs = GetHUDScale();
		k = Screen.GetHeight() / double(VH) / max(hs.y, 0.01);
		DrawCross();
		DrawHotbar();
		DrawStats();
		DrawAction();
		let s = MCStory.Get();
		if (s)
		{
			DrawChat(s);
			DrawQuest(s);
			DrawToast(s);
		}
	}

	void Text(String t, Vector2 pos, int flags, int color = Font.CR_UNTRANSLATED, double alpha = 1)
	{
		DrawString(mc, t, pos * k, flags, color, alpha, -1, 4, (k, k));
	}

	void Img(String tex, Vector2 pos, int flags, double alpha = 1, Vector2 box = (-1, -1))
	{
		if (box.x > 0) DrawImage(tex, pos * k, flags, alpha, box * k);
		else DrawImage(tex, pos * k, flags, alpha, (-1, -1), (k, k));
	}

	void Box(Color c, double x, double y, double w, double h, int flags)
	{
		Fill(c, x * k, y * k, w * k, h * k, flags);
	}

	void DrawCross()
	{
		if (automapactive) return;
		Img("CROSS", (0, 0), DI_SCREEN_CENTER | DI_ITEM_CENTER, 0.9);
	}

	void DrawHotbar()
	{
		int f = DI_SCREEN_CENTER_BOTTOM | DI_ITEM_LEFT_TOP;
		Img("HOTBAR", (-91, -24), f);
		let w = CPlayer.ReadyWeapon;
		for (int i = 0; i < SLOTS.Size(); i++)
		{
			double x = -91 + 1 + i * 20;
			Class<Weapon> c = SLOTS[i];
			let have = Weapon(CPlayer.mo.FindInventory(c));
			if (have)
			{
				Img(ICONS[i], (x + 10, -13), DI_SCREEN_CENTER_BOTTOM | DI_ITEM_CENTER, 1, (16, 16));
				if (have.Ammo1 && !have.bMeleeWeapon)
					Text(String.Format("%d", have.Ammo1.Amount), (x + 19, -10), DI_SCREEN_CENTER_BOTTOM | DI_TEXT_ALIGN_RIGHT);
			}
			if (w && w.GetClass() == c) Img("HOTSEL", (x - 2, -25), f);
		}
	}

	void DrawStats()
	{
		int f = DI_SCREEN_CENTER_BOTTOM | DI_ITEM_LEFT_TOP;
		let s = MCStory.Get();
		// XP bar and level.
		if (s)
		{
			Img("XPBARE", (-91, -30), f);
			double frac = clamp(s.xpInto / double(MCStory.ToNext(s.xpLevel)), 0, 1);
			if (frac > 0) DrawImage("XPBARF", (-91 * k, -30 * k), f, 1, (-1, -1), (k * frac, k));
			if (s.xpLevel > 0)
			{
				String lv = String.Format("%d", s.xpLevel);
				// Minecraft's level number: green with a black outline.
				for (int dx = -1; dx <= 1; dx++) for (int dy = -1; dy <= 1; dy++)
					if (dx || dy) Text(lv, (dx, -38 + dy), DI_SCREEN_CENTER_BOTTOM | DI_TEXT_ALIGN_CENTER, Font.CR_BLACK);
				double pulse = level.maptime - s.levelAt < 30 ? 1 : 0;
				Text(lv, (0, -38), DI_SCREEN_CENTER_BOTTOM | DI_TEXT_ALIGN_CENTER, pulse ? Font.CR_WHITE : Font.CR_GREEN);
			}
		}
		// Hearts: 10 per row, 10 health each; a second row when over 100.
		int hp = CPlayer.health;
		for (int row = 0; row < 2; row++)
		{
			int base = row * 100;
			if (row == 1 && hp <= 100) break;
			for (int i = 0; i < 10; i++)
			{
				double x = -91 + i * 8;
				double y = -40 - row * 10;
				int h = hp - base - i * 10;
				// Low health: the hearts shake, like in Minecraft.
				if (hp <= 30) y += (level.maptime + i * 3) % 6 < 2 ? -1 : 0;
				Img(h >= 10 ? "HEARTF" : (h >= 5 ? "HEARTH" : "HEARTE"), (x, y), f);
			}
		}
		// Armour row above the hearts.
		int ar = CPlayer.mo.CountInv("BasicArmor");
		if (ar > 0)
		{
			double y = hp > 100 ? -60 : -50;
			for (int i = 0; i < 10; i++)
			{
				int a = min(ar, 100) - i * 10;
				Img(a >= 10 ? "ARMORF" : (a >= 5 ? "ARMORH" : "ARMORE"), (-91 + i * 8, y), f);
			}
		}
		// Hunger: full (the Cat feeds you. Reluctantly.)
		for (int i = 0; i < 10; i++) Img("FOODF", (91 - 9 - i * 8, -40), f);
		// Keys, next to the hotbar.
		int kx = 96;
		static const Name KEYS[] = { 'BlueCard', 'YellowCard', 'RedCard', 'BlueSkull', 'YellowSkull', 'RedSkull' };
		static const String KICONS[] = { "BKEYA0", "YKEYA0", "RKEYA0", "BSKUA0", "YSKUA0", "RSKUA0" };
		for (int i = 0; i < KEYS.Size(); i++)
		{
			Class<Inventory> k = KEYS[i];
			if (k && CPlayer.mo.FindInventory(k)) { Img(KICONS[i], (kx + 6, -12), DI_SCREEN_CENTER_BOTTOM | DI_ITEM_CENTER, 1, (12, 14)); kx += 14; }
		}
	}

	void DrawChat(MCStory s)
	{
		int n = s.chat.Size();
		double y = -66;
		int shown = 0;
		Font f = Font.GetFont("mcfont");
		for (int i = n - 1; i >= 0 && shown < 4; i--)
		{
			int age = level.maptime - s.chatAt[i];
			if (age > 35 * 7) continue;
			double a = age > 35 * 6 ? 1 - (age - 35 * 6) / 35. : 1;
			double w = f.StringWidth(s.chat[i]) * 0.85 + 6;
			Box(Color(int(110 * a), 0, 0, 0), 2, y - 1, w, 10, DI_SCREEN_LEFT_BOTTOM);
			DrawString(mc, s.chat[i], (4 * k, y * k), DI_SCREEN_LEFT_BOTTOM, Font.CR_UNTRANSLATED, a, -1, 4, (k * 0.85, k * 0.85));
			y -= 10;
			shown++;
		}
	}

	// Doom's pickup and info messages, shown the Minecraft way: one line above the hotbar that fades.
	String actionText;
	int actionAt;
	override bool ProcessNotify(EPrintLevel printlevel, String outline)
	{
		if (printlevel == PRINT_CHAT || printlevel == PRINT_TEAMCHAT) return false;
		String t = outline;
		t.StripRight();
		if (t.Left(1) == "<" || t.IndexOf("Screenshot") >= 0) return true; // the chat has its own lines; screenshot notices stay quiet
		actionText = t;
		actionAt = level.maptime;
		return true;
	}

	void DrawAction()
	{
		let w = CPlayer.ReadyWeapon;
		if (w && w != lastWeapon) { lastWeapon = w; if (level.maptime > 70) { actionText = w.GetTag(); actionAt = level.maptime; } }
		int age = level.maptime - actionAt;
		if (actionText == "" || age > 70) return;
		double a = age > 50 ? 1 - (age - 50) / 20. : 1;
		Text(actionText, (0, -62), DI_SCREEN_CENTER_BOTTOM | DI_TEXT_ALIGN_CENTER, Font.CR_WHITE, a);
	}
	Weapon lastWeapon;

	void DrawQuest(MCStory s)
	{
		if (s.questText == "" && level.maptime - s.questDoneAt > 105) return;
		bool done = s.questDoneAt && level.maptime - s.questDoneAt < 105;
		String line = done ? "Quest complete!" : String.Format("%s  %d/%d", s.questText, s.questCount, s.questGoal);
		double w = max(Font.GetFont("mcfont").StringWidth(line), 80) + 10;
		Box(Color(120, 0, 0, 0), 2, 28, w, 24, DI_SCREEN_LEFT_TOP);
		Text("The Cat's Quest", (6, 31), DI_SCREEN_LEFT_TOP, Font.CR_GOLD);
		Text(line, (6, 41), DI_SCREEN_LEFT_TOP, done ? Font.CR_GREEN : Font.CR_WHITE);
	}

	void DrawToast(MCStory s)
	{
		if (!s.toastTitle.Size()) return;
		int age = level.maptime - s.toastAt;
		// Slides in from the right, stays, slides out.
		double slide = age < 8 ? (8 - age) * 20 : (age > 128 ? (age - 128) * 14 : 0);
		double x = -162 + slide;
		Img("TOAST", (x, 4), DI_SCREEN_RIGHT_TOP | DI_ITEM_LEFT_TOP);
		Img("SCATF0", (x + 16, 20), DI_SCREEN_RIGHT_TOP | DI_ITEM_CENTER, 1, (22, 22));
		Text("Advancement Made!", (x + 32, 10), DI_SCREEN_RIGHT_TOP, Font.CR_YELLOW);
		Text(s.toastTitle[0], (x + 32, 21), DI_SCREEN_RIGHT_TOP);
	}
}
