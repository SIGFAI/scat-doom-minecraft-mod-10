// SuperIntelligent Cat - the demo's stage manager. Only active when demo.cfg sets mc_demo 1.
// demo.cfg `wait`s also tick while GZDoom loads, so the staging lives here, on the map's own clock:
// Doom monsters in view for the Cat to convert, then a creeper fight, a hiss, an anvil, a TNT chain, a ghast.

class MCDemo : EventHandler
{
	override void WorldTick()
	{
		if (!mc_demo) return;
		let p = players[consoleplayer].mo;
		if (!p) return;
		p.player.cheats |= CF_GODMODE;
		int t = level.maptime;
		let cat = TheCat();
		if (t == hissAt && cat && creeper && creeper.health > 0) cat.Hiss(creeper);
		if (t == anvilAt && cat && skeleton && skeleton.health > 0) cat.Anvil(skeleton);
		switch (t)
		{
		case 1:
			p.GiveInventory("MCCrossbow", 1);
			p.GiveInventory("MCTNTCannon", 1);
			p.GiveInventory("MCDispenser", 1);
			p.GiveInventory("Shell", 50);
			p.GiveInventory("RocketAmmo", 20);
			p.GiveInventory("Clip", 150);
			p.A_SelectWeapon("MCCrossbow");
			break;
		case 8:	// plain Doom monsters, for the Cat's wave to turn into mobs on camera (passive until then)
			Passive(Ahead("ZombieMan", 380, -9));
			Passive(Ahead("ZombieMan", 420, 9));
			Passive(Ahead("DoomImp", 460, 0));
			break;
		case 35 * 6:	// a creeper with a zombie at its side: shoot it and the blast takes the zombie too
			Ahead("MCCreeper", 360, -6);
			Ahead("MCZombie", 380, 2);
			break;
		case 35 * 11:
			Ahead("MCCreeper", 400, 18);
			Ahead("MCSkeleton", 520, -14);
			break;
		case 35 * 17:	// a creeper walks up behind the Cat: it hisses, the creeper hops and runs
			hissAt = t + 32;
			creeper = Ahead("MCCreeper", 330, 0);
			if (creeper) CatBetween(creeper);
			break;
		case 35 * 23:	// a skeleton in plain view: the Cat drops an anvil on it
			skeleton = Ahead("MCSkeleton", 360, 0);
			anvilAt = t + 22;
			break;
		case 35 * 30:	// TNT blocks next to a group, and TNT in the player's hand
			Ahead("MCTNTBlock", 380, -9);
			Ahead("MCTNTBlock", 400, 7);
			Ahead("MCZombie", 430, -2);
			Ahead("MCCreeper", 450, 10);
			p.A_SelectWeapon("MCTNTCannon");
			break;
		case 35 * 40:
			p.A_SelectWeapon("MCCrossbow");
			Ahead("MCSpider", 480, 10);
			Ahead("MCZombie", 520, -10);
			break;
		case 35 * 48:
			Ahead("MCGhast", 560, 0);
			Ahead("MCZombie", 420, 14);
			break;
		case 35 * 55:
			p.A_SelectWeapon("MCDispenser");
			Ahead("MCEnderman", 460, 8);
			Ahead("MCCreeper", 420, -12);
			break;
		case 35 * 62:	// finale: the Cat's fish (the BFG's slot)
			p.GiveInventory("MCCatFish", 1);
			p.GiveInventory("Cell", 120);
			p.A_SelectWeapon("MCCatFish");
			Ahead("MCSkeleton", 520, 10);
			Ahead("MCCreeper", 480, -10);
			Ahead("MCZombie", 540, 0);
			MCStory.Cat("Wait. Is that... my fish? Put it DOWN.");
			break;
		case 35 * 70:
			p.A_SelectWeapon("MCCrossbow");
			Ahead("MCSpider", 460, -8);
			Ahead("MCZombie", 500, 12);
			break;
		}
	}

	int hissAt, anvilAt;

	// Friendly for a second: the pilot ignores them and they don't shoot, so the wave converts them alive.
	void Passive(Actor m)
	{
		if (!m) return;
		m.bFriendly = true;
		m.target = null;
		m.Speed = 0;
	}
	Actor creeper, skeleton;

	SuperCat TheCat()
	{
		let it = ThinkerIterator.Create("SuperCat");
		return SuperCat(it.Next());
	}

	void Cat(int at)
	{
		let c = TheCat();
		if (c) c.nextTrick = at;
	}

	// Puts the Cat (in a puff) between the player and a, a little closer to a: both in view.
	void CatBetween(Actor a)
	{
		let c = TheCat();
		let p = players[consoleplayer].mo;
		if (!c || !p) return;
		Vector2 dir = (p.pos.xy - a.pos.xy).Unit();
		for (int i = 0; i < 4; i++)
		{
			Vector2 xy = a.pos.xy + dir * (110 + i * 25) + (dir.y, -dir.x) * 30;
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			Vector3 old = c.pos;
			c.SetOrigin((xy, z), false);
			if (c.TestMobjLocation()) { MCFX.Poof(old + (0, 0, 20), 12, 6); MCFX.Poof(c.pos + (0, 0, 20), 12, 6); c.ClearInterpolation(); c.angle = c.AngleTo(a); c.busyUntil = level.maptime + 32; c.SetStateLabel("Sit"); return; }
			c.SetOrigin(old, false);
		}
	}

	// Spawns cls past the Cat, on the line from the player to the Cat, so the Cat is between them.
	Actor NearCat(Class<Actor> cls, double beyond)
	{
		let c = TheCat();
		let p = players[consoleplayer].mo;
		if (!c) return Ahead(cls, 260, 30);
		double off = Actor.deltaangle(p.angle, p.AngleTo(c));
		return Ahead(cls, p.Distance2D(c) + beyond, off);
	}

	// Spawns cls in front of the player (in view, on the floor, not in a wall), facing and hunting the player.
	Actor Ahead(Class<Actor> cls, double dist, double off, double up = 0)
	{
		let p = players[consoleplayer].mo;
		static const double tries[] = { 0, 20, -20, 40, -40, 65, -65, 100, -100, 150, -150, 180 };
		for (int i = 0; i < tries.Size(); i++)
		{
			double a = p.angle + off + tries[i];
			double d = dist;
			FLineTraceData lt;
			if (p.LineTrace(a, dist + 40, 0, TRF_THRUACTORS, 32, data: lt) && lt.HitType != TRACE_HitNone) d = lt.Distance - 48;
			if (d < 220) continue;
			Vector2 xy = p.Vec2Angle(d, a);
			double z = level.PointInSector(xy).floorplane.ZatPoint(xy);
			if (abs(z - p.pos.z) > 96) continue;
			let m = Actor.Spawn(cls, (xy, z + up), ALLOW_REPLACE);
			if (!m) continue;
			if (!m.TestMobjLocation() || !m.CheckSight(p)) { m.Destroy(); continue; }
			m.angle = m.AngleTo(p);
			if (m.bIsMonster && m is "MCMob")
			{
				m.target = p;
				if (m.SeeState) m.SetState(m.SeeState);
			}
			if (m is "MCMob" || m is "MCTNTBlock")
			{
				MCFX.Poof(m.pos + (0, 0, m.height * 0.5), m.radius, 8);
				m.A_StartSound("mc/blockplace", CHAN_7);
			}
			else Actor.Spawn("TeleportFog", m.pos, ALLOW_REPLACE);
			return m;
		}
		return null;
	}
}
