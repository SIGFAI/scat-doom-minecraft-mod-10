// SuperIntelligent Cat - the story layer: the Cat's chat lines, advancement toasts, XP levels and the Cat's quests.
// The HUD (mc_hud.zs) draws what this keeps.

class MCStory : EventHandler
{
	// Chat (bottom left, Minecraft style).
	Array<String> chat;
	Array<int> chatAt;
	// Advancement toasts (top right), shown one after the other.
	Array<String> toastTitle, toastText;
	int toastAt;
	// Experience.
	int xp, xpLevel, xpInto, levelAt;
	// Quests from the Cat.
	int quest, questCount, questGoal, questDoneAt;
	String questText;
	int kills, creeperBooms, anvils, hisses, creeperTalk, catLine;
	Array<String> got;  // advancements already made

	static clearscope MCStory Get() { return MCStory(EventHandler.Find("MCStory")); }

	static void Say(String who, String msg)
	{
		let s = Get();
		if (!s) return;
		s.chat.Push(String.Format("%s<%s>\c- %s", who == "Creeper" ? "\cd" : "\cf", who, msg));
		s.chatAt.Push(level.maptime);
		if (s.chat.Size() > 6) { s.chat.Delete(0); s.chatAt.Delete(0); }
		Console.PrintfEx(PRINT_NONOTIFY, "<%s> %s", who, msg);
	}

	static void Cat(String msg)
	{
		Say("SuperIntelligent Cat", msg);
	}

	static void Advance(String title, String text)
	{
		let s = Get();
		if (!s || s.got.Find(title) != s.got.Size()) return;
		s.got.Push(title);
		s.toastTitle.Push(title);
		s.toastText.Push(text);
		if (s.toastTitle.Size() == 1) s.toastAt = level.maptime;
		let p = players[consoleplayer].mo;
		if (p && s.toastTitle.Size() == 1) p.A_StartSound("mc/toast", CHAN_AUTO, CHANF_UI, 1, ATTN_NONE);
	}

	override void WorldTick()
	{
		// Toasts last 4 s each.
		if (toastTitle.Size() && level.maptime - toastAt > 140)
		{
			toastTitle.Delete(0);
			toastText.Delete(0);
			toastAt = level.maptime;
			let p = players[consoleplayer].mo;
			if (toastTitle.Size() && p) p.A_StartSound("mc/toast", CHAN_AUTO, CHANF_UI, 1, ATTN_NONE);
		}
		if (level.maptime == 20) NextQuest();
	}

	// ---- experience
	static clearscope int ToNext(int lvl) { return lvl < 16 ? 2 * lvl + 7 : 5 * lvl - 38; }

	void AddXP(int n)
	{
		xp += n;
		xpInto += n;
		while (xpInto >= ToNext(xpLevel))
		{
			xpInto -= ToNext(xpLevel);
			xpLevel++;
			levelAt = level.maptime;
			let p = players[consoleplayer].mo;
			if (p) p.A_StartSound("mc/levelup", CHAN_AUTO, CHANF_UI, 0.9, ATTN_NONE);
			if (xpLevel == 1) Advance("First Level", "Experience: it's like knowledge, but green");
			if (xpLevel == 5) { Advance("Getting Smarter", "Level 5. The Cat is still level 9000"); Cat("Level 5! I was level 5 before I was born."); }
			if (xpLevel == 10) Cat("Level 10. Do you want a sticker?");
		}
	}

	// ---- quests
	void NextQuest()
	{
		quest++;
		questCount = 0;
		switch (quest)
		{
		case 1: questText = "Defeat 8 mobs"; questGoal = 8; break;
		case 2: questText = "Make 3 creepers go boom"; questGoal = 3; break;
		case 3: questText = "Defeat 25 mobs"; questGoal = 25; break;
		default: questText = ""; questGoal = 0; break;
		}
		if (quest == 1) { } // announced by the Cat when the world is blocks
		else if (questGoal) Cat(String.Format("New quest: %s. I would do it myself, but I'm busy being a genius.", questText));
	}

	void QuestProgress(int kind)
	{
		if (!questGoal) return;
		bool match = (quest == 1 || quest == 3) ? kind == 0 : (quest == 2 && kind == 1);
		if (!match) return;
		questCount++;
		if (questCount < questGoal) return;
		questDoneAt = level.maptime;
		let p = players[consoleplayer].mo;
		switch (quest)
		{
		case 1:
			Advance("Monster Hunter", "Cat-approved. Barely.");
			Cat("Quest done. Here, a golden apple. Don't say I never gave you anything.");
			if (p) { p.A_StartSound("cat/purr", CHAN_AUTO, CHANF_UI, 1, ATTN_NONE); Actor.Spawn("Soulsphere", p.Vec3Angle(48, p.angle, 8)); }
			break;
		case 2:
			Advance("Sssseriously?", "Three creepers, zero survivors");
			Cat("Three booms. I calculated that would happen. I calculate everything.");
			if (p) { p.A_StartSound("cat/purr", CHAN_AUTO, CHANF_UI, 1, ATTN_NONE); p.GiveInventory("RocketAmmo", 10); }
			break;
		case 3:
			Advance("Overkill", "25 mobs. The Cat is mildly impressed");
			Cat("25! You may now pet me. Once. Gently.");
			break;
		}
		AddXP(10);
		NextQuest();
	}

	override void WorldThingDied(WorldEvent e)
	{
		let m = e.Thing;
		if (!m || !m.bIsMonster || m is "SuperCat") return;
		kills++;
		if (kills == 1) Advance("Monster Hunter Jr.", "Defeat your first blocky mob");
		QuestProgress(0);
		if (m is "MCCreeper") { creeperBooms++; QuestProgress(1); if (creeperBooms == 1) Advance("Sssurprise!", "Watch a creeper go boom"); }
	}
}

// XP from orbs (single player: the console player's tally lives in MCStory).
class MCPlayerXP play
{
	static void Add(Actor p, int n)
	{
		let s = MCStory.Get();
		if (s) s.AddXP(n);
	}
}
