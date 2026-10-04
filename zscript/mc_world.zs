// SuperIntelligent Cat - the world turns into Minecraft.
// At map start the level is still Doom. The Cat raises a paw and a wave of blocks spreads out from the player:
// every wall, floor and ceiling it reaches swaps to a block (table: mctexmap.txt, then keywords: mckeys.txt),
// the sky becomes a blue block sky, and every Doom monster it reaches pops into its Minecraft mob.

class MCWorld : EventHandler
{
	const WAVE_START = 44;      // tics after map start: the Cat casts first
	const WAVE_SPEED = 13.;     // map units per tic
	const POOFS_PER_TIC = 10;

	Map<String, String> wallMap, flatMap;
	Array<String> keySub, keyBlock;
	TextureID skyTex, grassTex;

	bool waveOn, converted, cubism;
	double radius;
	Vector2 origin;
	int waveTic;

	// What the wave still has to reach, sorted closest first.
	Array<int> lineOrder, sectorOrder;
	Array<double> lineDist, sectorDist;
	int nextLine, nextSector;

	static MCWorld Get() { return MCWorld(EventHandler.Find("MCWorld")); }

	override void OnRegister()
	{
		LoadTable();
	}

	void LoadTable()
	{
		int lump = Wads.CheckNumForFullName("mctexmap.txt");
		if (lump >= 0)
		{
			Array<String> lines;
			Wads.ReadLump(lump).Split(lines, "\n");
			for (int i = 0; i < lines.Size(); i++)
			{
				String l = lines[i];
				l.Replace("\r", "");
				if (l.Length() < 3 || l.Left(1) == "#") continue;
				Array<String> p;
				l.Split(p, " ", TOK_SKIPEMPTY);
				if (p.Size() < 3) continue;
				if (p[0] == "W") wallMap.Insert(p[1].MakeUpper(), p[2]);
				else if (p[0] == "F") flatMap.Insert(p[1].MakeUpper(), p[2]);
			}
		}
		lump = Wads.CheckNumForFullName("mckeys.txt");
		if (lump >= 0)
		{
			Array<String> lines;
			Wads.ReadLump(lump).Split(lines, "\n");
			for (int i = 0; i < lines.Size(); i++)
			{
				String l = lines[i];
				l.Replace("\r", "");
				if (l.Length() < 3 || l.Left(1) == "#") continue;
				Array<String> p;
				l.Split(p, " ", TOK_SKIPEMPTY);
				if (p.Size() < 2) continue;
				keySub.Push(p[0].MakeUpper());
				keyBlock.Push(p[1]);
			}
		}
		skyTex = TexMan.CheckForTexture("MCSKY", TexMan.Type_Any);
		grassTex = TexMan.CheckForTexture("MCGRASS", TexMan.Type_Any);
	}

	override void WorldLoaded(WorldEvent e)
	{
		if (e.IsSaveGame) { converted = true; return; } // a saved game is already blocks
		let mo = players[consoleplayer].mo;
		origin = mo ? mo.pos.xy : (0, 0);
		for (int i = 0; i < level.Lines.Size(); i++)
		{
			let l = level.Lines[i];
			Insert(lineOrder, lineDist, i, ((l.v1.p + l.v2.p) * 0.5 - origin).Length());
		}
		for (int i = 0; i < level.Sectors.Size(); i++)
			Insert(sectorOrder, sectorDist, i, (level.Sectors[i].centerspot - origin).Length());
		S_ChangeMusic("MCCALM");
	}

	// The Cat arrives with the player, on every map.
	override void PlayerEntered(PlayerEvent e)
	{
		let mo = players[e.PlayerNumber].mo;
		if (!mo || e.PlayerNumber != consoleplayer) return;
		// Start items skip replacements: swap Doom's fist and pistol for the sword and the bow.
		if (mo.FindInventory("Fist", true) && !mo.FindInventory("MCSword")) { mo.TakeInventory("Fist", 1); mo.GiveInventory("MCSword", 1); }
		if (mo.FindInventory("Pistol", true) && !mo.FindInventory("MCBow"))
		{
			let pw = Weapon(mo.FindInventory("Pistol"));
			bool held = mo.player.ReadyWeapon == pw;
			mo.TakeInventory("Pistol", 1);
			mo.GiveInventory("MCBow", 1);
			if (held) mo.A_SelectWeapon("MCBow");
		}
		for (int i = 0; i < 6; i++)
		{
			let c = Actor.Spawn("SuperCat", mo.Vec3Angle(140, mo.angle + (i % 2 ? i : -i) * 8));
			if (c && c.TestMobjLocation()) { c.angle = c.AngleTo(mo); return; }
			if (c) c.Destroy();
		}
		Actor.Spawn("SuperCat", mo.Vec3Angle(40, mo.angle));
	}

	// Sorted insert (a few thousand lines at most, done once).
	static void Insert(Array<int> order, Array<double> dist, int idx, double d)
	{
		int lo = 0, hi = dist.Size();
		while (lo < hi) { int m = (lo + hi) / 2; if (dist[m] < d) lo = m + 1; else hi = m; }
		order.Insert(lo, idx);
		dist.Insert(lo, d);
	}

	void StartWave()
	{
		if (waveOn || converted) return;
		waveOn = true;
		waveTic = level.maptime;
		radius = 0;
		if (skyTex.IsValid()) level.ChangeSky(skyTex, skyTex);
		let mo = players[consoleplayer].mo;
		if (mo) mo.A_StartSound("mc/levelup", CHAN_7, CHANF_UI, 0.8);
	}

	override void WorldTick()
	{
		if (!waveOn && !converted && level.maptime >= WAVE_START + 40) StartWave(); // the Cat is late: start anyway
		if (!waveOn) return;
		radius += WAVE_SPEED + radius * 0.012;
		// The wave front: blocks popping into place in front of the player, sweeping away.
		let pl = players[consoleplayer].mo;
		if (pl && radius > 140 && radius < 1800)
		{
			for (int i = 0; i < 16; i++)
			{
				Vector2 xy = origin + Actor.AngleToVector(pl.angle + frandom(-60, 60), radius);
				Sector sec = level.PointInSector(xy);
				double fz = sec.floorplane.ZatPoint(xy);
				if (abs(fz - pl.pos.z) > 160) continue;
				MCFX.BlockBurst((xy, fz + frandom(2, 70)), TexMan.GetName(sec.GetTexture(Sector.floor)), 1, 2.5, 6);
			}
			if (level.maptime % 5 == 0) pl.A_StartSound("mc/blockplace", CHAN_AUTO, CHANF_UI, 0.5, ATTN_NONE, frandom(0.8, 1.2));
		}
		int poofs = 0;
		while (nextLine < lineOrder.Size() && lineDist[nextLine] <= radius)
		{
			let l = level.Lines[lineOrder[nextLine++]];
			if (ConvertLine(l) && poofs < POOFS_PER_TIC && random(0, 2) == 0)
			{
				poofs++;
				Vector2 mid = (l.v1.p + l.v2.p) * 0.5;
				let s = l.frontsector;
				double z = s.floorplane.ZatPoint(mid) + frandom(8, 56);
				MCFX.BlockBurst((mid, z), TexMan.GetName(l.sidedef[0].GetTexture(Side.mid).IsValid() ? l.sidedef[0].GetTexture(Side.mid) : l.sidedef[0].GetTexture(Side.bottom)), 4, 3);
			}
		}
		while (nextSector < sectorOrder.Size() && sectorDist[nextSector] <= radius)
			ConvertSector(level.Sectors[sectorOrder[nextSector++]]);
		// Monsters inside the wave pop into their Minecraft mob.
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		Array<Actor> todo;
		while (a = Actor(it.Next()))
		{
			if (a.bIsMonster && a.health > 0 && MCFor(a.GetClass()) && (a.pos.xy - origin).Length() <= radius) todo.Push(a);
			else if (a is "ExplosiveBarrel" && a.health > 0 && (a.pos.xy - origin).Length() <= radius) todo.Push(a);
		}
		for (int i = 0; i < todo.Size(); i++) Convert(todo[i]);
		if (radius > 1400 && !cubism) { cubism = true; MCStory.Advance("Cubism Achieved", "Doom is now 100% blocks"); }
		if (nextLine >= lineOrder.Size() && nextSector >= sectorOrder.Size() && radius > 4000)
		{
			waveOn = false;
			converted = true;
			// Anything the wave did not reach (closets, far corners) converts now, out of sight.
			it = ThinkerIterator.Create("Actor");
			todo.Clear();
			while (a = Actor(it.Next()))
				if ((a.bIsMonster && a.health > 0 && MCFor(a.GetClass())) || (a is "ExplosiveBarrel" && a.health > 0)) todo.Push(a);
			for (int i = 0; i < todo.Size(); i++) Convert(todo[i], false);
		}
	}

	// After the wave, everything that spawns is born Minecraft.
	override void CheckReplacement(ReplaceEvent e)
	{
		if (!converted || e.IsFinal) return;
		let to = MCFor(e.Replacee);
		if (!to && e.Replacee == "ExplosiveBarrel") to = "MCTNTBlock";
		if (to) e.Replacement = to;
	}

	static Class<Actor> MCFor(Class<Actor> c)
	{
		Name n = c.GetClassName();
		switch (n)
		{
		case 'ZombieMan':        return "MCZombie";
		case 'WolfensteinSS':    return "MCHusk";
		case 'ShotgunGuy':       return "MCSkeleton";
		case 'ChaingunGuy':      return "MCStray";
		case 'DoomImp':          return "MCCreeper";
		case 'Demon':            return "MCSpider";
		case 'Spectre':          return "MCCaveSpider";
		case 'LostSoul':         return "MCGhastling";
		case 'Cacodemon':        return "MCGhast";
		case 'PainElemental':    return "MCGhastMother";
		case 'HellKnight':       return "MCEnderman";
		case 'BaronOfHell':      return "MCEnderLord";
		case 'Arachnotron':      return "MCSpiderJockey";
		case 'Revenant':         return "MCWitherSkeleton";
		case 'Fatso':            return "MCGiantZombie";
		case 'Archvile':         return "MCEnderMage";
		case 'Cyberdemon':       return "MCCreeperTitan";
		case 'SpiderMastermind': return "MCSpiderQueen";
		}
		return null;
	}

	void Convert(Actor m, bool show = true)
	{
		Class<Actor> to = MCFor(m.GetClass());
		if (!to && m is "ExplosiveBarrel") to = "MCTNTBlock";
		if (!to) return;
		let n = Actor.Spawn(to, m.pos, NO_REPLACE);
		if (!n) return;
		n.angle = m.angle;
		n.ChangeTid(m.tid);
		n.special = m.special;
		for (int i = 0; i < 5; i++) n.args[i] = m.args[i];
		n.bAmbush = m.bAmbush;
		n.SpawnPoint = m.SpawnPoint;
		n.SpawnAngle = m.SpawnAngle;
		if (m.target) { n.target = m.target; if (n.SeeState) n.SetState(n.SeeState); }
		if (show)
		{
			MCFX.Poof(n.pos + (0, 0, n.height * 0.5), n.radius, 10);
			n.A_StartSound("mc/blockplace", CHAN_7);
		}
		m.ClearCounters();
		m.Destroy();
	}

	String BlockFor(TextureID tex, bool flat)
	{
		if (!tex.IsValid()) return "";
		String n = TexMan.GetName(tex).MakeUpper();
		if (n == "" || n == "-") return "";
		String b = "";
		if (flat) { if (flatMap.CheckKey(n)) b = flatMap.Get(n); }
		else if (wallMap.CheckKey(n)) b = wallMap.Get(n);
		if (b == "" && n.Left(2) == "MC") return ""; // one of our blocks (Freedoom's own MC2..MC19 are in the table)
		if (b == "")
		{
			for (int i = 0; i < keySub.Size(); i++)
				if (n.IndexOf(keySub[i]) >= 0) { b = keyBlock[i]; break; }
		}
		if (b == "") b = flat ? "MCSTONE" : "MCSTBRK";
		return b == "KEEP" ? "" : b;
	}

	bool ConvertLine(Line l)
	{
		bool any = false;
		for (int s = 0; s < 2; s++)
		{
			let sd = l.sidedef[s];
			if (!sd) continue;
			for (int part = 0; part < 3; part++)
			{
				String b = BlockFor(sd.GetTexture(part), false);
				if (b == "") continue;
				let t = TexMan.CheckForTexture(b, TexMan.Type_Any);
				if (!t.IsValid()) continue;
				sd.SetTexture(part, t);
				// Blocks sit on the world grid: wall textures start at the line, so drop Doom's offsets.
				sd.SetTextureXOffset(part, 0);
				any = true;
			}
		}
		return any;
	}

	void ConvertSector(Sector s)
	{
		bool outdoors = s.GetTexture(Sector.ceiling) == skyflatnum;
		String b = BlockFor(s.GetTexture(Sector.floor), true);
		if (b != "")
		{
			// Open sky above bare ground: grass, like the overworld.
			if (outdoors && (b == "MCDIRT" || b == "MCSTONE" || b == "MCGRAVEL" || b == "MCCOBBLE" || b == "MCMOSSY" || b == "MCSAND")) b = "MCGRASS";
			let t = TexMan.CheckForTexture(b, TexMan.Type_Any);
			if (t.IsValid()) s.SetTexture(Sector.floor, t);
		}
		if (!outdoors)
		{
			b = BlockFor(s.GetTexture(Sector.ceiling), true);
			let t = TexMan.CheckForTexture(b, TexMan.Type_Any);
			if (b != "" && t.IsValid()) s.SetTexture(Sector.ceiling, t);
		}
		// Daylight: Minecraft is bright. Dark rooms stay darker, but you can still see the mobs.
		s.SetLightLevel(int(96 + s.lightlevel * 0.62));
	}
}
