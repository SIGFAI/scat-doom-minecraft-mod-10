// SuperIntelligent Cat - the player's companion and the reason Doom is now Minecraft.
// It walks next to the player (in view), turns the level into blocks at map start, hisses creepers away
// (creepers fear cats: they run), and pushes anvils onto mobs from the sky. It is far too smart to be hurt.

class SuperCat : Actor
{
	const FOLLOW_DIST = 150.;
	const FOLLOW_SIDE = 40.;     // degrees off the player's view, so it stays on screen but out of the line of fire
	const MAX_SPEED = 11.;
	const ABILITY_EVERY = 105;   // tics between two tricks

	int busyUntil, nextTrick, lastQuip, lostSince, idleSince, sideSign, rudeAt, lastHiss;
	Actor trickTarget;

	Default
	{
		Health 1000;
		Radius 15;
		Height 52;
		Mass 400;
		Speed 0;
		PainChance 255;
		Scale 1.3;
		+SOLID
		+SHOOTABLE
		+NODAMAGE
		+NOBLOOD
		+NEVERTARGET
		+DONTTHRUST
		+NOTELEPORT
		+FRIENDLY
		+NOICEDEATH
		+DROPOFF
		+CANPASS
		Tag "SuperIntelligent Cat";
		PainSound "cat/meow";
	}

	PlayerPawn Owner() { return players[consoleplayer].mo; }
	bool Busy() { return level.maptime < busyUntil; }

	override void BeginPlay()
	{
		Super.BeginPlay();
		sideSign = 1;
		nextTrick = 140;
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || IsFrozen()) return;
		let p = Owner();
		if (!p) return;
		Intro(p);
		// The opening: it stays in front of the player, facing them, while it converts the world.
		if (level.maptime < 110) { HoldInView(p); return; }
		if (Busy()) { vel.xy *= 0.6; return; }
		Follow(p);
		if (level.maptime >= nextTrick && MCWorld.Get() && MCWorld.Get().converted) Trick(p);
		else if (level.maptime % 8 == 0 && level.maptime - lastHiss > 70) SaveFromCreeper();
		else if (level.maptime - lastQuip > 35 * 22 && random(0, 300) == 0) Quip();
	}

	// ---- the opening: the Cat fixes Doom
	void Intro(PlayerPawn p)
	{
		int t = level.maptime;
		if (t == 8) { MCStory.Cat("Ugh. Brown pixels? Polygons? Not on my watch."); A_StartSound("cat/smug", CHAN_VOICE); A_Face(p); }
		if (t == 22) { SetStateLabel("Cast"); busyUntil = t + 40; MCStory.Cat("Hold my fish. Converting reality to blocks..."); }
		if (t == 44) { let w = MCWorld.Get(); if (w) w.StartWave(); }
		if (t == 175) { MCStory.Cat("There. Minecraft. You're welcome."); A_StartSound("cat/meow", CHAN_VOICE); }
		if (t == 250) MCStory.Cat("Quest: defeat 8 mobs. I'll supervise. From a safe distance.");
	}

	// Glides to a spot just left of the player's view and faces them (the opening must show it casting).
	void HoldInView(PlayerPawn p)
	{
		vel.xy *= 0.3;
		angle = AngleTo(p);
		double d = 150;
		FLineTraceData lt;
		if (p.LineTrace(p.angle, d + 40, 0, TRF_THRUACTORS, 20, data: lt) && lt.HitType == TRACE_HitWall) d = max(lt.Distance - 40, 60);
		Vector2 goal = p.Vec2Angle(d, p.angle);
		Vector2 step = (goal - pos.xy) * 0.3;
		if (step.Length() < 0.5) return;
		Vector3 old = pos;
		double z = level.PointInSector(pos.xy + step).floorplane.ZatPoint(pos.xy + step);
		SetOrigin((pos.xy + step, z), true);
		if (!TestMobjLocation()) SetOrigin(old, false);
	}

	void Follow(PlayerPawn p)
	{
		double d = Distance2D(p);
		// Lost (behind a door, far away): teleport next to the player in a puff.
		if (d > 900 || (d > 320 && !CheckSight(p))) { if (!lostSince) lostSince = level.maptime; }
		else lostSince = 0;
		if (lostSince && level.maptime - lostSince > 50) { Rejoin(p); return; }

		// Keep to the side the player is not shooting at.
		Vector2 goal = p.Vec2Angle(FOLLOW_DIST, p.angle + FOLLOW_SIDE * sideSign);
		FLineTraceData lt;
		if (p.LineTrace(p.angle + FOLLOW_SIDE * sideSign, FOLLOW_DIST + 20, 0, TRF_THRUACTORS, 20, data: lt) && lt.HitType == TRACE_HitWall)
		{
			sideSign = -sideSign;
			goal = p.Vec2Angle(max(min(FOLLOW_DIST, lt.Distance - 30), 90), p.angle + FOLLOW_SIDE * sideSign);
		}
		Vector2 to = goal - pos.xy;
		// Never under the player's nose: step away when closer than 70.
		if (d < 70) to = (pos.xy - p.pos.xy).Unit() * 60;
		double gd = to.Length();
		if (gd > 24)
		{
			double spd = clamp(gd * 0.12, 2, MAX_SPEED);
			Vector2 v = to / gd * spd;
			vel.x = v.x;
			vel.y = v.y;
			angle = VectorAngle(v.x, v.y);
			idleSince = 0;
			if (!InStateSequence(CurState, FindState("Walk"))) SetStateLabel("Walk");
		}
		else
		{
			vel.xy *= 0.5;
			if (!idleSince) idleSince = level.maptime;
			// Sitting, it looks at the player (you see its smug face).
			angle = AngleTo(p);
			if (level.maptime - idleSince > 20 && !InStateSequence(CurState, FindState("Sit"))) SetStateLabel("Sit");
		}
	}

	void Rejoin(PlayerPawn p)
	{
		for (int i = 0; i < 8; i++)
		{
			Vector2 xy = p.Vec2Angle(70, p.angle + 40 + i * 45);
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - p.pos.z) > 40) continue;
			Vector3 old = pos;
			SetOrigin((xy, z), false);
			if (TestMobjLocation() && CheckSight(p))
			{
				MCFX.Poof(old + (0, 0, 20), 12, 6);
				MCFX.Poof(pos + (0, 0, 20), 12, 6);
				A_StartSound("mc/pop", CHAN_BODY);
				lostSince = 0;
				if (random(0, 2) == 0) MCStory.Cat("Keeping up with you is beneath me. So I teleport.");
				return;
			}
			SetOrigin(old, false);
		}
	}

	// ---- tricks
	void Trick(PlayerPawn p)
	{
		nextTrick = level.maptime + ABILITY_EVERY + random(0, 40);
		Actor creeper = null, best = null;
		double cd = 1e9, bd = 1e9;
		let it = ThinkerIterator.Create("Actor");
		Actor a;
		while (a = Actor(it.Next()))
		{
			if (!a.bIsMonster || a.health <= 0 || a.bFriendly || a is "SuperCat") continue;
			double d = Distance2D(a);
			if (d > 1100 || !p.CheckSight(a)) continue;
			// Hiss only to save the day: a creeper already fusing.
			let cr = MCCreeper(a);
			if (cr && d < cd && cr.fuse > 0 && cr.savable && d < 520) { cd = d; creeper = a; }
			if (d < bd && !a.bFloat) { bd = d; best = a; } // anvils need a floor under the target
		}
		if (creeper) Hiss(creeper);
		else if (best) Anvil(best);
	}

	// A creeper fusing next to the player: the Cat hisses it away, whatever the trick timer says.
	void SaveFromCreeper()
	{
		let p = Owner();
		let it = ThinkerIterator.Create("MCCreeper");
		MCCreeper cr;
		while (cr = MCCreeper(it.Next()))
		{
			if (cr.health > 0 && cr.savable && cr.fuse > 6 && Distance2D(cr) < 520 && CheckSight(cr)) { Hiss(cr); return; }
		}
	}

	void Hiss(Actor c)
	{
		lastHiss = level.maptime;
		A_Face(c);
		SetStateLabel("Hiss");
		busyUntil = level.maptime + 40;
		A_StartSound("cat/hiss", CHAN_VOICE, 0, 1, ATTN_NORM * 0.5);
		// The hiss you can see: a ring of puffs bursting out of the Cat.
		for (int i = 0; i < 10; i++)
		{
			let pf = Actor.Spawn("MCPuff", pos + (0, 0, 30));
			if (pf) { pf.vel = (AngleToVector(i * 36, 5), frandom(0.5, 1.5)); pf.scale *= 0.6; }
		}
		int n = 0;
		let it = ThinkerIterator.Create("MCCreeper");
		MCCreeper cr;
		while (cr = MCCreeper(it.Next()))
			if (cr.health > 0 && Distance2D(cr) < 560) { cr.Scare(self); n++; }
		let s = MCStory.Get();
		if (s) s.hisses++;
		MCStory.Advance("Cat Scan", "Creepers are scared of cats. Science!");
		static const String lines[] = {
			"HSSSS! Creepers fear cats. It's in the source code. I read it.",
			"Shoo. Go explode somewhere else.",
			"Run, little green cucumber. RUN.",
			"I hiss, therefore I am." };
		if (level.maptime - lastQuip > 35 * 6 && s) { MCStory.Cat(lines[s.catLine++ % lines.Size()]); lastQuip = level.maptime; }
	}

	void Anvil(Actor t)
	{
		A_Face(t);
		SetStateLabel("Cast");
		busyUntil = level.maptime + 28;
		trickTarget = t;
		A_StartSound("cat/smug", CHAN_VOICE);
		let an = MCAnvil(Actor.Spawn("MCAnvil", t.pos));
		if (an) an.Drop(t, self);
		let s = MCStory.Get();
		if (s) s.anvils++;
		MCStory.Advance("Special Delivery", "The Cat drops an anvil on a mob");
		static const String lines[] = {
			"Physics is just knocking things off tables. Bigger tables.",
			"Oops. It slipped. (It did not slip.)",
			"Gravity: my favourite weapon.",
			"Anvil delivery. Sign here. Oh wait, you're flat.",
			"I calculated the trajectory with my left whisker." };
		if (level.maptime - lastQuip > 35 * 5 && s) { MCStory.Cat(lines[s.catLine++ % lines.Size()]); lastQuip = level.maptime; }
	}

	void Quip()
	{
		static const String lines[] = {
			"I calculated pi to nine lives.",
			"Fun fact: I am smarter than the entire Nether.",
			"This Doom place had no blocks. Barbaric.",
			"Meow means 'your build is ugly'.",
			"Your aim is 3% less terrible today.",
			"I have read every wiki. Twice." };
		MCStory.Cat(lines[random(0, lines.Size() - 1)]);
		A_StartSound("cat/meow", CHAN_VOICE);
		lastQuip = level.maptime;
	}

	override int DamageMobj(Actor inflictor, Actor source, int damage, Name mod, int flags, double angle)
	{
		if (source && source.player && inflictor == source && level.maptime - rudeAt > 100)
		{
			rudeAt = level.maptime;
			static const String lines[] = { "Rude.", "I will remember that. I remember EVERYTHING.", "Friendly fire? I'm not friendly. I'm SUPERIOR." };
			MCStory.Cat(lines[random(0, lines.Size() - 1)]);
		}
		return Super.DamageMobj(inflictor, source, damage, mod, flags, angle);
	}

	States
	{
	Spawn:
	Sit:
		SCAT F 35;
		Loop;
	Walk:
		SCAT AB 5;
		Loop;
	Cast:
		SCAT D 30 Bright A_StartSound("cat/purr", CHAN_BODY);
		Goto Sit;
	Hiss:
		SCAT C 40;
		Goto Sit;
	Pain:
		SCAT E 10 A_Pain;
		Goto Sit;
	}
}

// The anvil the Cat pushes off the sky: falls, flattens mobs under it, clangs, stays a moment, puffs away.
class MCAnvil : Actor
{
	Actor victim, cat;
	double floorAt;
	int landedAt;

	Default
	{
		Radius 20;
		Height 30;
		+NOGRAVITY
		+NOBLOOD
		+DONTSPLASH
		+NOTELEPORT
		RenderStyle "Normal";
		Scale 1.5;
	}

	void Drop(Actor t, Actor from)
	{
		victim = t;
		cat = from;
		double top = t.ceilingz - Height - 4;
		SetOrigin((t.pos.xy, min(t.pos.z + 260, top)), false);
		vel = (0, 0, -2);
		MCFX.Poof(pos + (0, 0, 10), 10, 4);
	}

	override void Tick()
	{
		Super.Tick();
		if (bDestroyed || landedAt) { if (landedAt && level.maptime - landedAt > 50) { MCFX.Poof(pos + (0, 0, 10), 14, 6); Destroy(); } return; }
		// Track the victim a little while it falls (it is a smart anvil).
		if (victim && victim.health > 0) vel.xy = (victim.pos.xy - pos.xy) * 0.25;
		vel.z = max(vel.z - 1.1, -30);
		double fz = floorz;
		if (pos.z + vel.z <= fz)
		{
			SetZ(fz);
			Land();
		}
	}

	void Land()
	{
		landedAt = level.maptime;
		vel = (0, 0, 0);
		bSolid = true;
		bShootable = false;
		A_StartSound("mc/anvil", CHAN_BODY, 0, 1, 0.6);
		A_QuakeEx(2, 2, 2, 8, 0, 400, "", QF_SCALEDOWN);
		MCFX.BlockBurst(pos + (0, 0, 4), TexMan.GetName(floorpic), 14, 5, 6);
		MCFX.BlockBurst(pos + (0, 0, 12), "MCIRON", 6, 4, 4);
		let it = BlockThingsIterator.Create(self, 60);
		while (it.Next())
		{
			let a = it.thing;
			if (!a || a == self || !a.bShootable || a.player || a.bFriendly || a.health <= 0) continue;
			if (Distance2D(a) > 44 + a.radius || abs(a.pos.z - pos.z) > 64) continue;
			a.DamageMobj(self, cat ? cat : Actor(self), 85, 'Anvil');
			if (a && a.health > 0) a.vel.z += 4;
		}
	}

	States
	{
	Spawn:
		MCAN A -1;
		Stop;
	}
}
